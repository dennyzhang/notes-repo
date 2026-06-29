[ot-oauth-refresher cron] Every 10 min. Preemptive OAuth token refresh — runs `buck2 run` on a tiny target to keep the meta-CLI / gchat-read OAuth token fresh, preventing the periodic 403 expiry class. Silent on success, escalates only on 3 consecutive failures.

State file: `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-oauth-refresher-state.json` — `{"last_refresh_epoch": <int>, "last_refresh_ok": <bool>, "consecutive_failures": <int>, "last_alert_epoch": <int|null>}`. Time budget: 10s typical; 30s max.

## Why this cron exists

Before this cron (pre-2026-05-28): OAuth tokens expired periodically → `meta google.chat.message list` returned 403 → cron monitors saw `gchat_reads=DEGRADED` → bot triage quality degraded for the rest of the run. The L66 `gchat_read_with_recovery` wrapper added REACTIVE self-heal (detect 403, refresh, retry). This cron adds PROACTIVE refresh so the 403 rarely fires in the first place — better operator UX (no DEGRADED labels on heartbeats).

Source: thread `4BK7HJHkzB0` 2026-05-28 21:14 PT — operator asked *"should we have a regular cron to monitor and fix these transient issues?"*. This is the missing Part 3 of the L66 plan (originally deferred pending instrumentation data; the reactive wrapper proves the refresh primitive works, so the preemptive cron is now safe to ship).

## Procedure

1. **Run the refresh primitive** — any `buck2 run` invocation triggers buck preflight which refreshes OAuth credentials as a side effect. Use a target that exits fast:
   ```bash
   (cd /home/dennyzhang/fbsource && buck2 run fbcode//pe_mrs_ml/mrs_ot_agent:scope_check -- --help) > /dev/null 2>&1
   REFRESH_EXIT=$?
   ```
   Why `scope_check --help`: target already exists, exits 0 in ~5s, output is suppressed. We do NOT use `-q` flag (per 2026-05-28 L68 — invalid buck2 flag, exits 3).

2. **Update state**:
   ```bash
   STATE=~/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-oauth-refresher-state.json
   PRIOR_FAIL=$(jq -r '.consecutive_failures // 0' "$STATE" 2>/dev/null || echo 0)
   if [ $REFRESH_EXIT -eq 0 ]; then
     NEW_FAIL=0
   else
     NEW_FAIL=$((PRIOR_FAIL + 1))
   fi
   jq -n --argjson ok "$([ $REFRESH_EXIT -eq 0 ] && echo true || echo false)" \
         --argjson now "$(date +%s)" \
         --argjson fail "$NEW_FAIL" \
         '{last_refresh_epoch: $now, last_refresh_ok: $ok, consecutive_failures: $fail, last_alert_epoch: null}' \
     > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
   ```

3. **Escalation gate (edge-triggered)** — post ONE gchat line to spaces/AAQAVOjYc80 ONLY when `consecutive_failures` crosses 3 (i.e., NEW_FAIL == 3 and PRIOR_FAIL == 2). Avoids spam. Format:
   ```
   🚫 [ot-oauth-refresher] buck2 refresh failed 3 ticks (~30 min). May affect downstream meta-CLI / gchat-read 403 recovery. Manual buck2 health check recommended.
   ```
   If `consecutive_failures` returns to 0 after a previous alert, post ONE recovery line: `✓ [ot-oauth-refresher] refresh recovered after N consecutive failures.`

4. **Respond** — silent on success: `HEARTBEAT_OK refresh-ok` for success path, `HEARTBEAT_OK refresh-failed n=$NEW_FAIL` on failure (no gchat unless escalation gate fires). Per brevity discipline (`feedback_brevity-discipline`), this cron MUST NOT emit user-facing messages on normal operation.

## Safety rules

- **No gchat sends on success.** Default operation is silent. Operator only learns this cron exists when (a) it fails 3× consecutively, OR (b) it recovers from a prior failure state.
- **No file writes outside the state file.** This cron does NOT touch fbcode, notes, or other state files.
- **Refresh primitive must not produce side effects.** `scope_check --help` is intentionally a noop target — does not modify anything, does not read SEVs. If the target ever gains side effects, switch to a different refresh primitive (e.g., a dedicated `meta auth.refresh` if available).
- **Frequency is 10 min** — tuned so refresh interval is well under typical OAuth TTL (assumed ~30-60 min based on observed expiry cadence). Reduce to 5 min if expiry observed faster.

## Anti-regression

- `buck2 run -q` is invalid (L68). Use `buck2 run TARGET -- ARGS 2>/dev/null` to suppress Buck UI noise instead.
- If this cron starts emitting on every run despite success → check that step 4's "silent on success" is being honored.
- If `consecutive_failures` climbs but no gchat alert fires → check edge-trigger logic in step 3 (must be `NEW_FAIL == 3 AND PRIOR_FAIL == 2`).

## Provenance

Created 2026-05-28 21:50 PT. Source thread: `4BK7HJHkzB0`. Companion to: ot-cron-health-watch class-7 parity validator (catches the L66 wrapper getting bypassed), ot-sev-monitor / ot-alert-monitor / ot-post-monitor step 0.5 (reactive 403 recovery). This cron closes the loop on the OAuth-403 transient class.
