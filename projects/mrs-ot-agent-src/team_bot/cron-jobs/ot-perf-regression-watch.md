[ot-perf-regression-watch cron] Every 6h. Pre-SEV performance-regression EARLY-WARNING for tracked prod OT models. Runs `tools/scan-perf-regression.sh`, which detects — baseline-relative, per model (vs its own trailing 7d median, not a global threshold) — two leading indicators that precede a SEV but are not themselves failures: (1) **training QPS drifting down** (`qps/global/window/train` < 70% of baseline) and (2) **GPU mem-util climbing** (positive slope over 24h while recent >80% — the leading edge of the OOM→zombie path, e.g. S670887). Example-age is intentionally NOT a standalone trigger here — it is OWNED by `ot-fleet-health`'s `scan-scribe-age.sh` (hard 10min SLO, team space); this cron uses age only as a co-signal to attribute a QPS regression to a subsystem (P-014, defer overlap). Created 2026-06-03 (operator request: "one model may run into performance regression … not SEVs, but still need to debug as early indication of SEVs").

**DELIVERY = OPERATOR 1:1 (`spaces/AAQAVOjYc80`), regression-only.** These are SOFT, unconfirmed early-warnings — they fail the Team-Chat Send Gate audience test (not a shared incident the whole team must act on *yet*), so they go to the operator, NOT the team space. The operator decides what (if anything) to escalate. When nothing is drifting, respond EXACTLY `HEARTBEAT_OK` and send nothing (no "all clear" spam).

**READ-ONLY (HARD):** queries Scuba only (mvai_metrics, gpu_dyno_stats). Never mutates a job, never files a task, never posts to an external surface. Hands the operator the model + signal + the one probe to run.

## Steps

1. **Run the scan** (read-only; generous timeout — per-model `meta`/scuba calls across the tracked set can exceed 5 min):
   ```bash
   cd ~/notes/users/dennyzhang/projects/mrs-ot-agent-src
   p_out=$(timeout 900 bash tools/scan-perf-regression.sh 2>&1); p_rc=$?
   ```
   Exit codes: `0`=regression(s) found, `1`=fleet clean, `2`=usage/data-fetch failure. (Timeout → treat as `2`/check-failed.)

2. **Branch on `p_rc`:**
   - `p_rc==1` (clean) → respond EXACTLY `HEARTBEAT_OK {fleet:clean, regressions:0}`. Send nothing.
   - `p_rc==0` → parse the per-model JSON lines (fields: `entity_id, model, owner, signals[], likely_subsystem`). Each `signals[]` entry has `signal` (`qps_down` | `gpu_mem_climb` | `example_age_up_cosignal`) plus its numbers. Build the alert (step 3) and send it to `spaces/AAQAVOjYc80`.
   - `p_rc==2`/timeout → the CHECK could not run (not necessarily a healthy fleet). Send one line to the 1:1: `⚠️ *perf-regression check could not run* — <first error/timeout line from $p_out>. Status UNKNOWN; re-run \`bash tools/scan-perf-regression.sh\` or check meta/scuba access.`

3. **ONE actionable early-warning post — every line says what to INVESTIGATE.** BLUF header with the count + the scan's coverage line (scanned/skipped — never hide the skip count; the skipped retrieval/sub-models are a known coverage boundary, see step 5). Send with an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --text="<post>"`, then respond EXACTLY `HEARTBEAT_OK`. Shape:
   ```
   📉 *OT perf-regression early-warning* — <N> model(s) drifting (pre-SEV)
   _scanned <S>/<T> tracked · <K> skipped (not emitting / retrieval-keyed)_

   • *<model>* (`<entity_id>`) — @<owner>
     <per-signal: qps_down recent/baseline (pct%); gpu_mem_climb slope_pp/recent%; age co-signal x×>
     likely: <likely_subsystem>
     → probe: <the matching first probe from cheatsheets/oncall/mast-debugging.md § Performance Regression — e.g. `mvai trace-doctor analyze -j mvai-training-online-<entity_id>` for qps_down; gpu_dyno_stats slope for gpu_mem_climb>
   ```
   Route each line to its `owner` (from the JSON; fall back to per-product reliability owner in `team_bot_config.yaml`). The probe is for the operator to run — the cron does not run it.

4. **Density (HARD):** BLUF first; no id/number/URL appears twice; ≤ (2 + 3×N) lines total. If N>5, show the 5 worst (by severity: gpu_mem_climb act-now > qps_down by depth-below-baseline), append `(+K more)`, drop the full JSON to a paste rather than scrolling the 1:1.

5. **Self-reporting + honest coverage:** every number comes from the script's JSON, never narrated. The scan SKIPs models not emitting `qps/global/window/train` under their own `model_entity_id` (most retrieval/sub-models — their metrics are keyed under a root trainer; ~half the registry today). This is a known coverage boundary, reported in the summary line — do NOT imply full-fleet coverage. Covered set = dense/MTML ranking models. (Follow-up: add a retrieval-model QPS/freshness probe path to close the gap.) If JSON parse fails, post the script's summary tail verbatim tagged `UNVERIFIED-PARSE`.

**Output discipline:** final response is EITHER the explicit-send path ending in `HEARTBEAT_OK`, OR bare `HEARTBEAT_OK {…}`. Never narrate ("running scan…", "fleet clean") as the final response — that leaks to chat.
