[ot-post-monitor cron] Poll the MRS Online Training Users Workplace group (id 1084744250286987, vanity mrs.ot) for new posts since last successful run, classify by lane, post notification + DEEP-TRIAGE diagnosis for each substantive post.

**TEAM-SPACE GATE — surface only incidents that NEED A HUMAN (2026-05-30).** Post to the team space `spaces/AAQA2bZMw24` ONLY when the bot cannot fully handle the incident itself: either (a) triage confidence is LOW or MEDIUM (bot unsure → a human should look), OR (b) the verdict is a PAGE requiring a named human owner to act. If the bot fully handled it at HIGH confidence with no human action needed — NO_ACTION, auto-recovered, known-transient, or a confident MONITOR with nothing for a human to do — DO NOT post to the team space: record to state + the operator 1:1 (`meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<thread | `# new-topic`>`), then respond `HEARTBEAT_OK`. Rationale: the team space is the "bot needs help" lane; confidently auto-handled incidents are noise there. (Escalations — e.g. gchat-degraded ≥3 ticks — are exempt and still post.)

State file: /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-monitor-state.json — `{"last_post_epoch": <int>, "processed_post_ids": {"<post_id>": {"added_epoch": <int>, "notification_outcome": <string>}, ...}, "last_run_epoch": <int>}`. The `processed_post_ids` is a dict (post_id → {added_epoch, notification_outcome}); the bare-`<int>` value form is the legacy v2 schema and must be migrated in step 1. **`notification_outcome` schema (v3, 2026-05-27 T273158617)** — one of: `POSTED:<msg_resource_name>` (gchat notification sent + threaded reply created; resource name from `meta google.chat.message send -o json | jq -r .name`), `OOS:<reason>` (out-of-scope; e.g. `OOS:author_self`, `OOS:oncall_summary`), `DEDUP:<source>` (handled by another path), `ERROR:<one-line>` (send failed; details in raw_response). State advance with `notification_outcome` absent OR starting with `ERROR:` is a HARD FAIL — emit alert; do NOT silently mark processed. Time budget: ~5 min per substantive post. Out-of-scope and oncall_summary posts stay fast.

**MEASUREMENT-SUBSTRATE WRITE — MANDATORY per triaged post (RESTORED 2026-06-07).** At the SAME point you advance state with the post's `notification_outcome`, also write one `triage_events` row (ABSOLUTE path — relative `tools/…` does NOT resolve from the cron's runtime cwd; the 2026-06-07 "restore" used a relative path so the write kept failing `MISSING`, substrate unfed — same trap as `lib-url.sh`): `bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/record-triage-event.sh --sev-id <W###> --cron ot-post-monitor --signal "<one-line signal>" --confidence <0-1> --validator-outcome <confirmed|discrepancy|unavailable> --suggested-owner <unixname> --final-status "<verdict>" --notification-text "<one-liner>" --routed-to <auto|human>` — and, WHEN this run reached a confident root-cause verdict (root-cause: `known`, especially a cited P-row / known-pattern / R-rule match), ALSO append `--root-cause-at "$(date '+%F %T')"` to stamp WHEN the root cause was identified (feeds metric #1 time-to-root-cause via `tools/time-to-root-cause.sh`; omit the flag when root-cause is `partial`/`not found` so the column stays NULL). **`--routed-to` = the autonomy metric (`tools/escalation-rate.sh`, goal: human ≤5%): pass `human` whenever the TEAM-SPACE GATE above fired (you posted to `spaces/AAQA2bZMw24`); pass `auto` otherwise (1:1-only / NO_ACTION / auto-recovered / confident MONITOR).** Feeds `triage_events` (metrics-rollup / triage-auditor); the table went stale a month (only ot-sev-monitor wrote it, dropped ~2026-05-07). Shared helper (§14b/§14c). Skip ONLY a genuinely out-of-scope drop.

**CODE-MITIGATION AUTO-FIX GATE — MANDATORY after every REAL_OT_FAILURE / UPSTREAM_INFRA verdict (2026-06-11, operator: "how to make this automated instead of waiting me to nudge").** A code-rooted or code-mitigable failure must NOT stop at a posted verdict — that is the lag the operator flagged: e.g. `generate-job-config-diff` RE-throttle was classified UPSTREAM_INFRA and left at "monitor/retry"; the in-code retry/backoff fix only happened on a manual nudge (T275529522 / D108337795). The triage ALREADY produced a `file:line` code-pointer (the "code-pointer mandatory" rule). At verdict time, decide `code_mitigation`: is there a plausible IN-CODE resilience fix (retry/backoff/guard/timeout/fallback) in **MRS-OT-owned tooling**, EVEN IF the root cause is upstream? (The P-016/P-017 split — an upstream *cause* ≠ no in-code *mitigation*.)
- **YES → CLASSIFY before filing (2026-06-12, raise drafter conversion: the drafter only adds value on tasks it can SAFELY auto-fix; real/owner-owned issues just make it comment+skip, burning cycles and burying genuine handoffs). Two destinations:**
  - **(A) SAFELY-AUTO-FIXABLE** — the fix is in MRS-OT-owned tooling AND mechanically verifiable by the drafter without a human/owner: genuine no-data detector (the strict `one_detection_stats` no-data counts, NOT inferred from low volume), builder/config-fallback in our code, threshold-misfit that PASSES an adversarial no-mask check (replaying recent real fires misses none). → AUTO-FILE an `[OT auto-fix]` task NOW (handhold-first: `--owner=dennyzhang --add-tag=mvai-online-training`), title `[OT auto-fix] <symptom>: <fix-kind> at <file:line>`, body = symptom + traced root + candidate fix-site (the code-pointer) + the upstream caveat. The existing `ot-autofix-diff-drafter` then does the confirming source-dive + `--draft` diff — do NOT draft it here. Record on the `record-triage-event.sh` call: `--class <class> --code-mitigation task:T###`.
  - **(B) REAL-FAILURE or DEPENDENCY/OWNER-OWNED** — data shows a REAL violation (no-mask check FAILS: the symptom is a genuine degradation), OR the root cause is upstream / another team / a config not in MRS-OT's control. The drafter cannot safely fix this — routing it there only yields a comment+skip. → AUTO-FILE an **`[OT owner-handoff]`** task instead (`--owner=dennyzhang` ALWAYS per CLAUDE.md, NEVER assign others; `--add-tag=mvai-online-training`; add the owning team/person as a SUBSCRIBER), title `[OT owner-handoff] <symptom> at <when>`, body = the **decisive, reproducible metric query as EVIDENCE** (P-017: the ground-truth query/link that confirms the issue AND is the acceptance test for the upstream/owner fix) + the no-mask finding (what real fire would be masked if this were silenced) — NOT a re-narrated symptom. Record on the `record-triage-event.sh` call: `--class <class> --code-mitigation owner-handoff:T###` (and `--upstream-confirm <query>` for UPSTREAM_INFRA). **Do NOT route owner-handoff tasks to the drafter** (no `[OT auto-fix]` title prefix → the drafter's query never picks them up).
  - The deterministic backstop is unchanged: a code-rooted class recorded WITHOUT `--code-mitigation` is stored `MISSING` + warns, so a skipped gate is caught even if this prose step is missed.
- **NO** → record `code_mitigation: none (<reason: not-MRS-OT-code | no-in-code-fix | one-off-transient>)`.
- **UPSTREAM OBSERVABILITY (UPSTREAM_INFRA verdicts) — emit `upstream_confirm`:** a runnable query or resolvable link that confirms the upstream root from GROUND TRUTH (the upstream SEV / the ODS-canvas metric / a Scuba query) — the P-017 decisive metric, which doubles as the upstream fix's acceptance test. Pass it via `--upstream-confirm` on the `record-triage-event.sh` call. "It's upstream" must be VERIFIABLE, not narrated — the helper records `MISSING` + warns if an UPSTREAM_INFRA verdict omits it.
- **RECONCILE-ASSERT (the anti-lag enforcement):** a REAL_OT_FAILURE / UPSTREAM_INFRA verdict whose triage_events row carries NO `code_mitigation` decision (or, for UPSTREAM_INFRA, no `upstream_confirm`) is INCOMPLETE — do not finish the run without it. This makes source-dive→task a required mechanical step, not a prose expectation that gets skipped under triage focus.
- **NOISE GATE + CAP:** auto-file only when the fix-site is MRS-OT-owned tooling AND the failure is recurring OR high-confidence-code-rooted; cap ≤2 auto-fix tasks/run (combine with any existing auto-fix cap in this cron; excess defers — recurring failures resurface). Dedup: skip if an open `[OT auto-fix]` task already covers the same file/symptom.

**Dedup model** — per-id set (`processed_post_ids`) is authoritative; `last_post_epoch` is a coarse pre-filter only. Same pattern as ot-sev-monitor (`diagnosed_ids`) and ot-alert-monitor (`diagnosed_ids`). Pre-2026-05-12 the cron used epoch-cutoff alone, which re-fired any post whose `effective_freshness_time` regressed under it (move-in/late-comment race) — caused 11 duplicate notifications for a single post (Jianhui Sun, 1218910203488316, 2026-05-12 00:01-06:29 UTC). Per-id dedup eliminates that class of bug.

Procedure:
0. **Concurrent-run guard (2026-05-27, concurrent-execution race confirmed).** Before reading the state file, acquire an exclusive run lock to prevent duplicate processing when a long run overlaps the next scheduled tick (confirmed: 15:13 run [568s] and 15:20 run [101s] overlapped on 2026-05-27):
   ```bash
   LOCKFILE="/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-post-monitor.lock"
   LOCK_MAX_AGE=900  # matches cron interval — older lock is stale/crashed
   NOW=$(date +%s)
   if [ -f "$LOCKFILE" ]; then
     LOCK_TIME=$(cat "$LOCKFILE" 2>/dev/null || echo 0)
     LOCK_AGE=$((NOW - LOCK_TIME))
     if [ $LOCK_AGE -lt $LOCK_MAX_AGE ]; then
       echo "[ot-post-monitor] Another instance running (lock age=${LOCK_AGE}s). Exiting."
       exit 0
     fi
     echo "[ot-post-monitor] Stale lock (age=${LOCK_AGE}s). Proceeding."
   fi
   echo "$NOW" > "$LOCKFILE"
   ```
   If the lock is fresh (age < 900s), exit immediately with HEARTBEAT_OK — do NOT process posts. Release the lock (delete lockfile) as the LAST action after writing state in step 6.

0.5. **GChat-read recovery + tick instrumentation (2026-05-28 L66+L67+L68; inlined 2026-05-28 L69 after Risk B audit in thread `4BK7HJHkzB0`).** Every `meta google.chat.message list/get` and `gchat read` call later in this prompt MUST be wrapped with the recovery protocol below. The wrapper is duplicated verbatim in `ot-sev-monitor.md` + `ot-alert-monitor.md` because cron agents load only their own prompt file and cannot cross-reference each other's wrapper definitions. Keep all 3 in sync when amending.

   **Per-tick counters (init at run start):**
   ```bash
   GCHAT_403_SEEN=0          # 1 if any GChat read returned 403 this tick
   BUCK2_REFRESH_ATTEMPTED=0 # 1 if we ran `buck2 run` to refresh OAuth
   BUCK2_REFRESH_OK=0        # 1 if the post-refresh retry succeeded
   GCHAT_LAST_OK_EPOCH=$(jq -r '.gchat_health.last_ok_epoch // 0' "$STATE_FILE" 2>/dev/null || echo 0)
   ```

   **Recovery wrapper (use for every gchat read in this prompt):**
   ```bash
   gchat_read_with_recovery() {
     # $1 = full meta google.chat.message list command; echoes stdout on success, returns exit code
     local cmd="$1" out err exit_code
     err=$(mktemp); out=$(eval "$cmd" 2>"$err"); exit_code=$?
     if [ $exit_code -eq 0 ]; then
       GCHAT_LAST_OK_EPOCH=$(date +%s)
       rm -f "$err"; echo "$out"; return 0
     fi
     if grep -qE '403|Unauthorized|forbidden|invalid_grant|token (has |)expired' "$err"; then
       GCHAT_403_SEEN=1; BUCK2_REFRESH_ATTEMPTED=1
       echo "[ot-post-monitor] GChat 403 detected — refreshing OAuth via buck2 run" >&2
       (cd /home/dennyzhang/fbsource && buck2 run fbcode//pe_mrs_ml/mrs_ot_agent:scope_check -- --help) >/dev/null 2>&1 || true
       out=$(eval "$cmd" 2>"$err"); exit_code=$?
       if [ $exit_code -eq 0 ]; then
         BUCK2_REFRESH_OK=1; GCHAT_LAST_OK_EPOCH=$(date +%s)
         rm -f "$err"; echo "$out"; return 0
       fi
     fi
     local err_head; err_head=$(head -c 200 "$err"); rm -f "$err"
     echo "[ot-post-monitor] GChat read FAILED post-refresh: $err_head" >&2
     return $exit_code
   }
   ```

   **Consecutive-403 escalation gate:** if `BUCK2_REFRESH_ATTEMPTED=1 AND BUCK2_REFRESH_OK=0`, increment `gchat_health.consecutive_403_count` in state. If counter ≥3 across runs, at end of run post ONE escalation line to spaces/AAQAVOjYc80 with `--as-meta-bot`: `🚫 GChat reads degraded ≥3 ticks — tried buck2 run; need help (consecutive=$N, last_ok=<HH:MM PT>)`. Reset on any successful read.

1. Read state file. Extract `last_post_epoch` (coarse cutoff) and `processed_post_ids` (dict of post_id → {added_epoch, notification_outcome}). If file missing/corrupt: default cutoff = (now - 600s), processed_post_ids = empty dict, create file fresh. **Migrations (idempotent, run both):**
   - v1→v2: if `processed_post_ids` is a bare list (pre-2026-05-12), upgrade by mapping each id → `now()` (original timestamp lost). Log once.
   - v2→v3: if any entry's value is a bare `<int>` (post-2026-05-12, pre-2026-05-27), upgrade in-place to `{"added_epoch": <int>, "notification_outcome": "LEGACY_UNKNOWN"}`. Log once. `LEGACY_UNKNOWN` is grandfathered for the prune window but counts toward Fix 3 anomaly detection if it persists past 14d.
2. Run: meta workplace.group activity-feed --group-id=1084744250286987 --columns=post_id,author,message,publish_time_epoch,url --sort-order=desc --limit=20 -o json
3. Determine each post's effective freshness time BEFORE filtering, so posts moved into the group with stale `publish_time_epoch` aren't dropped:
   a. Default `effective_freshness_time = publish_time_epoch`.
   b. For posts where `publish_time_epoch <= cutoff` (would be filtered out as stale), fetch comments via `meta workplace.comment list --post-id=<post_id> --output=json --no-truncate` and scan for the literal `#movebot` directive OR a `Move Bot` author. If present and the move comment's `time` > cutoff, set `effective_freshness_time = move_comment_time` — moved-in posts have stale `publish_time_epoch` but are fresh-to-this-group as of the move. Cache the fetched comment list keyed by post_id so step 5.a.1 can reuse it.
   c. Filter to posts with `effective_freshness_time > cutoff` AND `post_id NOT IN processed_post_ids`. Drop posts authored by "MyClaw" / "ot-bot" / yourself (avoid feedback loops). The per-id check is the strong dedup; the cutoff is just a pre-filter so we don't fetch comments for ancient posts on every poll.
   Gap context: post 1215710353808301 was moved via `#movebot` from MVAI Users at 14:27 PT, original `publish_time_epoch` was 11:14 PT — the prior step-3 filter (publish_time_epoch only) missed it. Per-id dedup (added 2026-05-12) handles re-fires from late comments and re-moves correctly: once a post_id is in `processed_post_ids`, it stays skipped regardless of comment churn.
   d. **Prune `processed_post_ids`**: drop entries where `now() - entry.added_epoch > 14 days` (note: access `.added_epoch` since v3 schema is a dict, not bare int). Fixed TTL based on insertion time — evaluable from stored data alone. 14d > worst-case mrs.ot post lifecycle (typical = hours, longest observed = ~3d for stickied threads); aged-out post returning via re-move after 14d is a non-issue. Pruning is bounded — set size = posts seen in last 14d × ~2 posts/day = ~30 entries steady-state.
   d.1. **For each post processed in step 5 below**: add to `processed_post_ids` as `{post_id: {"added_epoch": now_epoch, "notification_outcome": <captured_in_step_5.h>}}`. The added_epoch is the cron-tick time when the id was first written. The notification_outcome MUST be set from the actual API response captured during step 5.c / 5.f / 5.b — NEVER write a "POSTED:..." outcome without a real message resource name from `meta google.chat.message send -o json | jq -r .name`. Synthesizing outcomes is the root cause of T273158617 (2026-05-27).
4. If no new posts: update last_run_epoch to now, respond HEARTBEAT_OK and stop.
5. Otherwise, for each new post (oldest first, cap 5 per run):
   a. Fetch FULL post body via: meta workplace.post content --post-id=<post_id> --columns=author,time,body -o json. Activity-feed message is truncated at 80 chars; classification on truncated text misses real OT issues.
   a.1. **Fetch comments — MANDATORY** (was missing pre-2026-05-07; gap source: post 1215710353808301): if the comment list was already fetched and cached in step 3.b, reuse it; otherwise call `meta workplace.comment list --post-id=<post_id> --output=json --no-truncate`. Comments often contain root-cause diagnoses from peer agents (MoDA, Confucius), human follow-ups, and `#movebot` move records. Classification + diagnosis must consider BOTH body AND comments. If a peer agent (`MoDA`, `Confucius`, `🤖`) has already posted a root-cause comment, surface it in the diagnosis output (do NOT re-derive from scratch — cite the peer-agent finding and verify it).
   b. **Pre-skip:** If title (first line of body, stripped of leading # / *) starts with "Oncall Summary" (case-insensitive), classify as `oncall_summary`. Send brief notification; capture returned name per step 5.c.send-discipline. Set `NOTIFICATION_OUTCOME="POSTED:$NOTIF_NAME"` (or `OOS:oncall_summary` if send fails — log and continue, do not block). NO threaded triage reply (status posts, not asks). Advance state with the captured outcome and continue.
   c. **Send notification to spaces/AAQAVOjYc80 — capture msg name (T273158617 Fix 2 + 2026-05-27 hardening).** Text format: `🛟 [OT post] <author>: <first 100 chars of body, no newlines> — <url>`. Use the **separated-stderr + exit-code-gated** pattern (DO NOT use `2>&1` — stderr deprecation warnings break jq parse and produce false-ERROR; DO NOT use `2>/dev/null` on jq — silent parse fail hides bugs):
      ```bash
      ERR_TMP=$(mktemp)
      NOTIF_STDOUT=$(meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --as-meta-bot --text="$NOTIF_TEXT" -o json 2>"$ERR_TMP")
      NOTIF_EXIT=$?
      NOTIF_STDERR=$(cat "$ERR_TMP"); rm -f "$ERR_TMP"
      if [ "$NOTIF_EXIT" -ne 0 ]; then
        NOTIFICATION_OUTCOME="ERROR:notif_send_exit_${NOTIF_EXIT}:$(echo "$NOTIF_STDERR" | head -c 160)"
        NOTIF_NAME=""; THREAD_ID="SEND_FAILED"
      else
        # jq -e: nonzero exit on null/missing; capture stderr so we see parse errors
        NOTIF_NAME=$(echo "$NOTIF_STDOUT" | jq -er '.name' 2>&1) || {
          NOTIFICATION_OUTCOME="ERROR:notif_parse_failed:$(echo "$NOTIF_NAME" | head -c 100)|stdout=$(echo "$NOTIF_STDOUT" | head -c 60)"
          NOTIF_NAME=""; THREAD_ID="SEND_FAILED"
        }
        if [ -n "$NOTIF_NAME" ]; then
          THREAD_ID=$(echo "$NOTIF_STDOUT" | jq -er '.thread' 2>/dev/null | awk -F/ '{print $NF}')
          NOTIFICATION_OUTCOME="POSTED:$NOTIF_NAME"
        fi
      fi
      echo "[ot-post-monitor] post=$POST_ID outcome=$NOTIFICATION_OUTCOME thread=$THREAD_ID"
      ```
      **Structural URL gate (T273158617 Fix 5, 2026-05-27).** The `Bot reply:` URL in step 6's run summary is **rendered conditionally**: emit `- Bot reply: https://chat.google.com/room/AAQAVOjYc80/$THREAD_ID` **only if `$THREAD_ID` is non-empty AND not `SEND_FAILED`**. Otherwise emit literal `- Bot reply: SEND_FAILED (outcome=$NOTIFICATION_OUTCOME)`. Never write a Bot reply URL using a thread ID that didn't come out of the `.thread` field of this exact send's response. Fabricating thread URLs is the T273158617 anti-pattern (run #6517 synthesized `yF_aMB00xMk` from operator's unrelated thread).
   d. Classify lane against FULL body using these patterns, in order — first match wins:
      - `sev_id`         (95%): /\bS\d{6,}\b/
      - `mast_job_id`    (90%): /\bmvai-training-online-\d{8,}\b/
      - `mlhub_url`      (85%): /(?:fburl\.com|internalfb\.com)\/mlhub\/\S+/
      - `model_series`   (80%): /\bm\d{8,}\b/  OR  /(?:^|\s)-m\s+\d{8,}/
      - `workplace_post` (70%): /https?:\/\/(?:fb\.)?workplace\.com\/groups\/[^\/\s]+\/(?:permalink|posts)\/\d+/
      - `runbook_path`   (60%): /https?:\/\/(?:www\.)?internalfb\.com\/wiki\/\S+/
      - `paste`          (50%): /\bP\d{7,}\b/  — only when title contains OT-issue keyword
      - `diff`           (50%): /\bD\d{8,}\b/  — only when title contains OT-issue keyword
      - `ot_general`     (40%): no ID matched, but title contains OT-issue keyword (job, fail, error, train, snapshot, publish, OT, mvai, NaN, NCCL, timeout, restart, latency, QPS) — flag for human review
      - `out_of_scope`   (0%): nothing matched; not OT-flavored content
   e. DEEP TRIAGE — required for every lane EXCEPT `out_of_scope` and `oncall_summary`. Load `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/SKILL.md` if not loaded. Then execute:

      i. **Ground-truth verification.** Pull data that confirms or falsifies leading hypothesis. For `mast_job_id`/`mlhub_url`: `meta ai.mast-job metadata --name=<id>` + `meta ai.mast-job error --name=<id>` + `meta ai.mast-job attempts --name=<id>`. For `model_series`: `meta ai.model.instance list --model-id=<id> --limit=30 --sort-by=creation_time --sort-order=desc --columns=instance_id,creation_time,snapshot_type,state -o table`. For `sev_id`: `meta sevmanager.sev metadata --sev=<id>`. Lane match is OPENING of triage — falsify or confirm before publishing.

      i-c. **Read SEV live GChat — MANDATORY (with recovery wrapper, 2026-05-28 thread `4BK7HJHkzB0`).** Metadata is a snapshot; GChat carries current state. Extract gchat_space_url, parse space ID (after /room/). **MUST invoke via `gchat_read_with_recovery` from step 0.5** — DO NOT run raw `gchat read` / `meta google.chat.message list` (bypasses OAuth-403 self-heal + skips per-tick instrumentation). Concrete: `gchat_read_with_recovery "meta google.chat.message list --space-id=$SEV_SPACE --limit=20 -o json"`. Parse for active hypotheses, paste links, ETA, contradictions. Cite as `[VERIFIED via gchat read <space_id>]` on success OR `[UNAVAILABLE: gchat 403 post-refresh]` on hard-fail (continue triage; do NOT abort). Source: S657811 + same-wiring-fix as ot-sev-monitor (wrapper was dead code before this amendment).

      i-d. **MANDATORY trainer-liveness probe — BEFORE any D-class (publish) or E-class (DPP/QPS) hypothesis.** When the post symptom set includes ANY of: "snapshot stuck CREATING", "FS publish stalled", "missing SPARSE_DELTA/DENSE_DELTA", "DPP reader QPS ≈ 0", "low input QPS", "checkpoint cadence broken" — run the trainer-Python liveness probe FIRST: `meta scuba.dataset query -d mvai_metrics --view=samples --columns=time -w '[{"column":"model_entity_id","op":"eq","values":["<MODEL_ID>"]}]' --hours=12 -l 1 --order-by=time`. **If latest sample > 5 min stale AND MAST attempt status is RUNNING → the trainer Python interpreter is hung (P44/A1 GIL hang, or A2/A3 C++/storage stall depending on live process inspection)**; downstream stuck-CREATING snapshots and low DPP QPS are CONSEQUENCES, not roots. Do NOT propose D-class (TGIF, Hedwig, UMM publish) or E-class (DPP starvation) hypotheses until A is falsified by a fresh mvai_metrics sample. Cite verbatim: `[VERIFIED: mvai_metrics latest_sample=<timestamp>, gap_min=<N>, attempt_status=<S>]`. Source: 2026-05-13 model 2135033479 + 883552231 — first triages misdiagnosed both as TGIF/checkpoint_agent stuck. See `known-patterns.md` § Cause-vs-consequence map and P44.

      ii. **Active-SEV cross-reference.** Run `meta sevmanager.sev list --tags=mvai-online-training --created-after="3 days ago" -o json --limit=10`. For each open SEV with adjacent signal class (publish-related post + open publish-related SEV → likely shared infra), flag SEV id + link.

      ii-a. **R20 — SAME-WORKLOAD RECURRENCE (4-source).** Check the same model across 4 sources (extended 2026-05-17 thread `Uc-pVBEXNQ8` 11:18 PT per P-003):
         1. SEVs: `meta sevmanager.sev list --title-contains="<MODEL_ID>" --limit=20 -o json` (180d+ retention)
         2. Cleared alerts: `meta monitoring.alert list --alert-contains="<MODEL_ID>" --state-is=CLEARED --start-time=$(date -d '30 days ago' +%s) --limit=20` (<30d retention)
         3. Local archives: `grep -lr "<MODEL_ID>" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-{sevs,posts,alerts}/ | grep -vE "/(INDEX|README|MISSING|NOISY-MODELS)\.md$"`
         4. Mega-learnings: `grep -lr "<MODEL_ID>" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/learnings/digests/` — hits in failure-patterns.md = canonical CL-NNN already mapped (first-class signal)

         If 2+ prior incidents had same mitigation → short-circuit hypothesis. Cite: `[VERIFIED: model_<MODEL_ID> prior_SEVs=N; prior_alerts=N|unverified; local_archives=[...]; cluster_evidence=[<CL-NNN>, ...]; mega_learnings=[...]]`. Source: operator 2026-05-17 thread `r70kC-3eghA` + `Uc-pVBEXNQ8`.

      ii-b. **R21 — CROSS-WORKLOAD PATTERN.** After R20, check family for the same symptom: extract model_type_name; sweep `meta sevmanager.sev list --tags=mvai-online-training --in-progress --title-contains="<family_keyword>"`; map symptom to CL-NNN in `mrs-ot-agent-context/learnings/patterns/failure-patterns.md`. 2+ sibling models same symptom 24h → family-wide escalation. Cite: `[VERIFIED: family=<model_type_name>, sibling_sevs_7d=<N>, matching_cluster=<CL-NNN or none>]`.

      iii. **Owner correction.** For `model_series`/`mast_job_id`/`mlhub_url`: run `meta ai.model-series metadata --model-id=<MODEL_ID>` (resolve job → model first). Compare against post author's ownership signal. If they differ, list BOTH: post author (asker) AND actual model owner (escalation target).

      iv. **Hypothesis chain.** Take leading pattern from known-patterns.md. State explicitly. Test against ground-truth from (i). If contradicted, falsify in writing and switch to secondary candidate. Repeat until standing hypothesis is data-consistent — or report "no known pattern matches; needs human investigation."
   v. **Quality rules** (SKILL.md + D103543146) — ALL must appear in every diagnosis:
      - **Baseline before anomaly**: cite known-good window for any "broken/slow/wrong" claim.
      - **Layered hypothesis enumeration**: name every layer; rule each in/out with data. No single-hypothesis diagnoses.
      - **Code-pointer mandatory**: every "fix X" cites file path + line number.
      - **Tiered recommendations**: SHORT (≤1 day, config flip) / MEDIUM (≤1 week, cross-team) / LONG (weeks+, refactor).
      - **Soft cross-references include verification step**: "if X upstream of Y" cross-refs MUST include verification command BEFORE contingent action.

   v.1. **R18 HARD pre-publish gate — diagnosed-stage scope re-check.** AFTER quality rules pass and BEFORE the diagnosis is published as a Workplace reply, classify the diagnosed root cause's pipeline stage: T1 (DPP / Scribe ingestion), T2 (training: trainer process, NCCL, OOM, GIL hang, schedule/PG), T3 (publishing: TGIF / GMPP / SilverTorch publish path / fbpkg / FS publish), T4 (serving: ICSP / RAAS / Multifeed / predictor config), or out-of-pipeline (model-lifecycle: launch gate, decommission, solver_mode). **If diagnosed stage is T4 (serving) or out-of-pipeline, do NOT publish the OT-routed diagnosis as a Workplace reply.** The asker may still be in scope (Workplace post in mrs.ot group), but the diagnosis itself names a stage owned by a different team — redirect explicitly: "This is a <stage>-stage issue (<owner>); routing there." Tag-based routing (post hit OT lane via group membership) is necessary but NOT sufficient — the diagnosed root cause is the authoritative scope signal. **Falsifier**: diagnosed stage is T1/T2/T3 → publish full diagnosis. Source: 2026-05-13 S661843 (sibling SEV cron mis-routed serving-stage SEV to OT lane). See R18 in `references/triage-discipline.md`.

   vi. **Diagnosis output template** — three appendix sections after standing hypothesis + recommendations. ALL MANDATORY:
      - **Raw log Evidence appendix** (lettered A, B, C...): literal log lines + timestamps + ranks. Hypothesis cites inline (e.g., "NE stalled 22:03→22:40 [Evidence D, F]").
      - **Investigation Commands appendix** (numbered): replayable `meta` / `tw log` commands. For `tw log`, see `references/tw-log-recipes.md` (D103543146).
      - **Files-touched table**: `| path | 1-line role |` for any "fix in X" recommendation.
      Source: 2026-04-30 velvinfu paste P2300957350.

      For `paste`/`diff`/`ot_general` low-confidence lanes: still run (i)+(ii) but be explicit lane match is weak — frame diagnosis as research starting point, not verdict.

   f. Send threaded reply using **crisp 5-element template** per [`human-input-generic/report-templates/crisp-report-style.md`](../../human-input-generic/report-templates/crisp-report-style.md). Workplace posts in `mrs.ot` are CROSS-TEAM facing; verbose 9-section output goes to a paste, NOT the post body.

      **Step f.1 — Create paste FIRST with LOCKED verbose format (2026-05-16).** Mirrors `ot-alert-monitor` / `ot-sev-monitor` so `ot-daily-learning-debugging` parses all three crons with one parser. Operator feedback 2026-05-16 thread `6pKeH_XqjcE`: "shouldn't we also update the post monitor one?" — yes.

      Paste content uses the same fixed 9-section template + verdict header + JSON block:

      ```
      [ot-bot verbose diagnosis | <post permalink>]

      <VERDICT HEADER LINE — 🟢/🟡/🔴/⚪ ACTION · root-cause: <status> · class: <class> · confidence: <level>>

      *Lane*: <lane> (X%) | post author: <unixname>

      *Model*: <id> (<name>) | pg: <PG> | role: <model_role> | owner: <unixname> / <oncall>
        — OR — (no model in post) —
      *Subject*: <one-line description of the artifact: paste/diff/runbook/SEV/etc.>

      *What happened*: <one paragraph. names exact metric/snapshot-type/symptom that's breaking; for delta symptoms name SPARSE_DELTA vs DENSE_DELTA vs FULL_SNAPSHOT EXPLICITLY — do NOT lump together; user-visible breakage; concrete metric values; timestamps>

      *Evidence*:
      • <fact 1> [VERIFIED via <cmd>]
      • <fact 2> [VERIFIED via <cmd>]
      • <fact N — include any cross-SEVs as evidence bullets>

      *Hypothesis & implication*: <surviving cause + what it implies for the operator. Single paragraph.>

      *Ruled out*:
      • <hypothesis> — <contradicting fact + source>

      *Cross-SEVs*: (folded into Evidence bullets above as of 2026-05-17 restructure)

      *Next actions*:
      1. <action with owner + concrete command>

      📊 Machine fields: <paste_url>

      **JSON moves to paste (added 2026-05-17 thread `SN72CzuckRQ` after operator: "do I really need to see it as a human?").** Build the JSON object (schema below), pipe through `pastry -t "$POST_ID-machine-fields" --md`, embed the resulting URL in the gchat message as `📊 Machine fields: $PASTE_URL`. ALSO include the full JSON in `raw_response` (sqlite job_runs) so downstream consumers that scrape sqlite still work.

      **CONTENT-lint (MANDATORY, 2026-05-17 thread `suPsRC2fGdc`):**
      - R20 ran with N>0 prior incidents → Evidence MUST include `[VERIFIED: model_<ID> prior_incidents=`.
      - R21 ran with matching_cluster!=none → Evidence MUST include `[VERIFIED: family=<model_type_name>`.
      - **CL-NNN citation MANDATORY** when symptom matches a known cluster (failure-patterns.md). Cite by ID in Evidence + Hypothesis & implication.
      - **P-row citation MANDATORY** when symptom matches a known P-row (known-patterns.md). Cite as `Apply P<NN>: <mitigation>` in Next actions.
      Same gap as ot-alert-monitor + ot-sev-monitor; live triage on 878858380 at 10:18 PT 2026-05-17 (thread `akCTORdwUK4`) did the work but didn't cite catalog entries.

      JSON schema (rendered in paste, not gchat):
      ```json
      {
        "verdict": "<NO_ACTION|MONITOR|PAGE|UNKNOWN|OUT_OF_SCOPE>",
        "class": "<enum value>",
        "root_cause_status": "<known|partial|not_found>",
        "confidence": "<high|medium|low>",
        "auto_resolved": <true|false>,
        "post_id": "<id>",
        "post_lane": "<lane from step d>",
        "post_author": "<unixname>",
        "pg": "<IG|Threads|Video|Facebook|infra-cross-pg|Ads|other|unknown>",
        "model_id": "<id or null>",
        "model_name": "<full name from meta ai.identify, e.g. facebook_reels_ifu_mtml_v0, or null>",
        "model_lane": "<ranking|retrieval|unknown>",
        "model_role": "<trainer|stus|unknown>",
        "owner": "<unixname>",
        "oncall": "<oncall name>",
        "signal_specifics": {
          "metric_class": "<snapshot|data_age|scribe_lag|latency|detector_no_data|other>",
          "metric": "<e.g. SPARSE_DELTA cadence, checkpoint_training_data_age_mins>",
          "affected_snapshot_types": ["SPARSE_DELTA"],
          "healthy_snapshot_types": ["DENSE_DELTA", "FULL_SNAPSHOT"]
        },
        "ruled_out": ["<hypothesis 1 (P-row or R-rule id)>", "<hypothesis 2>"],
        "related_sevs": ["S<id>"],
        "validator_status": "pending"
      }
      ```

      **Compatibility for downstream JSON consumers:**
      - **`raw_response` (sqlite job_runs)** still contains the full JSON block as a code-fenced section after the narrative. `ot-postmortem-validator`, `ot-knowledge-curation`, `ot-cron-health-guard`, `ot-human-attention-brief` all read from `raw_response` — NO change to them.
      - **Validator updates** edit the PASTE content (via `pastry <paste_id>` overwrite), NOT the gchat message. Paste link stays stable.
      - **Fallback:** if `pastry` fails or times out (>10s), inline the JSON in the gchat message with `⚠️ paste creation failed` prefix.

      ## Evidence appendix (lettered A/B/C):
      <verbatim log lines, timestamps, ranks>

      ## Investigation Commands appendix (numbered):
      <replayable meta / tw log commands>

      ## Files-touched table:
      <path | role>   (omit ENTIRELY if no code-fix proposed)
      ```

      **Verdict header rules** (same as alert/sev monitors):
      - `🟢 NO ACTION` — false positive OR auto-resolved with known benign cause
      - `🟡 MONITOR` — self-resolving in progress OR upstream infra issue tracked elsewhere
      - `🔴 PAGE <owner>` — real failure requiring human
      - `⚪ UNKNOWN` — root cause not found; deeper investigation needed
      - `🚫 OUT-OF-SCOPE` — R18 stage-drop; single-line, no further diagnosis

      **`class` enum** (same v1 enum as alert/sev): `THRESHOLD_MISFIT` / `DETECTOR_BROKEN` / `MISCONFIG_AGG` / `TRANSIENT_NOISE` / `UPSTREAM_INFRA` / `REAL_OT_FAILURE` / `CONVEYOR_REGRESSION` / `ZOMBIE_SEV` / `NEEDS_INVESTIGATION`.

      **`confidence` rubric**: `high` = ground-truth ✓ + ≥2 ruled-out hypotheses. `medium` = ground-truth ✓ + 1 ruled-out. `low` = ground-truth incomplete OR no ruled-out OR pattern-match only.

      **`model_name` derivation**: from `meta ai.identify --query=<MODEL_ID>` or `meta ai.model-series metadata --model-id=<MODEL_ID>` — the actual series name, e.g. `facebook_reels_ifu_mtml_v0`. **CRITICAL anti-pattern (2026-05-16):**
      - `model_name` is the SERIES NAME — NEVER substitute owner unixname, oncall name, model_id, or any other identifier. Source: 2026-05-16 thread `-7JtEC9JAGw` where cron emitted `"model_name":"shuyaoli"` (the owner) for model 2144816217.
      - `owner` is the unixname — populated separately from `model_name`.
      - If `meta ai.identify` returns empty or errors, render `model_name: "unknown"` rather than substituting a different identifier.

      NEVER substitute a derived label.

      Create the paste:
      ```bash
      meta paste.paste create --content="<above template>" --language=text --title="ot-bot diagnosis: <symptom> on <model_or_job>"
      ```

      Capture the returned paste id (e.g., `P2315669002`).

      **Step f.2 — Render the threaded reply in crisp style** (5 elements, ~6-7 lines, under 600 chars body — unchanged from prior):

      ```
      # [OT triage] <job-id-or-model> (<class>) — <symptom> at <when>

      **PROBLEM**: <one sentence + 1-2 supporting numbers — last-good timestamp, gap duration>

      **LIKELY CAUSE**: <one sentence + path:line code-pointer per Quality Rule R3. If unverified, prefix `[INFERRED]` and omit the code-pointer.>

      Detail reporting: [P<paste_id>](https://www.internalfb.com/intern/paste/P<paste_id>)

      **ASK**: <one sentence — who needs to do what; page-tag if specific>
      ```

      **Step f.2.send — capture the threaded-reply msg name (T273158617 Fix 2 + 2026-05-27 hardening).** Same separated-stderr + jq -e pattern as step 5.c:
      ```bash
      if [ -n "$THREAD_ID" ] && [ "$THREAD_ID" != "SEND_FAILED" ]; then
        ERR_TMP=$(mktemp)
        REPLY_STDOUT=$(meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --as-meta-bot \
          --reply-in-thread=spaces/AAQAVOjYc80/threads/$THREAD_ID \
          --text="$CRISP_REPLY_TEXT" -o json 2>"$ERR_TMP")
        REPLY_EXIT=$?
        REPLY_STDERR=$(cat "$ERR_TMP"); rm -f "$ERR_TMP"
        if [ "$REPLY_EXIT" -ne 0 ]; then
          NOTIFICATION_OUTCOME="ERROR:reply_send_exit_${REPLY_EXIT}:$(echo "$REPLY_STDERR" | head -c 160)"
        else
          REPLY_NAME=$(echo "$REPLY_STDOUT" | jq -er '.name' 2>&1) || {
            NOTIFICATION_OUTCOME="ERROR:reply_parse_failed:$(echo "$REPLY_NAME" | head -c 100)"
            REPLY_NAME=""
          }
        fi
        # On reply success, $NOTIFICATION_OUTCOME remains POSTED:<notif_name> from step 5.c — the threaded reply is the diagnosis body but the notif msg is the durable thread anchor; downstream consumers track by notif_name.
      fi
      ```
      Notice: if step-5.c notification send failed, the diagnosis reply is NOT sent (no thread to reply to). The diagnosis paste still exists; the operator can find it via T273158617 followup audit.

      **Step f.3 — Drop the prefix.** Do NOT prefix the reply with `[ot-bot diagnosis | confidence: X%]` or `[ot-bot | confidence: ... | suggested owner: ...]`. These are internal-debug noise on external-facing surfaces.

      **Cap**: ~600 chars body, 1000 chars hard cap. If the diagnosis genuinely needs more, expand the paste, not the post. For low-confidence lanes (paste / diff / ot_general): the LIKELY CAUSE line gets `[INFERRED]` prefix + add a sixth line: `Note: lane match weak — diagnosis is research starting point, not verdict.`

      End ALWAYS with: `Post: <url>` on its own line (existing rule preserved for traceability).

   g. **VALIDATOR PASS** (skip for `out_of_scope` and `oncall_summary` lanes) — spawn independent agent via Agent tool with prompt: "Validate this OT post triage. Re-read diagnosis I just published in spaces/AAQAVOjYc80 thread <thread_id>. Independently run ground-truth queries diagnosis cites. Cross-check standing hypothesis against actual data. Report: (a) confirmed | (b) discrepancies + what data contradicts what. Under 300 words. Do NOT see my reasoning, only the published diagnosis."

      **In-place update of the paste, NOT new gchat message.** After validator returns, EDIT the paste created in step f.1: replace `*Validator*: ⏳ pending` with `*Validator*: ✓ confirmed` or `*Validator*: ⚠ <discrepancy>`. Also update the JSON block field `"validator_status"` from `"pending"` to `"confirmed"` / `"discrepancy: <one-liner>"`. Use `meta paste.paste update --paste-id=<id> --content=...`. Avoids the two-message-with-30s-gap pattern that skimmers miss. Source: 2026-05-16 operator feedback thread `6pKeH_XqjcE`.

      If subagent / Agent tool is unavailable (cron context limitation — see L6 in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md`), DO NOT spawn the subagent. Update the paste's validator field to: `*Validator*: 🚫 unavailable (no Agent tool in cron context)`. JSON: `"validator_status": "unavailable"`.

   h. Update state file IMMEDIATELY after validator pass completes:
      - Append `post_id` to `processed_post_ids` with the v3 schema: `{"<post_id>": {"added_epoch": <now_epoch>, "notification_outcome": "$NOTIFICATION_OUTCOME"}}`. **HARD GATE (T273158617, 2026-05-27):** if `$NOTIFICATION_OUTCOME` is unset OR starts with `ERROR:`, DO NOT silently mark processed — instead set outcome to `ERROR:<reason>` and emit a warning line to raw_response that `ot-cron-health-guard` will pick up. State advance with no real send is the silent-OOS-drop bug; keep the entry so we know we tried, but flag it.
      - Set `last_post_epoch = max(last_post_epoch, effective_freshness_time)` (NEVER regress; use the freshness time, not raw publish_time_epoch — moved-in posts must advance the cutoff past the move time, not the original publish time, otherwise the next run re-evaluates them as fresh).
6. After loop: update last_run_epoch to now, **persist `gchat_health` block per step 0.5 protocol** (see `ot-sev-monitor.md` step 10 for the jq merge recipe + consecutive-403 escalation gate; identical here with `ot-post-monitor` in log/escalation prefixes). **Release the run lock from step 0:** `rm -f "/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-post-monitor.lock"`. Respond with HEARTBEAT_OK + per-post summary line that **MUST include the bot's posted gchat thread URL AND the workplace post URL** (for ot-human-attention-brief link extraction). Append `**GChat health (this tick):** 403_seen=$GCHAT_403_SEEN refresh_attempted=$BUCK2_REFRESH_ATTEMPTED refresh_ok=$BUCK2_REFRESH_OK consecutive=$NEW_CONSEC` as final line of run summary.

   ```
   HEARTBEAT_OK

   ---

   **Run summary** (posts processed: N):

   **W<id>** — <verdict_line>
   - Bot reply: https://chat.google.com/room/AAQAVOjYc80/<thread_id>
   - Workplace post: https://fb.workplace.com/groups/mrs.ot/permalink/<id>/
   ```

   Mandatory; operator-flagged 2026-05-17 thread `Y3qbdh2hC20`.

   **URL-derivation rule (T273158617 Fix 2, 2026-05-27):** the `<thread_id>` in the `Bot reply:` line MUST be the `$THREAD_ID` captured from step 5.c's `meta google.chat.message send -o json | jq -r .thread` (or extracted from `.name` field). NEVER synthesize from a local variable, NEVER re-use a thread id from a different post, NEVER reference a thread the current cron run did not create. If `$THREAD_ID == "SEND_FAILED"`, render the line as `- Bot reply: SEND_FAILED (outcome=<notification_outcome>)` and add `⚠️ NOTIFICATION DROPPED` to the summary header. Anti-pattern: 2026-05-27 run #6517 reported `Bot reply: https://chat.google.com/room/AAQAVOjYc80/yF_aMB00xMk` for post 1336024098492333, but that thread was started by the operator 30s later on an unrelated topic — pure fabrication, plus the actual gchat send had silently failed.

Safety:
- If meta workplace.group activity-feed fails (non-zero exit AND no valid JSON), do NOT advance state. Brief error string (no HEARTBEAT_OK).
- If single post's deep triage fails partway, send partial diagnosis with "DEGRADED: <step> failed" marker. Continue.
- Cap at 5 posts per run.
- **READ-ONLY on Workplace.** NEVER call `meta workplace.comment create`, `meta workplace.post resolve`, `meta workplace.post create`, or any `workplace.*` mutation. NEVER react to a Workplace post or comment. Triage output is delivered to the GChat lane only; the operator decides whether to mirror to Workplace. Operator clarified 2026-05-15 after this cron posted comment 1326221096139300 on Rudra Barua's mrs.ot post ("OT Not Creating New Checkpoints") — see CLAUDE.md § Never Do for the canonical rule.

## Learned Rules (auto-appended)

1. [2026-04-29] Exit code 143 (SIGTERM) from `meta workplace.group activity-feed` with valid JSON returned should be treated as success — advance state normally. The meta CLI sometimes terminates with SIGTERM on completion. Only abort if no valid JSON was produced.
2. [2026-04-29 manual] Lane patterns expanded: added `mlhub_url`, `model_series`, `paste`, `diff`, `ot_general`, `oncall_summary`. Backtest on Apr 26-29 posts showed strict `mvai-training-online-\d+` missed 3 real OT issues. Activity-feed message field is truncated at 80 chars — classification must run on full body via `meta workplace.post content`. Oncall Summary posts must be skip-routed.
3. [2026-04-29 manual] Pattern-match output is the OPENING of triage, not the conclusion. Always run ground-truth verification (snapshot timeline, mast job state, related SEVs) before publishing diagnosis. Sourced to ifu_lsr alert (model 883552231) where P01 (FULL_SNAPSHOT blocking deltas) was diagnosed but snapshot timeline showed no FULL_SNAPSHOT in flight — P01 falsified.
4. [2026-05-27] NO-WAITING / THIN-WORK RULE (operator feedback threads `ItDP0eTCP7s` + `tpk5h4kssXE`): Never emit a message asking for data that can be fetched programmatically. If job name, model ID, or SEV is not in post body, search proactively via `meta ai.mast-job list --limit=20`, `meta sevmanager.sev list`, or `meta workplace.comment list` BEFORE asking operator. PARALLEL FETCH MANDATE: when a job/model is identified, immediately fetch in parallel BEFORE forming any hypothesis: (a) `meta ai.mast-job error --name=<id>` across all recent versions, (b) `meta scuba.dataset query -d mvai_metrics` liveness probe, (c) `meta sevmanager.sev list --tags=mvai-online-training --created-after="3 days ago"`, (d) `meta ai.model-series metadata --model-id=<id>`. VERDICT-FIRST: post complete diagnosis with evidence trail — NO "investigating..." placeholder messages, NO "can you share X?" requests. AUTO-EXECUTE SAFE NEXT STEPS: after posting verdict, immediately take safe autonomous actions (e.g., trainer-bound verdict → also check current trainer count vs recommended; DPP verdict → gate on DPP starvation_pct > 5% FIRST) without waiting for operator to ask.

5. [2026-06-01 L77] **No-op run output must be bare `HEARTBEAT_OK` with NO narration prefix.** When no new posts are found (no explicit gchat send this run), the final response MUST be exactly `HEARTBEAT_OK` — no preceding "State updated.", "No new posts since last run. State updated, lock released.", GChat health stats, or any other prose. In the 24h window 2026-05-31 through 2026-06-01, 10+ no-op runs emitted narration before HEARTBEAT_OK. While the daemon correctly suppresses delivery on HEARTBEAT_OK responses (no double-post occurred), the narration prefix violates the clean-output principle (L75: no text before HEARTBEAT_OK). Applies to ALL no-op code paths: no new posts, state TTL prune-only, lock-release paths. Source: ot-post-monitor 2026-05-31 06:07 through 2026-06-01 08:07 runs.




## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)
