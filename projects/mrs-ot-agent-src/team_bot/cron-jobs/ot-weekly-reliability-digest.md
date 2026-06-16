[ot-weekly-reliability-digest cron] Weekly (Mon ~08:30 PT). Per-PG OT reliability review digest — crashes + error-pattern clusters + top challenges across ALL tracked prod OT models. Task: T274590754 (parent T259215482). Runs `tools/scan-weekly-failures.sh`, which pulls last-7d DEAD/FAILED runs from Scuba `mast_hpc_job_run_status` for the tracked set, enriches each failing model with PG/tier/owner (shared `lib-enrich-model.sh`), and aggregates DETERMINISTICALLY IN-SCRIPT into (a) per-PG crash counts, (b) normalized error-pattern clusters (fleet-wide + per-PG), (c) per-PG top challenges (failure-theme ranked by freq × tier-weight). This is the fleet generalization of the IG-only/crash-only "Check 3: Weekly Crash Aggregation" in the `ot-reliability-health-check` skill. Created 2026-06-05.

**DELIVERY = TEAM SPACE (`spaces/AAQA2bZMw24`).** Operator promoted this to team-wide 2026-06-05 (thread `TMSbFoqItA0`: "this msg shall send to team chat. Fixing the routing"). Per-PG fleet reliability — crashes + error-pattern clusters + top challenges across every PG — is the "one team digest" the Team-Chat Send Gate explicitly allows (the whole org benefits from the weekly per-PG picture; same class as `ot-fleet-health`, which also posts to team). Mechanism: render the digest, send it with an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQA2bZMw24 --text="<digest>"`, **VERIFY-BY-READBACK** (confirm it's readable in `spaces/AAQA2bZMw24` before treating as delivered; on send error surface it, do NOT silently fall back), then respond EXACTLY `HEARTBEAT_OK`. When the fleet is clean (no failures), respond EXACTLY `HEARTBEAT_OK {fleet:clean}` and send nothing (no "all clear" to the team). **Exception:** the check-could-not-run error (step 2, `w_rc==2`) is plumbing → it still goes to the operator 1:1 (`spaces/AAQAVOjYc80`), NOT the team; only the actual digest is team-wide.

**READ-ONLY (HARD):** queries Scuba only. Never mutates a job, never files a task, never posts to any external surface. Hands the operator per-PG signal + the owners to route to.

**Cheatsheet load (per Conditional Cheatsheet Loading — applies to crons):** before composing the gchat send, this prompt operates the gchat modality → the send MUST go through the thread-fold rule. This cron originates its own message (no inbound thread), so it sends to the team space top-level; that is the intended new-topic for a weekly team digest. Per the Team-Chat Send Gate (HARD): this digest PASSES the AUDIENCE test (team-wide per-PG reliability) and must also pass DENSITY (steps 4–5) before send. No other modality (diff/gdocs/sev) is entered.

## Steps

1. **Run the scan** (read-only; generous timeout — one fleet Scuba query + bounded parallel enrichment of only the failing models):
   ```bash
   cd ~/notes/users/dennyzhang/projects/mrs-ot-agent-src
   w_out=$(timeout 500 bash tools/scan-weekly-failures.sh --json-only 2>&1); w_rc=$?
   ```
   Exit codes: `0`=failures found, `1`=fleet clean, `2`=usage/Scuba-fetch failure. (Timeout → treat as `2`/check-failed.)

2. **Branch on `w_rc`:**
   - `w_rc==1` (clean) → respond EXACTLY `HEARTBEAT_OK {fleet:clean}`. Send nothing.
   - `w_rc==2`/timeout → the CHECK could not run (NOT a healthy fleet). Send ONE line to the 1:1: `⚠️ *weekly reliability digest could not run* — <first error line / coverage.error from $w_out>. Status UNKNOWN; re-run \`bash tools/scan-weekly-failures.sh\` or check Scuba access.` Then respond `HEARTBEAT_OK`.
   - `w_rc==0` → parse the single aggregate JSON object (`$w_out`) and build the digest (step 3).

3. **ONE per-PG digest — consume the scan JSON fields VERBATIM (no prompt-side per-item compute; the script already did all counting/clustering/ranking).** BLUF header with the fleet crash count + the coverage line (`scanned/tracked · with_failures · enrich_errors` — NEVER hide the skip/error counts). Then one block per PG, ordered by crash_count desc. Send with an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQA2bZMw24 --text="<digest>"` (team space; VERIFY-BY-READBACK per the DELIVERY note), then respond EXACTLY `HEARTBEAT_OK`. Shape:
   ```
   🗓️ *OT weekly reliability digest* — <fleet_crash_count> crashes across <P> PGs (last 7d)
   _scanned <scanned>/<tracked> tracked · <with_failures> with failures · <enrich_errors> enrich-err_

   *<PG>* — <crash_count> crashes / <model_count> models
     genuine app-failures: <count of HPC_TASK_GROUP_APPLICATION_FAILURE from top_failure_types> · infra/churn: <sum of PREEMPTED_BY_MAST + KILLED_BY_USER + SCHEDULING_ERROR>
     top challenge: <top_challenges[0].theme> (×<freq>)
     worst model: <entity_id> (`<model_type>`, <mvai_tier>) — @<owner>, <crash_count>×
   …(repeat per PG)…

   top fleet cluster: <clusters_fleet[0].signature> — ×<count>, PGs: <pgs joined>
   ```
   Route each PG's worst-model line to its `owner` (from the per-model JSON; the `models[]` list is pre-sorted by crash_count desc — the first model whose `pg` matches is that PG's worst). Fall back to the per-product reliability owner in `team_bot_config.yaml` only if `owner` is `?`.

4. **Signal vs churn (HARD — every line earns its place, P0 density):** `KILLED_BY_USER`, `PREEMPTED_BY_MAST`, and `SCHEDULING_ERROR` are operational/host churn (preemptions, user restarts, host-repair reschedules), NOT model crashes — they are HIGH-VOLUME and would bury the real signal. **Lead each PG block with the genuine `HPC_TASK_GROUP_APPLICATION_FAILURE` count; collapse the churn classes into ONE `infra/churn: N` number.** Do NOT enumerate churn clusters. The "top challenge" and "worst model" lines should reflect genuine app-failures where possible (the scan's `top_challenges` are already freq×tier ranked; if the #1 theme is clearly a churn signature like "twtask-pre-run-step" or "preempted with exit message", note it as churn and surface the first genuine-failure theme instead).

5. **Density (HARD):** BLUF first; no id/number/URL appears twice; ≤ (3 + 4×P) lines total (P = number of PGs with failures, ≤4). Done/resolved → counts, never lists. If a PG has only churn and zero genuine app-failures, render it as ONE line (`*<PG>* — <N> crashes, all infra/churn (no app-failures)`) — do not give it a full block. Full per-model JSON is NOT pasted into the team digest; if anyone wants the raw breakdown, they re-run the scan or ask for a paste.

6. **Self-reporting + honest coverage (HARD):** every number comes from the scan's JSON, never narrated. The scan covers exactly the tracked prod set in `human-input/models.md` (65 models as of 2026-06-05); models not in that file are out of scope by design. `coverage.enrich_errors > 0` means some failing models could not resolve PG/tier/owner (rendered as `unknown`/`?`) — surface that count, never imply full enrichment. The Scuba source columns differ from the skill's spec (`error_traits_category`/`normalized_message` do not exist; the scan uses `job_failure_type` + in-house normalization of `source_failure_message`) — this is documented in the scan header. If JSON parse fails, post the scan's summary tail verbatim tagged `UNVERIFIED-PARSE` and route to the operator.

**Output discipline:** final response is EITHER the explicit-send path ending in `HEARTBEAT_OK`, OR bare `HEARTBEAT_OK {fleet:clean}`. Never narrate ("running scan…", "fleet clean", "composing digest") as the final response — that leaks to chat.
