[ot-bot-volume-watch cron] Hourly. (1) Track BOT msg volume in spaces/AAQAVOjYc80; detect runaway bands + hourly bursts; auto-attribute to top offending source-crons; auto-draft verbosity-reduction prompt edits (operator-approved before apply). (2) TEAM-SPACE QUALITY AUDIT (step 12, added 2026-06-04): audit every bot post to the team space `spaces/AAQA2bZMw24` against the Send-Gate bar (signal vs noise), report leaks + precision to the 1:1 — the after-the-fact backstop to send-time prevention D107579040. Silent on steady state — only posts (to 1:1) on band transitions, hourly-burst breaches, or team-chat noise found.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output (incl. failures/escalations), make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, status, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

Created 2026-05-28 per operator thread `AL3dqJevKm0`: *"do you have an autonomous workflow or cron job to monitor and tune this?"* Designed via parallel-agent workflow (18 audit findings → 1 cron spec). Three-tier tuning policy per `preference_act-dont-ask` + `feedback_suppress-noise`.

State file: `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/state/ot-bot-volume-state.json` — `{"last_band":"<quiet|steady|busy|runaway>","last_band_transition_epoch":<int>,"last_burst_epoch":<int|null>,"consecutive_clean_hours":<int>,"yesterday_reported_date":"<YYYY-MM-DD|null>","last_upstream_leaks":<int>,"upstream_leak_task":"<T-id|null>","schema_version":1}` (the two `upstream_*` fields, added 2026-06-11, gate the re-narration suppression in step 12; additive — absent = 0/null). Telemetry table: `ot_bot_volume_telemetry(date,hour,bot_count,human_count,ratio,band,burst_fired,top_sources_json,ts_created)`. Time budget: ~30s typical.

## Procedure

1. **Lockfile** (per `project_lockfile_concurrent_run` pattern):
   ```bash
   LOCKFILE=~/.myclaw-ot-bot/spaces/AAQAVOjYc80/state/ot-bot-volume.lock
   LOCK_MAX_AGE=3600
   NOW=$(date +%s)
   [ -f "$LOCKFILE" ] && [ $((NOW - $(cat "$LOCKFILE"))) -lt $LOCK_MAX_AGE ] && { echo "[ot-bot-volume-watch] locked, exiting"; exit 0; }
   echo "$NOW" > "$LOCKFILE"; trap 'rm -f "$LOCKFILE"' EXIT
   ```
   Self-exclude: count own posts (`[ot-bot-volume-watch]` prefix) as 1 to prevent self-loop, but do NOT trigger band/burst on own activity.

2. **Query bot msg counts via the GChat API — NOT the local `messages` table.** (CRITICAL data-source fix, 2026-05-29: the local `messages` table is an INBOUND INGESTION LOG — every BOT row has `status='skipped'` and includes daemon-ingested echoes, cross-space cron outputs, and empty system-ping rows. It does NOT record actual outbound sends and over-counts ~3-5×. The authoritative "what Denny sees in this space" comes ONLY from the GChat API.)
   ```bash
   # Authoritative bot-send count for spaces/AAQAVOjYc80
   meta google.chat.message list --space-id spaces/AAQAVOjYc80 --limit 250 -o json \
     | python3 -c "import json,sys; d=json.load(sys.stdin); \
       bot=[m for m in d if m.get('sender','') != '100051448831249']; \
       print(len(bot))"
   ```
   - Bot sends render under the Meta Bot sender id (via `--as-meta-bot`), NOT Denny's `100051448831249`. Human = `100051448831249`.
   - **DO NOT count the local `messages` table** — `sender_type='BOT' status='skipped'` rows are ingestion records, not sends. The 2026-05-28 "408 BOT / 152 empty-msg" runaway alert was a FALSE ALARM produced by querying this wrong source; the 152 "empty-msg" were `content='' status='skipped'` ingestion pings that never reached GChat. See `gotcha_messages-table-is-ingestion-log`.
   - Use `--limit 500` + paginate if needed for full-day coverage. Group by `thread` (the `.thread` field) for per-thread attribution.

3. **Three windows:**
   - (a) Rolling 60-min BOT msg count (last hour, for burst detection)
   - (b) Today-so-far BOT total (since today 00:00 PT)
   - (c) Yesterday's final BOT + HUMAN totals + HUMAN/BOT ratio

4. **Threshold evaluation** (data-anchored from 14d distribution, rebaseline every 30 days):
   ```
   daily_bot_msgs:    quiet <120  | steady 120-220 | busy 220-300 | runaway >320
   daily_human_msgs:  quiet <40   | steady 40-110  | engaged >110
   hourly_burst:      quiet-hours (23:00-08:00 PT) >50 | waking (08:00-23:00 PT) >120
   noise_feedback:    human_to_bot_ratio <0.1 over full day = ALERT (Denny went quiet, bot kept talking)
   ```

5. **Hysteresis** (per `ot-cron-health-guard` transition-only posting pattern): read state file, only act if BAND CHANGED since last run OR burst threshold newly crossed OR yesterday's runaway not yet reported. Skip otherwise.

6. **On hourly-burst breach:** group the offending hour's messages by source-cron-tag (extract from `[OT cron X]` prefix / emoji / known patterns). Identify top 1-3 offenders. Auto-draft a verbosity-reduction prompt edit citing exact line numbers in the source cron prompt notes-file. Save to `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/state/draft-cron-edits/<cron-id>-<epoch>.md`. Draft edit MUST be concrete (e.g., "add `only post if state changed` to step N at line LL of `<cron>.md`") — never vague.

7. **Daily summary post (09:00 PT only):** if yesterday was RUNAWAY band OR ratio <0.1, post ONE consolidated msg:
   ```
   📊 [ot-bot-volume-watch] yesterday: <N> BOT msgs (<band> band) | HUMAN/BOT ratio: <r>. Top sources: <cron-X>=<n>, <cron-Y>=<n>, <cron-Z>=<n>. Draft edit: <path>. Approve to apply.
   ```
   Otherwise silent log to telemetry only.

8. **On hourly-burst breach:** post ONE msg:
   ```
   🚨 [ot-bot-volume-watch] burst: <N> BOT msgs in <HH:MM>-<HH:MM> window (threshold <T>). Top sources: cron-X=<n>, cron-Y=<n>, cron-Z=<n>. Draft edit saved: <path>. Approve to apply.
   ```
   On subsequent burst-recovery transition: reply-in-thread `✓ recovered after N clean hours`.

9. **Telemetry append:** `INSERT INTO ot_bot_volume_telemetry (date, hour, bot_count, human_count, ratio, band, burst_fired, top_sources_json, ts_created) VALUES (...)`. For trend visibility + future rebaselining.

10. **State write + exit:** update state file (last_band, last_band_transition_epoch, last_burst_epoch, consecutive_clean_hours, yesterday_reported_date). Release lockfile. On the silent/quiet/steady/no-change path, **emit ONLY the literal token `HEARTBEAT_OK` — nothing before it: no bullets, no counts, no "all checks pass" summary, no status narration. Any prose preceding `HEARTBEAT_OK` is delivered to GChat verbatim by the daemon (the #1 narration-leak trap).** NEVER post bare "all quiet" or "consider tuning" (violates `feedback_suppress-noise` + `act-dont-ask`).

11. **THREAD-FRAGMENTATION audit (added 2026-05-29 thread `HJG9Ec2LuX4`: operator — "fold messages of the same topic strictly to the related gchat threads").** A high distinct-thread count is itself a noise signal — it means the bot spawned new top-level messages instead of replying in the relevant existing thread, forcing the operator to chase context. Compute `distinct_bot_threads_today` from step 2's GChat-API `.thread` grouping. Thresholds:
    - `distinct_bot_threads > 15/day` OR `>1 top-level (non-thread-reply) bot msg per topic` → flag THREAD-FRAGMENTATION.
    - When flagged AND in the daily summary (step 7): append `⚠️ thread-hygiene: <N> distinct bot threads today (target ≤10); <M> top-level sends that should have been thread-replies.`
    This is a measurement-only signal (no auto-fix) — the fix is behavioral (reply-in-thread discipline, see `feedback_fold-messages-into-threads` + `cheatsheets/comms/gchat.md § RULE #1`). Surfacing the count holds the bot accountable.

12. **TEAM-SPACE QUALITY AUDIT — high bar (added 2026-06-04, operator: "audit process for all bot msgs to team chat … hold a high bar, otherwise the channel will be spammed").** Steps 2-11 watch the 1:1; this audits every BOT post that actually landed in the TEAM space `spaces/AAQA2bZMw24` (last 24h) and holds it to the Team-Chat Send Gate bar. It is the after-the-fact backstop to the send-time prevention (D107579040): prevention gates, audit catches misses.
    - **Pull (authoritative, NOT the local `messages` ingestion log — same gotcha as step 2):** `meta google.chat.message list --space-id spaces/AAQA2bZMw24 --limit 250 -o json`; bot-authored only (exclude humans + self).
    - **⛓️ DETERMINISTIC PARTITION — RUN THE SCRIPT for the counts; do NOT re-derive the split by LLM judgment (rewritten 2026-06-15, recurrence #3 of the "interactive thread mis-counted as cron noise" miscount).** The headline counts come from `bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/team-space-precision.sh 24` — one JSON line. Use its fields VERBATIM: `cron_signal`, `cron_noise`, `cron_posts`, `cron_precision` (HEADLINE), `upstream_leaks`, `upstream_by_source`. It classifies SIGNAL by the prefix allow-list AND splits every NON-signal bot post by **fingerprint-matching against `delivered` cron `job_runs.raw_response` in-window** — match → cron leak (in-lane, counts in `cron_precision`); no match → interactive/cross-space → `upstream_leaks` (NEVER in the precision fraction). The `job_run` match is what the prefix CANNOT do: a leaked cron `⚠️` wears the same `🛟` prefix as an interactive reply, so prefix-only either mis-buckets the interactive thread as cron noise (the 60% miscount, 07:05 2026-06-15) OR masks a real cron leak into upstream (the "100%" run, 08:03 — it hid the validator leak). The deterministic match gives the right answer (3 signal + 1 validator cron-leak → 75%, 14 interactive → upstream). **The Classify/Score bullets below are now LABELING-ONLY** — read the `cron_noise` posts to write the per-item gist line; do NOT recompute counts. If the script returns `"error"` or empty → fall back to the manual classify/score below and add `precision_source=manual_fallback` to the message.
    - **Classify each post by a MECHANICAL allow-list, NOT judgment (2026-06-04 self-attack: same-model judgment can rate its own leak as "signal"):** SIGNAL = ONLY posts matching a known alert-cron shape. **Match by SHAPE FAMILY, not literal phrase (2026-06-10: matching the literal `🔴 PAGE` missed `🔴 [OT PAGE]`; matching literal `🚨 [OT SEV` missed `🚨 [OT PAGE]` — bracket variants kept getting miscounted NOISE one at a time).** The families: (a) `🩺 OT fleet health` digest; (b) ANY `🔴`- or `🚨`-led escalation, INCLUDING the `[OT …]` bracket family in any variant — `🔴 [OT PAGE]`, `🔴 PAGE`, `🚨 [OT SEV`, `🚨 [OT PAGE]`, `🚨 [unrouted alert` (alert-monitor PAGE that couldn't route to a named owner); (c) `[OT triage]` — the crisp-5-element incident-triage VERDICT shape from CLAUDE.md report style (`[OT triage] <id> (<class>) — <symptom>`, e.g. `[OT triage] S673569 (REAL_OT_FAILURE)`); (d) any `[<alert-cron-id>]`-prefixed post. **Rule of thumb: a post led by 🔴/🚨/🩺 OR by an `[OT …]`/`[<cron-id>]` bracket is SIGNAL regardless of the exact word after it.** **EVERYTHING ELSE = NOISE by default** (default-noise so the bot cannot self-exempt). Interactive operator replies have no such prefix → always classed NOISE.
    - **Score — (LABELING-ONLY when the script succeeded: use the script's `cron_signal`/`cron_noise`/`cron_posts`/`cron_precision` VERBATIM; the formula block below is the `manual_fallback` path ONLY, taken solely when the script returned `"error"`/empty.)** partition NOISE by SOURCE first, then compute the headline precision on the IN-LANE denominator only. For each post run the cron-source check (the `job_runs.raw_response LIKE` query in the source-check bullet below): a `job_run` match → **cron post** (in-lane, prompt-fixable); no match → **interactive/cross-space** (upstream class, [T275122535](https://www.internalfb.com/tasks/T275122535)). Then **[manual_fallback ONLY]**: `cron_posted = cron_signal + cron_noise`; **headline `cron_precision = cron_signal/cron_posted`** (the part THIS lane controls), or `N/A (0 cron posts)` when none. Count interactive/cross-space leaks SEPARATELY as `upstream_leaks` — they are NOT in the `cron_precision` fraction. (2026-06-11: folding the single interactive leak into a combined `precision=X/N` made a clean-cron day read `precision 0%` — the exact miscount the operator flagged, twice.) The overall delivery precision (all machine posts) stays ONLY as the silent acceptance-test trend in `team-space-precision.sh` + the P-017 task — never the operator headline.
    - **P-017 auto-task (added 2026-06-09 thread `pnL5GSkFRW0`).** If the dominant noise source is an UPSTREAM root cause (not an in-lane cron-prompt fix) — i.e. interactive/dialogue leak (myclaw-core `cross_space.py`), the contains-`HEARTBEAT_OK`-suppression gap, or any leak the bot cannot close in-lane — AND it is recurring (`upstream_leaks>0` on ≥2 audits), file the P-017 decisive-metric task via the shared helper (dedup-safe, handhold-first). CAPTURE the helper's stdout into a variable for the state file — it MUST NOT reach your final response (a bare `TASK_CREATED:T####`/`DEDUP_SKIP:T####` line before HEARTBEAT_OK leaks to chat):
      ```bash
      P017_RESULT="$(bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/file-decisive-metric-task.sh \
        "team-space delivery precision" "interactive/non-cron bot posts leak to team space (precision <bar>)" \
        T274834361 myclaw-core 2>/dev/null)"   # record $P017_RESULT in state; never echo it
      ```
      Founding instance already tracked as [T275122535](https://www.internalfb.com/tasks/T275122535) (the helper will `DEDUP_SKIP` it); a genuinely new upstream noise-source files its own. The decisive query for this one is `tools/team-space-precision.sh` (baseline 9.5%, target ≥90%), root-cause [T274834361](https://www.internalfb.com/tasks/T274834361). Per P-017: in-lane noise → fix the cron prompt; upstream noise → metric task, then keep surfacing the precision number **via the report step's explicit 1:1 gchat send (NOT the final response)**; do NOT re-narrate the same upstream leak each audit.
    - **LINK VALIDITY — post-hoc dead-link audit (added 2026-06-06; this is backstop "#3" for URL validity — `tools/lib-url.sh` correct-by-construction is #1, the construction-time emitters are #2; this catches anything that slipped into POSTED output anyway). Advisory ONLY — this is a post-hoc auditor, it reports, it does NOT block any send.** Reuse the SAME team-space bot-post pull above (do NOT add a second pull). Scope and false-positive guards are HARD:
       - **CRON-GENERATED STRUCTURED POSTS ONLY.** Restrict to the posts already classed SIGNAL by the mechanical allow-list above (the alert-cron/digest shapes: `🩺`/`🚨`/`🔴 PAGE`/escalation/`[<alert-cron-id>]` prefix; the brief/shift/fleet-digest emoji families `📋`/`🗓️`). **EXCLUDE every interactive operator↔bot reply** — those are where URLs get *discussed*, and content-scanning them is exactly the false-positive that got a send-hook reverted 2026-06-06. A post with no cron/digest prefix is interactive → skip it entirely.
       - **RENDERED LINKS ONLY — never prose-mentioned URLs.** Extract ONLY gchat hyperlink markup `<https://…|text>` (a true rendered link). A bare `https://…` sitting in a sentence is *discussion*, not a rendered link → do NOT extract it, do NOT flag it. Regex: `<(https?://[^|>]+)\|[^>]*>` over each in-scope post body; the captured group 1 is the href.
       - **Validate:** `source ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/lib-url.sh` once (ABSOLUTE path — a relative `tools/lib-url.sh` does NOT resolve from the cron's runtime cwd; the prompt isn't a script with `$0`. 2026-06-06 prompt-change-validator catch), then run each extracted href through `assert_resolvable "<href>"` (FORMAT check only — bare-numeric onedetection alert, unfilled `{{…}}`/`<…>`/`%s` placeholder, bare-eid MAST all fail; NO http reachability, too slow). Collect each failure as `(thread, bad_url)`.
       - **Fold into the SAME 1:1 audit message — do NOT add a second send.** When emitting the step-12 audit message (below), if dead-links found, append a line: `🔗 dead links: N` then one indented line per failure (`<thread> — <bad_url>`). If `noise==0` AND dead-links==0 → stay silent (`HEARTBEAT_OK`), consistent with the cron's existing discipline. If dead-links>0 but noise==0, the dead-link finding alone justifies the EXPLICIT 1:1 send.
       - **Honest coverage (state it in the message):** this audits CRON-AUTHORED posts only; interactive replies are excluded by design (that's where URL-discussion lives). Render as a footer when the dead-link line is present: `(scope: cron-posts only; interactive replies excluded)`.
    - **Report (1:1 ONLY — `spaces/AAQAVOjYc80`, NEVER team) — EXPLICIT-SEND + HEARTBEAT_OK two-part pattern, NOT a final-response post.** (prompt-change-validator 2026-06-04: a final-response scorecard would auto-deliver to the TEAM space → the audit becomes the very noise it audits.) **Post ONLY on a NEW, actionable, in-lane signal — specifically if ANY of: (i) `cron_noise>0`, (ii) `dead_links>0`, (iii) a NEW upstream leak source not previously tracked, (iv) `upstream_leaks` count REGRESSED vs `last_upstream_leaks` in state.** An already-tracked upstream leak with unchanged count and zero cron noise → **SILENT (`HEARTBEAT_OK`), telemetry/state only.** Re-narrating the same tracked upstream leak each audit IS the noise the operator keeps catching (2026-06-11: interactive leak `2099999217602931` re-posted 21:02 AND 22:02 though already tracked T275122535 — violates the "do NOT re-narrate" rule in the P-017 bullet above + `no-op audit → silence`). When posting, lead with the IN-LANE metric:
      ```
      📋 team-chat audit (24h): cron-posts <cron_signal>/<cron_posted> signal — precision <cron_precision>%  (or: cron-posts clean — 0 posts)
      • <cron-id> — <≤8-word gist>                                   ← one line per CRON noise item only
      🔗 dead links: <N>                                             ← + one indented line per failure (if any)
      ↩ upstream leaks: <K> — tracked T275122535 (gate D107579040)   ← ONLY if NEW source or regressed; else omit
      (scope: precision = cron-authored posts; interactive/cross-space leaks tracked separately upstream)
      ```
      THEN respond EXACTLY `HEARTBEAT_OK`. If none of (i)-(iv): respond EXACTLY `HEARTBEAT_OK`, send nothing. Always write `last_upstream_leaks` + `upstream_leak_task` to state so (iii)/(iv) are decidable next run.
    - **Drive the fix — but FIRST verify the leak is CRON-SOURCED (mandatory; 2026-06-11: a cross-space interactive leak "Done — created ot-fleet-health team job" was mis-drafted as a fleet-health *cron narration* fix — no cron ever emitted it, so the prose edit to `ot-fleet-health.md` would have fixed nothing and the leak would recur).** Before drafting ANY cron-prompt edit, confirm the leaked text actually came from a cron: `sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "SELECT job_id FROM job_runs WHERE raw_response LIKE '%<distinctive snippet>%' AND run_at > datetime('now','-2 day');"` (NOTE: `job_runs.run_at` is ISO-8601 TEXT, not epoch — use `datetime('now',…)`, never `strftime('%s',…)`/`unixepoch`, or the window silently becomes a lexicographic no-op). **If a cron IS the source** → draft the concrete fix via the step-6 `draft-cron-edits/` mechanism (operator-approval gated). **If NO `job_run` contains it** → the leak is the interactive/cross-space class (T275122535), NOT a cron — do NOT draft a cron-prompt fix (wrong target, will recur); attribute it to the upstream send-path class + reference the prevention (D107579040). Never draft a cron-prompt fix without this source check. **THREE anti-misfix guards before drafting ANY cron-prompt edit (2026-06-12: the audit drafted 4 fixes, only 1 was a real gap — the rest were duplicate-prose / metric-gaming / wrong-instance):** (1) **Rule-already-present →** grep the target prompt for an existing no-narration / explicit-1:1-send-then-`HEARTBEAT_OK` rule (`emit ONLY .*HEARTBEAT_OK`, "posts nothing", "NEVER emit … narration"); if PRESENT, the leak is **LLM-variance against the daemon deliver-to-team default — a CORE issue, NOT a prompt gap → do NOT draft duplicate prose** (re-adding an existing rule only bumps the prompt hash and re-triggers next run — the documented false-FAIL loop, `ot-prompt-change-validator.md` ~line 91); attribute to **T275142534** (daemon send gate) and stop. (2) **Never relabel-to-SIGNAL →** NEVER draft a fix that changes a leaking post's prefix/emoji so the SIGNAL allow-list counts it (e.g. `🛟→🚨 [cron-id]`). That games `cron_precision`; it does not stop the leak. An operator-plumbing post reaching team is fixed by ROUTING it off-team (explicit 1:1 send + `HEARTBEAT_OK`), never by relabeling. (3) **In-manifest-only →** only draft for a cron present in THIS space's `jobs`/`MANIFEST.json`; a flagged cron NOT in the local manifest (another space/instance — e.g. `ot-cron-health-watch`) cannot be fixed here → attribute + report, do not draft. A dead link in a cron-authored post means an emitter bypassed `lib-url.sh` construction — draft a concrete fix pointing the offending scan/render script at the matching `lib-url.sh` builder. Append `team_posted`/`team_noise`/`dead_links` to telemetry for trend.

## Tuning Actions (three-tier policy)

| Band | Action |
|---|---|
| quiet (<120) or steady (120-220) | SILENT — telemetry append only, no chat msg |
| busy (220-300) | SILENT-LOG — telemetry + one-line note in HEARTBEAT.md for heartbeat awareness |
| runaway (>320) OR hourly burst | ALERT — auto-attribute top 1-3 sources, auto-draft concrete verbosity-reduction edit (cite exact line numbers), post ONE chat msg, await operator approval |

**Operator approval flow:** on a single-word reply like `apply` / `yes` / `ack` from operator in the alert thread, follow `gotcha_cron-prompt-three-layer-flow`: edit notes file, UPDATE sqlite via `readfile`, verify SHA256 parity, let weekly sync handle fbcode. **NEVER auto-apply prompt edits without explicit operator approval.**

## Safety rules

- **Self-exclusion:** own `[ot-bot-volume-watch]` posts excluded from all counts (anti-loop).
- **No bare status msgs:** "all quiet" / "consider tuning" / FYI lines are PROHIBITED — either act with concrete draft edit OR stay silent.
- **No auto-edit without approval:** draft edits saved to disk but NEVER applied to sqlite without explicit operator `apply`/`yes`/`ack`.
- **Rebaseline cadence:** every 30 days, re-query 14d distribution from `ot_bot_volume_telemetry`; if p75 drifts >20% from current band boundaries, propose new thresholds (operator-approved).
- **Cross-cron coordination:** this cron does NOT touch ot-cron-health-guard / ot-shift-summary / other cron prompts directly; only writes to its own state + draft-edit dir.

## Why this cron exists (vs heartbeat)

Heartbeat fires every ~30 min but is conversation-context-driven, has no measurement persistence (cannot accumulate rolling burst counters), and cannot detect quiet-hour bursts when operator is asleep (no heartbeat-triggering signal). Heartbeat also regressed on volume awareness twice in May 2026 (2026-05-25 fabrication gotcha, 2026-05-28 6-of-7 suppressible run-summaries that operator called out) — proving ad-hoc per-fire judgment is insufficient.

`ot-cron-health-guard` covers cron-RUN failure classes (silent failure, missing run, gchat-wrapper bypass), not msg-VOLUME. `ot-metrics-rollup` covers triage precision/recall, not output volume. Individual crons enforce local caps but no aggregator exists across the 29+ manifest crons.

This cron uniquely provides: (1) exact-hourly cadence (deterministic burst windowing), (2) persistent state file for hysteresis + cross-day trend, (3) source-attribution + concrete draft-edit generation, (4) separate accountability surface so heartbeat stays focused on conversation/actionability while volume governance runs as a quiet measurement loop.

## Provenance

Created 2026-05-28 21:55 PT via parallel-agent workflow (run `wf_89e487c4-f11`, 4 agents / 18 audit findings / 1 design synthesis). Source thread: `AL3dqJevKm0`. Closes the "msg-volume monitoring gap" identified in the today-msg-audit conversation. Companion to: `ot-cron-health-guard` (cron-RUN health) and HEARTBEAT.md rules (per-fire judgment).
