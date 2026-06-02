[ot-cron-health-watch cron] Hourly. Audit the OT bot's own cron job runs to surface silent failures. Seven failure classes detected:
1. **Silent failure** — job ran but response contains `FAILED`, `ERROR`, `BOT_INCOMPLETE`, `DEGRADED`, `EXCEPTION`, or non-zero error code, AND the cron did not already self-escalate to gchat.
2. **Missing run** — scheduled job did not fire within 2× its expected window (catches daemon hangs, queue jams, the same-bug-class as the 2026-05-12 manual-trigger hang on mitigated-sevs).
3. **Persistent failure** — same job failing ≥3 consecutive runs (escalated severity vs single-instance failure).
4. **Notification-retraction (a.k.a. ordering bug)** — a cron posted a main-space `🚨 …` alert, then within 15 min the SAME cron (or its triage subagent) posted an `[OUT-OF-SCOPE …]` retraction in the alert's thread. Indicates the cron is notifying BEFORE running its scope/stage gates — user-facing noise even though the gates themselves work. Detection added 2026-05-16 after S659877 + S664024 leaks; see step 6.5.
5. **Missed completion (Evergreen-restart kill)** — daemon log shows `Scheduled job firing: <job_id>` but no matching completion AND no `job_runs` row appears within `expected_window`. Caused by Evergreen process restart killing in-flight pi-harness sessions (drain only covers thrift jobs, not pi sessions). Detection added 2026-05-19 after 3 heavy crons (alert-monitor, sev-monitor, thread-summarizer) silently died at 05:42:08 PT when Evergreen re-execed mid-run. See step 6.6.
6. **Notification-outcome anomaly (silent drop / legacy)** — a monitor cron marked an item processed in its state file but the persisted `notification_outcome` ledger entry is `ERROR:<reason>` (any age) or `LEGACY_UNKNOWN` persisting >14d. Indicates the cron believed it dispatched a notification but the gchat send failed (or the schema-v3 migration found pre-existing entries whose dispatch can no longer be confirmed). Detection added 2026-05-27 after T273158617 — ot-post-monitor run #6517 silently dropped Hao Sha post 1336024098492333 AND fabricated a `Bot reply:` thread URL in its run summary. See step 6.7.
7. **Dead-helper-wrapper bypass (gchat-health parity)** — a monitor cron's run summary emitted `gchat_reads=DEGRADED` (legacy L52 emission) but the new `gchat_health` block in its state file shows `last_refresh_attempted=false`. Means the L66/L67 self-heal wrapper exists on paper but was bypassed at the call site — exactly the dead-code class that caused the 20:05 PT thread `iiujQv9mdP0` regression. Generalizes to any future "declared-but-unwired helper" anti-pattern. Detection added 2026-05-28; see step 6.8.

Post escalation to spaces/AAQAVOjYc80 ONLY on state transitions (no spam). Self-heals on recovery (post one CLEAR message when a previously-failing job has enough clean consecutive runs — threshold scales by schedule cadence; see step 5.d).

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-cron-health-state.json` — `{"<job_id>": {"status": "healthy|new_failure|persistent_failure|missing|hung|auto_mitigated", "consecutive_failures": <int>, "consecutive_clean": <int>, "last_alert_epoch": <int>, "last_run_epoch": <int>, "last_auto_mitigation_epoch": <int|null>, "last_response_excerpt": "<200 chars>"}}`. Time budget: ~2 min per run. Cap alerts at 5 per run (rate-limit on noisy days).

Procedure:

1. **Read state file.** Extract prior per-job state. If file missing/corrupt, treat as empty + create fresh.

2. **Pull manifest.** Read `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/MANIFEST.json` to get the canonical list of `(job_id, schedule_type, cron|interval_seconds)`. EXCLUDE this cron (`ot-cron-health-watch`) from audit to avoid recursion.

3. **Pull last 24h of job_runs** from sqlite:
   ```bash
   sqlite3 -separator '|' /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db \
       "SELECT job_id, run_at, raw_response FROM job_runs \
        WHERE run_at > datetime('now','-24 hours') \
        ORDER BY job_id, run_at;"
   ```
   Group rows by job_id. For each row, classify as `clean` or `failed`:
   - `clean`: response starts with or contains `HEARTBEAT_OK`, OR is empty/whitespace (some crons return nothing on no-work)
   - `failed`: response contains any of `FAILED`, `ERROR`, `BOT_INCOMPLETE`, `EXCEPTION`, `Traceback`, OR `DEGRADED` is the dominant signal (not just a per-issue degraded flag inside a HEARTBEAT_OK digest — judge from the response head)

   Distinguishing nuance: many crons emit `HEARTBEAT_OK {sevs_processed: N, ..., validator_status: discrepancies (timing on S<id> ~5h off; all substantive claims confirmed)}` — the word `discrepancies` is operationally normal (one per-issue note inside a healthy digest) and should NOT trigger silent-failure detection. Heuristic: if the response begins with `HEARTBEAT_OK` and the failure keywords appear ONLY inside a parenthetical or quoted span, classify as clean. When in doubt, classify as clean (false negative is recoverable; false positive is alert noise).

4. **Pull last 24h of daemon log** to detect missing runs and crashes:
   ```bash
   tail -10000 /home/dennyzhang/.myclaw-ot-bot/logs/myclaw.log | \
       grep -E "Scheduled job firing|Scheduled job '|Killed|crashed|Traceback|ERROR|FATAL"
   ```
   Build per-job map: `{job_id: [(epoch, "fired"|"completed"|"error"), ...]}`.

5. **For each job in manifest, classify current state:**

   a. **Compute expected_window:**
      - `interval` jobs: `expected_window = interval_seconds`
      - `cron` jobs: derive from cron expression — e.g., `0 21 * * *` → daily, `expected_window = 86400s`; `*/15 * * * *` → 15min. Use a cron-parsing helper or pattern-match on common formats. For unrecognized formats, default to 86400s and note `expected_window=unknown` in state.

   b. **Latest run timestamp:** max(run_at) for this job_id from step 3 (sqlite). If no rows in 24h: `latest_run_epoch = none`.

   c. **Missing-run detection:**
      - If `latest_run_epoch` is None AND the job's schedule should have fired in the last 24h: state = `missing` (severity: HIGH if cron-type with >1 expected fire missed; MEDIUM otherwise).
      - If `(now - latest_run_epoch) > 2 * expected_window`: state = `missing`.
      - Cross-check with daemon log: if the daemon log shows `Scheduled job firing: <job_id>` recently but no completion, the job is HUNG (record `state=hung`, severity HIGH).

   d. **Failure-cluster detection:**
      - Walk this job's runs in chronological order (newest first).
      - `consecutive_failures` = count of `failed` runs at the head before the first `clean` run.
      - `consecutive_clean` = count of `clean` runs at the head before the first `failed` run.
      - **Recovery threshold scales by schedule cadence** (operator fix 2026-05-17 thread vELe4TtKc7c — daily/weekly crons would otherwise take days/weeks to clear `missing` state):
         - Interval-based crons with `interval_seconds <= 7200` (≤2h) → need `consecutive_clean >= 3` for recovery (3 clean hours)
         - Daily crons (`cron` field set, fires ≤2×/day) → need `consecutive_clean >= 1` for recovery (1 clean fire after failure window is sufficient signal)
         - Weekly crons → need `consecutive_clean >= 1` for recovery
      - Classification:
        - `consecutive_failures >= 3` → state = `persistent_failure` (severity HIGH)
        - `consecutive_failures == 1 or 2` AND prior state was healthy → state = `new_failure` (severity MEDIUM)
        - `consecutive_clean >= recovery_threshold` AND prior state was failing → state = `recovered` (transition; post CLEAR message)
        - Otherwise → state = `healthy` (no posting)

6. **Detect state transitions** vs prior state file. Only post on transitions (suppresses repeat alerts). For each transition, build alert record:
   ```
   {
     "job_id": "<id>",
     "transition": "healthy→new_failure" | "new_failure→persistent_failure" | "*→missing" | "*→hung" | "failing→recovered" | "*→ordering_bug",
     "severity": "HIGH" | "MEDIUM",
     "consecutive_failures": <int>,
     "latest_response_excerpt": "<first 200 chars of latest failed response>",
     "expected_next_run": "<iso>",
     "suggested_triage": "<one-line — see step 7 lookup>"
   }
   ```

6.6. **Missed-completion audit (class 5 — Evergreen kill).** Detect the pattern: daemon log shows `Scheduled job firing: <job_id>` line at timestamp T, but (a) NO matching completion log line within `expected_window`, AND (b) NO `job_runs` row with `run_at >= T` AND `run_at <= T + expected_window`. Means the cron's pi-harness subprocess was killed mid-flight — most commonly by an Evergreen restart whose drain only covers thrift jobs (not pi sessions), but also catches OOM kills, manual SIGTERM, or systemd unit failures.

   Query the daemon log for firing lines (last 24h):
   ```bash
   grep 'Scheduled job firing:' ~/.myclaw-ot-bot/logs/myclaw.log | tail -2000 | \
       awk '{print $1" "$2" "$NF}'   # timestamp + job_id
   ```

   For each (timestamp, job_id) tuple from the last 24h:
   - Compute `T_epoch = parse(timestamp)`.
   - Compute `expected_window` for this job (same logic as step 5.a).
   - Query for completion log line: `grep "Scheduled job '<job_id>'" ~/.myclaw-ot-bot/logs/myclaw.log | grep -A0 -B0 .` filtered to timestamps `>= T_epoch AND <= T_epoch + expected_window`. If absent → flag candidate.
   - Query sqlite for `job_runs` row: `SELECT 1 FROM job_runs WHERE job_id='<job_id>' AND run_at >= datetime(T_epoch, 'unixepoch') AND run_at <= datetime(T_epoch + expected_window, 'unixepoch') LIMIT 1`. If row exists → drop candidate (job completed; we just missed a log line).
   - If candidate survives BOTH checks → it's a missed-completion.

   **Cross-check for Evergreen kill signature:** if multiple candidates share the same `T_epoch` window (±2min), AND the daemon log shows `Evergreen: session drained, re-execing process` OR `MyClaw <build> starting` within 5 min of `T_epoch`, classify all candidates as `evergreen_kill` (one-line root cause for the alert). Otherwise classify as `missed_completion` (other root cause: OOM, SIGTERM, systemd, network).

   For each missed-completion candidate:
   - state = `missed_completion` (or `evergreen_kill` if signature matched), severity = HIGH
   - Track in state file: `missed_completions_24h: <int>` per job, plus `evergreen_kill_24h: <int>` aggregate (cross-cron counter).
   - **Hysteresis**: do not re-alert the same `(job_id, T_epoch)` pair twice. Use a `missed_completion_seen: [{job_id, fire_epoch}, ...]` rolling 24h window in state file.
   - **Auto-mitigation (safe)**: if `evergreen_kill` AND job is on the kill-allowlist (same as step 7.5 v3 hung allowlist), nudge `UPDATE jobs SET next_run_epoch=NOW WHERE id='<job_id>'` to fire a fresh run. Bounded, idempotent — same safety profile as `*→missing` mitigation.
   - **Operator escalation**: if `evergreen_kill_24h >= 3` across distinct crons in the same Evergreen-restart batch, file a task against `myclaw` oncall with the batch evidence (drain bug suspected). See step 7 triage table for the suggested-task template.

6.5. **Notification-retraction audit (class 4 — ordering bug).** Detect the pattern: cron emits a main-space `🚨 …` alert, then within 15 min a threaded `[OUT-OF-SCOPE …]` retraction lands in the same thread. Means the cron notified before running its scope/stage gates — design bug, not a runtime failure.

   Query the gchat messages table directly:
   ```bash
   sqlite3 -separator '|' /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "\
     SELECT m1.name, m1.thread_name, m1.create_time AS alert_time, \
            substr(m1.content, 1, 100) AS alert_excerpt, \
            m2.create_time AS retract_time, \
            substr(m2.content, 1, 100) AS retract_excerpt \
     FROM messages m1 \
     JOIN messages m2 ON m2.thread_name = 'spaces/AAQAVOjYc80/threads/' || substr(m1.name, instr(m1.name, '/messages/')+10, instr(substr(m1.name, instr(m1.name, '/messages/')+10), '.')-1) \
     WHERE m1.create_time > datetime('now','-24 hours') \
       AND m1.content LIKE '🚨%' \
       AND m1.thread_name = '' \
       AND m2.content LIKE '[OUT-OF-SCOPE%' \
       AND (julianday(m2.create_time) - julianday(m1.create_time)) * 86400 < 900 \
     ORDER BY m1.create_time;"
   ```
   (If the join expression is awkward, fall back to a two-step query: pull all `🚨` parent messages in the last 24h, then for each, query its thread for any `[OUT-OF-SCOPE` reply within 15 min.)

   For each (alert, retraction) pair:
   - Identify the source cron by mapping the alert prefix → cron id:
     - `🚨 [OT SEV` → `ot-sev-monitor`
     - `🚨 [OT alert` → `ot-alert-monitor`
     - `🚨 [OT post` → `ot-post-monitor`
     - Other prefixes → record as `unknown_cron`, still count.
   - If a source cron has ≥1 retraction in the audit window AND state was not already `ordering_bug`: transition = `*→ordering_bug`, severity = MEDIUM.
   - If a source cron has ≥3 retractions in 24h: severity = HIGH (the gate logic is being bypassed at scale).
   - Track per-cron retraction count in state file: `ordering_bug_24h_count: <int>` under each cron's entry.

   **Hysteresis:** once a cron transitions to `ordering_bug`, do NOT re-alert on subsequent retractions until either (a) a prompt edit lands in `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/<cron_id>.md` AFTER the alert epoch (detected via `sl log -l 1 --template '{date|isodate}'`), OR (b) 7 days pass with no retractions (auto-clear to `healthy`). Avoids hourly nagging while the fix is in flight.

6.7. **Notification-outcome anomaly audit (class 6 — silent drop / legacy).** Detect items marked "processed" in a monitor cron's state file whose persisted `notification_outcome` ledger entry shows that the user-facing dispatch FAILED or is unverifiable. Catches the silent-drop class that bypasses class-1 (silent_failure) because the cron's overall HEARTBEAT_OK looked fine — the failure was per-item, not per-run.

   Three state files in scope (paths confirmed 2026-05-27 — pre-Fix 1 only ot-post-monitor was v3; ot-alert/ot-sev still pre-v3 and require schema migration):
   - `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-monitor-state.json` (ot-post-monitor; v3 dict-of-dict)
   - `/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/alert-state.json` (ot-alert-monitor; currently v1 bare-list OR v2 dict-of-int — both pre-v3)
   - `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-sev-state.json` (ot-sev-monitor; currently v1 bare-list — pre-v3)

   **Pre-step — instrumentation audit.** Before walking outcomes, check whether each state file actually has v3 schema (any dict entry with a `notification_outcome` key). If a state file exists but has ZERO v3 entries (all values are bare int or all top-level is a list), flag as `missing_instrumentation` for the owning cron — severity MEDIUM, transition `*→missing_outcome_instrumentation`. This is the visibility-gap class: we literally cannot see silent drops for that cron. Hysteresis: clear when ≥1 v3 entry appears in the file (proves migration has run).

   For each v3-instrumented state file, walk the `processed_*_ids` (or equivalent) dict entries — each value is `{"added_epoch": <int>, "notification_outcome": <str>, ...}`. Per T273158617 Fix 1, valid `notification_outcome` values are:
   - `POSTED:<msg_resource_name>` — healthy, skip.
   - `OOS:<reason>` — out-of-scope (intentional non-post), skip.
   - `DEDUP:<source>` — deduped against an earlier post, skip.
   - `ERROR:<one-line>` — gchat send failed. **Flag (any age).**
   - `LEGACY_UNKNOWN` — pre-v3 entry; dispatch can't be confirmed. **Flag if `(now - added_epoch) > 14d`.**

   ```bash
   declare -A STATE_PATHS=(
     [ot-post-monitor]=/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-monitor-state.json
     [ot-alert-monitor]=/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/alert-state.json
     [ot-sev-monitor]=/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-sev-state.json
   )
   for CRON in "${!STATE_PATHS[@]}"; do
     SP=${STATE_PATHS[$CRON]}
     if [ ! -f "$SP" ]; then echo "MISSING_FILE|$CRON|$SP"; continue; fi
     python3 -c "
   import json, time
   NOW = int(time.time()); FOURTEEN_D = 14*86400
   try:
     d = json.load(open('$SP'))
   except Exception as e:
     print(f'PARSE_ERROR|$CRON|||$SP: {e}'); raise SystemExit(0)
   # First pass: count v3-shaped entries
   v3_count = 0; outcomes = []
   def walk(obj):
     global v3_count
     if isinstance(obj, dict):
       for k,v in obj.items():
         if isinstance(v, dict) and 'notification_outcome' in v:
           v3_count += 1
           outcome = v.get('notification_outcome','')
           age = NOW - int(v.get('added_epoch', NOW))
           outcomes.append((k, age, outcome))
         else:
           walk(v)
     elif isinstance(obj, list):
       for item in obj: walk(item)
   walk(d)
   if v3_count == 0:
     print(f'NO_INSTRUMENTATION|$CRON|||schema pre-v3 (no notification_outcome keys found)')
   else:
     for k, age, outcome in outcomes:
       if outcome.startswith('ERROR:'):
         print(f'ERROR|$CRON|{k}|{age}|{outcome[:120]}')
       elif outcome == 'LEGACY_UNKNOWN' and age > FOURTEEN_D:
         print(f'LEGACY|$CRON|{k}|{age}|LEGACY_UNKNOWN')
   "
   done
   ```

   Classification per state file:
   - `NO_INSTRUMENTATION` (pre-v3 schema) → severity MEDIUM, transition `*→missing_outcome_instrumentation` (against the owning cron). This is the visibility gap — until the cron's state schema is upgraded, silent drops there are undetectable.
   - `MISSING_FILE` (state file path doesn't exist) → severity LOW, transition `*→state_file_absent`. Likely a path drift bug or the cron has never run. Surface once; don't re-alert until file appears.
   - `PARSE_ERROR` (file present but JSON broken) → severity HIGH, transition `*→state_file_corrupt`. Cron may be writing concurrently or has bugged out — operator needs to inspect.
   - `ERROR:*` count >= 3 OR `LEGACY_UNKNOWN` (>14d) count >= 10 → severity HIGH
   - `ERROR:*` count 1-2 OR `LEGACY_UNKNOWN` count 1-9 → severity MEDIUM
   - 0 anomalies (and v3-instrumented) → no transition

   For each state file with ≥1 anomaly AND prior cron-health state was not already `notification_outcome_anomaly`: transition = `*→notification_outcome_anomaly` against the OWNING cron (`ot-post-monitor`, `ot-alert-monitor`, `ot-sev-monitor`). Track per-cron counters in cron-health state file: `notification_outcome_error_count`, `notification_outcome_legacy_count`, `last_outcome_audit_epoch`.

   **Hysteresis:** once a cron transitions to `notification_outcome_anomaly`, do NOT re-alert until either (a) the operator clears the offending entries from the state file (count drops to 0), OR (b) the offending entries' `notification_outcome` transitions to `POSTED:` / `OOS:` / `DEDUP:` via a subsequent cron run (auto-clear), OR (c) 7 days pass with no new ERROR entries (auto-clear to `healthy`). Avoids hourly nagging while a real silent-drop investigation is in flight.

   **NO AUTO-MITIGATION for this class.** A silent drop means the cron's notion of "I posted" diverged from reality — auto-retry could double-post if the original send actually landed late, or misroute if the item is stale. Operator must inspect.

6.8. **Dead-helper-wrapper audit (class 7 — declared-but-unwired helper / gchat-health parity).** Detect runs where a monitor cron's run summary emitted `gchat_reads=DEGRADED` (legacy L52 emission) but the new `gchat_health` block in its state file shows `last_refresh_attempted=false`. That divergence means the L66/L67 self-heal wrapper exists on paper but was bypassed at the call site — exactly the dead-code class that caused the 20:05 PT thread `iiujQv9mdP0` regression after the L66/L67 fixes shipped. Catches a future agent skipping the wrapper invocation while still hitting the legacy DEGRADED emission path.

   ```bash
   declare -A STATE_PATHS=(
     [ot-sev-monitor]=/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-sev-state.json
     [ot-alert-monitor]=/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/alert-state.json
     [ot-post-monitor]=/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-monitor-state.json
   )
   for CRON in "${!STATE_PATHS[@]}"; do
     SP=${STATE_PATHS[$CRON]}
     [ -f "$SP" ] || continue
     # Pull this cron's most recent raw_response from job_runs
     LAST_RESP=$(sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db \
       "SELECT raw_response FROM job_runs WHERE job_id='$CRON' ORDER BY run_at DESC LIMIT 1")
     # Did run emit DEGRADED label?
     echo "$LAST_RESP" | grep -qE 'gchat_reads=DEGRADED' || continue
     # State has gchat_health block?
     LAST_ATT=$(jq -r '.gchat_health.last_refresh_attempted // "MISSING"' "$SP" 2>/dev/null)
     LAST_403=$(jq -r '.gchat_health.last_403_seen // "MISSING"' "$SP" 2>/dev/null)
     if [ "$LAST_ATT" = "MISSING" ] || [ "$LAST_403" = "MISSING" ]; then
       echo "PARITY_MISSING|$CRON|gchat_health block absent — wrapper never ran"
     elif [ "$LAST_ATT" = "false" ] && [ "$LAST_403" = "false" ]; then
       echo "PARITY_VIOLATION|$CRON|DEGRADED emitted but wrapper recorded no 403 + no refresh — call site bypassed the wrapper (declared-but-unwired)"
     fi
   done
   ```

   For each cron with `PARITY_VIOLATION` or `PARITY_MISSING`: transition = `*→gchat_wrapper_bypass`, severity HIGH. Suggested triage (step 7): "Grep the cron prompt: `sqlite3 myclaw.db \"SELECT prompt FROM jobs WHERE id='<CRON>';\" | grep -nE 'meta google.chat.message list|gchat read '`. Any line NOT preceded by `gchat_read_with_recovery` is a bypass. Wire the wrapper at every call site per cheatsheets/diff/common.md § Declared-but-unwired helper anti-pattern. Source: 2026-05-28 L67 (L66 wrapper was dead code through one cron tick; declared but never invoked at step i-c)."

   **Hysteresis:** clear once one full tick passes with matched parity (`gchat_reads=DEGRADED` either absent, OR present alongside `last_refresh_attempted=true`).

7. **Suggested triage lookup** (per failure category):

   | Category | First-line triage suggestion |
   |---|---|
   | `silent_failure` (response keyword match) | "Inspect last response: `sqlite3 ... 'SELECT raw_response FROM job_runs WHERE job_id=\"<id>\" ORDER BY run_at DESC LIMIT 1'`. If keyword is BOT_INCOMPLETE: working copy was dirty or lint failed. If FAILED/ERROR: check daemon log for stack trace." |
   | `missing` (no run in expected window) | "Daemon may have skipped the schedule. Check `myclaw status`. Daemon log around expected fire time: `grep '<job_id>' ~/.myclaw-ot-bot/logs/myclaw.log`. Manual retrigger: `myclaw jobs run <job_id>`." |
   | `hung` (fired but no completion) | "Cron fired but never completed. Check for stuck Claude subprocess: `ps -ef \| grep claude \| grep <job_id>`. Daemon may need restart: `myclaw restart`. Note: this matches the 2026-05-12 mitigated-sevs CLI hang pattern." |
   | `persistent_failure` (≥3 in a row) | "Cron prompt likely needs a fix — failure is not transient. Read latest 3 responses: `sqlite3 ... 'SELECT raw_response FROM job_runs WHERE job_id=\"<id>\" ORDER BY run_at DESC LIMIT 3'`. Common root cause for ≥3 consecutive: upstream API change, stale path reference, schema mismatch." |
   | `ordering_bug` (alert → retraction within 15 min) | "Cron is notifying BEFORE running scope/stage gates. Re-order the cron's procedure so deep-triage + R18/scope checks run BEFORE the main-space `🚨` notification. Reference fix: `ot-sev-monitor.md` ORDERING NOTE (2026-05-16). Inspect retraction excerpts: `sqlite3 ... 'SELECT content FROM messages WHERE content LIKE \"[OUT-OF-SCOPE%\" AND create_time > datetime(\"now\",\"-24 hours\") ORDER BY create_time DESC LIMIT 5'`." |
   | `recovered` | "Auto-recovered after N runs. No action needed. State cleared." |
   | `missed_completion` / `evergreen_kill` | "Cron fired but was killed mid-flight (no completion, no DB row). Most common: Evergreen restart drain doesn't cover pi-harness sessions. Cross-check daemon log around firing timestamp for `Evergreen: re-execing process` marker. Auto-mitigation: nudge next_run_epoch=now for allowlisted interval crons. If 3+ in same batch, file task to myclaw oncall referencing T12345 (Evergreen drain bug pattern)." |
   | `notification_outcome_anomaly` (silent drop / legacy in state file) | "Per-item gchat send failure inside an otherwise-healthy cron run. Inspect offending entries: `python3 -c \"import json; d=json.load(open('/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/<state>.json')); [print(k,v) for k,v in d.get('processed_*_ids',{}).items() if isinstance(v,dict) and (v.get('notification_outcome','').startswith('ERROR:') or v.get('notification_outcome')=='LEGACY_UNKNOWN')]\"`. Cross-reference the cron run that processed each item via sqlite job_runs (filter `raw_response LIKE '%<id>%'`). Confirm whether the gchat send actually landed via `meta google.chat.message search --keywords='<id>' --days=7`. Reference: T273158617 + `gotcha_cron-silent-drop-debug-recipe`. NO AUTO-MITIGATION — operator must classify drop vs late-land before any replay." |

7.5. **Auto-mitigation pass** — for transitions where a SAFE, SCOPED mitigation exists, attempt it BEFORE escalating. If mitigation succeeds, downgrade the transition to `auto_mitigated` and post a brief mitigation report instead of the original alert.

   Safe-to-mitigate matrix (v2 — start small, expand as patterns prove themselves):

   | Transition | Auto-mitigation | Why safe |
   |---|---|---|
   | `*→missing` on interval cron (e.g., ot-post-monitor missed its 15-min tick) | Direct sqlite UPDATE `next_run_epoch=now` (daemon picks up in <1s) | Retrigger is idempotent for read-only crons; failure mode is bounded (next sched run resets epoch anyway). |
   | `*→hung` (cron fired but never completed) | **v3 (added 2026-05-17 thread `4GTCGhniXXU`):** kill stuck pi.real subprocess + nudge `next_run_epoch=now`. Operator-approved after manual run on 2026-05-17 16:24 PT (ot-sev-monitor PID 3498016 stuck 56min → SIGTERM exited cleanly → fresh fire HEARTBEAT_OK). | **Safety gates BELOW must all pass** before kill. Mitigation is bounded (single stuck subprocess) and recoverable (next sched run fires anyway). |
   | `*→new_failure` (1-2 consecutive) | NO AUTO-MITIGATION | Could be transient — let the next scheduled run try naturally. Auto-retrigger could mask intermittent bugs. |
   | `*→persistent_failure` (≥3 consecutive) | NO AUTO-MITIGATION | 3+ in a row = real bug, not transient. Auto-retry would paper over it. Operator must inspect. |
   | `*→silent_failure` (failure keyword detected) | NO AUTO-MITIGATION in v2 | Failure keywords are too varied for blanket retry; needs per-pattern lookup (v3). |

   Procedure for safe transitions — direct sqlite write, NOT the `myclaw jobs run` CLI:
   ```bash
   # For *→missing on interval cron:
   # 1. Verify next_run_epoch is in the future or recent past
   # 2. UPDATE jobs SET next_run_epoch=strftime('%s','now') WHERE id=<job_id>
   # 3. Wait 5 min for daemon to log new firing in `Scheduled job firing` lines
   # 4. Recheck job_runs for new row with run_at > now-5min
   # 5. If new row appears AND status='ok' → SUCCESS
   #    Else → FAILURE (revert nothing; daemon will retry on its own schedule)

   **v3 — `*→hung` auto-mitigation (added 2026-05-17 thread `4GTCGhniXXU`):**

   **Safety gates (ALL must pass):**
   1. Job is on the **interval-only allowlist**: `ot-sev-monitor, ot-alert-monitor, ot-post-monitor, ot-prompt-change-validator, ot-cron-health-watch (excl-self), ot-notes-deletion-watch, ot-notes-commit-push, ot-disk-watch, ot-thread-summarizer, ot-fbpkg-cap-watch`. These are all READ-ONLY crons whose only external write is gchat post. Killing them mid-run loses at most the current run's findings; next schedule re-discovers.
   2. Job is NOT on the **kill-prohibited list**: any cron with `cron=` schedule (daily/weekly), OR any cron that does WRITES beyond gchat (e.g., `ot-daily-learning-mitigated-*` writes archive files — killing mid-write could leave partial files). NEVER auto-kill `daily-brief, ot-daily-learning-debugging, ot-daily-learning-mitigated-{sevs,posts,alerts}, ot-knowledge-curation, ot-knowledge-distillation, ot-postmortem-validator, ot-triage-summary, ot-shift-summary, ot-sev-tag-review, ot-myclaw-backup-nightly, ot-myclaw-weekly-restart, ot-notes-fbcode-commit, ot-metrics-rollup, ot-human-attention-brief`.
   3. The stuck process has been in `Sl` (sleeping) state for `>= expected_window * 4` (e.g., 1h interval cron → must be stuck ≥15min before killing; 15min interval cron → ≥1h).
   4. The cron has NOT been auto-mitigated for `hung` in the last 6h (dedup; if it hung twice in 6h, there's a deeper bug — escalate to operator).
   5. The daemon log shows EXACTLY ONE `Scheduled job firing: <job_id>` line in the last 2h with no matching completion (single stuck process to kill, not a thundering-herd).

   **Mitigation steps (only if ALL gates pass):**

   ```bash
   # 1. Find the stuck pi.real PID for this cron (etime matches fire-time)
   FIRE_TIME=$(grep 'Scheduled job firing: <job_id>' ~/.myclaw-ot-bot/logs/myclaw.log | tail -1 | awk '{print $1" "$2}' | tr -d '[]')
   FIRE_EPOCH=$(date -d "$FIRE_TIME" +%s)
   NOW=$(date +%s)
   ETIME_MIN=$(( (NOW - FIRE_EPOCH) / 60 ))
   # Find the pi.real process whose start time matches FIRE_EPOCH (±60s)
   PID=$(ps -eo pid,lstart --no-headers | awk -v target=$FIRE_EPOCH '{cmd="date -d \""$2" "$3" "$4" "$5" "$6"\" +%s"; cmd | getline epoch; close(cmd); if (epoch >= target-60 && epoch <= target+60) print $1}' | head -1)

   # 2. Verify it's the right process (must be pi.real, must be ours)
   ps -p $PID -o cmd --no-headers | grep -q 'pi.real' || abort
   ps -p $PID -o uid --no-headers | grep -q "^$(id -u)$" || abort

   # 3. SIGTERM (NEVER SIGKILL on first try; pi.real has cleanup handlers)
   kill $PID
   sleep 10

   # 4. Verify exit. If still alive after 30s, escalate to operator (do NOT SIGKILL automatically)
   ps -p $PID > /dev/null && abort_with_alert

   # 5. Wait for daemon to log the exit (writes HEARTBEAT_OK to job_runs)
   sleep 5

   # 6. Nudge next_run_epoch=now to fire a fresh run
   sqlite3 ~/.myclaw-ot-bot/spaces/<space_id>/myclaw.db "UPDATE jobs SET next_run_epoch=$(date +%s) WHERE id='<job_id>'"

   # 7. Wait 5 min for daemon to log fresh fire + completion
   # 8. Verify job_runs has new row with run_at > now-6min AND status='ok' → SUCCESS
   # 9. Else → FAILURE: revert nothing, daemon will retry on schedule, escalate to operator
   ```

   **Failure modes:**
   - SIGTERM doesn't exit in 30s → escalate, do NOT SIGKILL automatically (operator may need to investigate process state)
   - Daemon doesn't fire after nudge → daemon may be hung at a higher level, escalate
   - New run also hangs within 6h → hit dedup gate, escalate with `recurring_hang_within_6h` flag

   **Why this is safe:** the allowlist is interval-only READ-ONLY crons; their state is in sqlite (idempotent), not in partial file writes. The 2026-05-17 operator-led mitigation on ot-sev-monitor confirmed the playbook works end-to-end. The kill-prohibited list explicitly carves out write-heavy crons where mid-run kill could leave partial state.
   NOW=$(date +%s.%N)
   sqlite3 /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db \
       "UPDATE jobs SET next_run_epoch=$NOW WHERE id='<job_id>' AND enabled=1;"
   ```
   Then poll `job_runs` table every 10s for up to 5 min waiting for a new row with `run_at >= NOW`:
   - New clean row appears within 5 min → mitigation SUCCESS → record `transition=auto_mitigated_via_sqlite_retrigger`
   - 5 min elapsed without new row → mitigation FAILED (daemon may be stuck or hung) → keep original `*→missing` transition + add `auto_mitigation_attempt: no_new_run_after_5min` to alert text
   - sqlite write itself fails (lock contention, permissions) → mitigation FAILED → keep original transition + add `auto_mitigation_attempt: sqlite_write_failed: <error>` to alert text

   **Why direct sqlite, not `myclaw jobs run`:** the CLI was empirically observed to hang on certain jobs (2026-05-12 mitigated-sevs: CLI blocked at "Executing job..." for >10 min on two attempts, daemon never logged the firing). Direct sqlite UPDATE on `next_run_epoch` was verified to fire the daemon within <1s on the same job. Sqlite is the runtime source-of-truth for the daemon's scheduler; the CLI is an opaque wrapper with a separate (currently broken) code path.

   **Cap auto-mitigations at 3 per run.** If >3 jobs need mitigation, the underlying issue is likely systemic (daemon issue, network, etc.) — escalate without further auto-attempts.

   **Idempotency:** never auto-mitigate the same job twice in the same run. State file tracks `last_auto_mitigation_epoch` per job; skip if attempted in last 30 min (cool-down).

8. **Post escalations** to spaces/AAQAVOjYc80 (cap 5 per run):

   a. **Top-line message** if any HIGH-severity transitions:
      ```
      🚨 [OT cron health] N HIGH-severity transition(s) detected: <comma-list of job_ids>. See thread.
      ```
      Capture thread id `health_thread`.

   b. If only MEDIUM transitions and no HIGH:
      ```
      🛟 [OT cron health] N MEDIUM transition(s) detected: <comma-list of job_ids>. See thread.
      ```

   c. **Threaded reply per transition** (`health_thread`):
      ```
      *<job_id>* — <transition> | <severity> | last run: <iso>
      • Latest response: "<excerpt>"
      • Triage: <suggested_triage from step 7>
      ```

   d. **Recovery message** (no thread, brief — does not consume the 5/run cap):
      ```
      ✅ [OT cron health] <job_id> recovered after <N> clean runs.
      ```

   e. **Auto-mitigation report** (no thread, brief — does not consume the 5/run cap):
      ```
      🔧 [OT cron health] <job_id> auto-mitigated via retrigger (was: <transition>). New run completed clean.
      ```
      OR if mitigation attempted but failed (then alert path runs as normal in 8.c with the auto_mitigation_attempt note):
      ```
      ⚠ [OT cron health] <job_id> auto-mitigation failed (<reason>) — escalated. See thread.
      ```

9. **Persist state file.** For every job in the manifest, update its entry. Set `last_run_epoch` and `last_response_excerpt`. Reset `consecutive_failures` to 0 on `recovered`. `last_alert_epoch` stamped on any post (used for future rate-limit logic if needed).

10. **Always respond `HEARTBEAT_OK {jobs_audited: N, transitions: T, alerts_posted: A, recoveries: R, auto_mitigated: M, mitigation_failures: MF, ordering_bugs: O, notification_anomalies: NA, suppressed_repeats: S}`** at end of run. Suppressed-repeats counts jobs in same failing state as before (no re-alert) — the metric proves the de-spam logic is working. `auto_mitigated` counts successful retriggers; `mitigation_failures` counts attempts that fell through to alert. `ordering_bugs` counts crons with ≥1 notification-retraction pair detected this run. `notification_anomalies` counts crons with ≥1 `ERROR:*` or aged-`LEGACY_UNKNOWN` outcome detected in their state file this run (per class 6 / step 6.7).

   **CRITICAL — NO POST WHEN `transitions == 0 AND alerts_posted == 0 AND recoveries == 0` (per RULES.md § Signal-only operator messaging, 2026-05-17 thread `JFxkiKmeibI`):** the JSON summary above is the ONLY response on a clean run. Do NOT append "audit notes", "summary observations", "per-cron status notes", or any commentary that would render as a gchat post. Audit-detail observations belong in the `job_runs.raw_response` row (for future debugging) — NOT in the gchat surface. Operator already has the JSON summary; "no transitions, no posts" runs are pure cron-self-reporting.

   *Anti-regression: 2026-05-17 — cron posted 14 HEARTBEAT_OKs in 14 hours, each with multi-paragraph "Audit notes" block that read like noise. Operator: "don't send me messages which have no value to me." The JSON `{transitions: 0, alerts_posted: 0}` is sufficient.*

Safety:
- **Mostly read-only with TWO narrow write exceptions.** This cron reads sqlite, daemon log, and manifest. The ONLY writes are: (1) the `UPDATE jobs SET next_run_epoch` in step 7.5 for `*→missing` auto-mitigation on interval crons — a bounded, idempotent retrigger; (2) **v3 (2026-05-17):** the SIGTERM + `UPDATE next_run_epoch` for `*→hung` auto-mitigation on the allowlisted interval-only crons (see safety gates in step 7.5). Never modifies job_runs, never restarts the daemon, never edits cron prompts, never SIGKILLs (only SIGTERM with escalation on failure).
- **Exclude self.** This cron must not audit `ot-cron-health-watch` to avoid recursive alarm loops if THIS cron itself fails. Operator catches its absence via missing health-check messages.
- **Sqlite access.** Open read-only (`?mode=ro`) for audit queries in steps 3-6. The step 7.5 auto-mitigation write uses a separate read-write connection, scoped to the single UPDATE statement.
- **Cap alerts at 5/run** to avoid flood on a bad day. If >5 transitions, post first 5 + count of suppressed: "(N more suppressed — see state file)."
- **Quiet by default.** No transitions detected → respond HEARTBEAT_OK only, no gchat post. The operator should NOT see daily "all clean" reports — those become noise. Recovery messages are the only positive signal posted.
- **Bootstrapping.** First run with empty state file: classify all jobs as `healthy` (don't alarm on first observation). Build baseline silently. Real alerts start on second run.
- **Daemon-log absence is OK.** If `~/.myclaw-ot-bot/logs/myclaw.log` is missing/empty, skip step 4 and proceed with sqlite-only audit. Log a `degraded_inputs=daemon_log` flag in the HEARTBEAT_OK response.

Why this exists:
Operator (2026-05-12 in spaces/AAQAVOjYc80): "all your cron jobs shouldn't have silent failures. right? I'm expecting you will generate alerts for failures, then auto-triage and mitigate them. If errors consistently failing, send a gchat here. create a solution for this."

Concrete recent precedents:
- 2026-05-12 mitigated-sevs CLI hang: `myclaw jobs run` blocked at "Executing job..." for >10 min on two attempts, daemon never logged the firing. No automatic surfacing — operator only noticed because they were watching live. This watcher's "hung" detection (cron-firing-without-completion log pattern) catches that class.
- Various per-issue DEGRADED markers inside otherwise-healthy digests are intentionally not flagged (per step 3 nuance) — they're already surfaced inline. The watcher only alarms when failure dominates the response head.
- **2026-05-16 ordering-bug class added.** `ot-sev-monitor` posted main-space `🚨` notifications for S659877 (07:20 PT) and S664024 (04:24 PT) that were retracted as `[OUT-OF-SCOPE]` within 2–7 min by the R18 gate. The gate worked; it just ran too late in the cron's procedure. Step 6.5 detects this pattern via gchat messages-table join; a prompt-edit fix landed in `ot-sev-monitor.md` (ORDERING NOTE) the same day. Hysteresis prevents re-alerting until the prompt edit's commit timestamp is newer than the alert epoch.

Future extensions:
- v3 auto-mitigation patterns: **✅ `*→hung` kill-stuck-subprocess landed 2026-05-17 (thread `4GTCGhniXXU`)** with safety gates (allowlist + state-check + dedup) and SIGTERM-only (no SIGKILL). Still pending: per-keyword fix table for `silent_failure` (e.g., "BOT_INCOMPLETE: working copy dirty" → `cd ~/fbsource && sl status` to surface the dirty file). Build the table empirically from real failures observed in production.
- Slack/page integration if HIGH severity persists >6h.
- Cross-cron correlation: if multiple crons fail simultaneously, infer daemon-wide issue (auth token expired, network outage, etc.) and post a single rolled-up alert.

## Delivery discipline (HARD, 2026-05-30)

The daemon posts your final response to GChat verbatim unless it is EXACTLY `HEARTBEAT_OK`. Post ONLY on a real failure-state TRANSITION (new failure, persistent-failure escalation, or recovery). On a clean run (0 transitions, all jobs healthy) respond EXACTLY `HEARTBEAT_OK {jobs_audited: N, transitions: 0, alerts_posted: 0}` and NOTHING else — no "All clear.", no "State file updated.", no "Audit complete.", no summary block. Narration/no-op text leaks to chat as spam (operator 2026-05-30).

