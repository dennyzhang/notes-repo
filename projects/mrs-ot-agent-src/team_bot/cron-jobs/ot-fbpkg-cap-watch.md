[ot-fbpkg-cap-watch cron] Weekly Mondays 14:00 UTC. Pre-emptively detect and address `light_cli` fbpkg version-cap pressure (P41 pattern — 800-cap recurrence every ~7 days, root cause T271102844). Audits the in_use_by_model_<id> tag set against the live model registry to find ORPHAN tags (model decommissioned, tag still pinning a version slot). Posts a triage report with identified orphans + recommended deletion list. Does NOT auto-delete in v1 — operator confirms before any fbpkg state change.

**Why weekly + Mondays:** the recurrence cadence is ~7 days (S657811 2026-05-05 → S661987 2026-05-12). Running each Monday morning catches the build-up before Conveyor blocks mid-week. Mondays at 14:00 UTC = 06:00 PT = before the US-PT release-engineering cohort starts pushing.

**Scope — single fbpkg in v1:** `light_cli` only. The pattern is fbpkg-specific; expansion to other ML release fbpkgs (mvai-fire-app, others under mrs_ml_release_oncall) follows after v1 has 2-3 weeks of validated detections. This is the same iterative-discipline as the mitigated-* cron family.

State file: ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-fbpkg-cap-watch-state.json — `{"last_run_epoch": <int>, "previous_orphans": ["model_<id>", ...], "previous_count": <int>, "last_alert_epoch": <int>}`. Time budget: ~10 min per run (one fbpkg info + ~250 model-id lookups).

Procedure:

1. **Read state file.** Extract previous_orphans, previous_count. If file missing/corrupt, treat as empty + create fresh.

2. **Pull current fbpkg state:**
   ```bash
   fbpkg info light_cli > /tmp/light_cli_info.txt 2>&1
   ```
   Extract:
   - Total versions: from `Stats: [Versions: <N>, ...]` line
   - Version cap: from `Version Limit: <N>` line
   - All `in_use_by_model_<id>` tags from `Archived Tags:` line

3. **Compute headroom:** `headroom = cap - total`. If `headroom > 200`: pre-emptive flag, no action needed (post HEARTBEAT_OK). If `headroom <= 200`: proceed to orphan audit.

4. **Build pinned-model list:** extract model IDs from in_use_by_model_<id> tags into a deduped list. Save count as `pinned_count`.

5. **Audit each model_id** for liveness — batch via parallel calls (cap 10 concurrent):
   ```bash
   for model_id in $(cat /tmp/pinned_models.txt); do
       meta ai.model-series metadata --model-id="$model_id" -o json 2>/dev/null \
           | jq -r 'if .lifecycle_state then "\($model_id) ALIVE \(.lifecycle_state)" else "\($model_id) DEAD" end'
   done
   ```
   Classify:
   - **ALIVE**: model-series metadata returns active state. Tag is legitimate, leave alone.
   - **DEAD**: metadata returns empty or error → likely decommissioned. Tag is orphan candidate.
   - **STALE**: model-series exists but `lifecycle_state` indicates retired/deprecated AND no model.instance in last 30 days → orphan candidate.

6. **Confidence gate:** for each DEAD/STALE candidate, run a second-source check:
   - `meta ai.model.instance list --model-id=<id> --limit=1 --sort-by=creation_time --sort-order=desc -o json` — if NO recent instances OR most recent > 30 days old: confirm orphan. Otherwise downgrade to "uncertain" (skip in v1).

7. **Build orphan report:** `confirmed_orphans = [<model_id>, ...]`. Compute:
   - total_orphans = len(confirmed_orphans)
   - slots_recoverable = total_orphans (each tag pins 1 version)
   - new_orphans = orphans not in previous_orphans (week-over-week growth)
   - resolved_orphans = orphans in previous that disappeared (acted on or model came back to life)

8. **Post triage report** to spaces/AAQAVOjYc80 (only if state crossed a threshold: headroom <= 100 OR new_orphans >= 20):
   ```
   📦 [OT fbpkg cap watch — light_cli] Versions: <N>/<cap> (headroom: <H>)
   • Confirmed orphan tags: <N> (= <N> recoverable slots)
   • New orphans this week: <N>
   • Resolved orphans since last week: <N>
   • Predicted next 800-cap: <date> if no action (per ~7-day cadence)

   *Recommended action* (operator confirms before any deletion):
   ```
   fbpkg delete light_cli:<v1> light_cli:<v2> ...
   ```
   Or for tag-level cleanup (preferred — keeps version, just removes the orphan reference):
   ```
   fbpkg meta light_cli --remove-tag in_use_by_model_<id1> in_use_by_model_<id2> ...
   ```

   Full orphan list: ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/fbpkg-audits/<YYYY-MM-DD>.json
   Root-cause work: T271102844 (ml_deps_graph retention leak)
   ```
   Capture thread id `report_thread`.

9. **Write orphan list to disk** (durable for operator review):
   - Path: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/fbpkg-audits/<YYYY-MM-DD>.json`
   - Format: `{"audited_at": "<iso>", "fbpkg": "light_cli", "version_count": <N>, "version_cap": <N>, "headroom": <N>, "pinned_models_count": <N>, "confirmed_orphans": [...], "new_orphans": [...], "resolved_orphans": [...], "predicted_next_cap": "<date>"}`

10. **Persist state file:** update last_run_epoch, previous_orphans = current confirmed_orphans, previous_count = current total versions. Respond `HEARTBEAT_OK {versions: N, cap: M, headroom: H, orphans_confirmed: O, new_orphans: NO, alerts_posted: A}`.

Safety:
- **Read-only on fbpkg in v1.** This cron NEVER deletes versions or tags. The operator-recommended action lines in the report are for the operator to copy-paste — not for the bot to execute. Auto-delete moves to v2 after 2-3 weeks of operator-validated detection accuracy.
- **Conservative orphan classification.** Only confirm DEAD/STALE when (a) model-series metadata fails OR (b) lifecycle_state is retired/deprecated AND most recent model.instance is > 30 days old. Single-source classification = "uncertain", skip in v1.
- **Cap report frequency.** Only post when headroom drops below 100 OR new orphans grow by >=20. Otherwise HEARTBEAT_OK silent. Avoid weekly noise on stable weeks.
- **Don't run the audit if fbpkg info fails.** Skip the run, post `🛟 [ot-fbpkg-cap-watch] FAILED: fbpkg info <error>`. Persist no state changes.
- **Bounded model-lookup batch size.** Cap concurrent model-series queries at 10 to avoid hammering the registry.
- **Don't audit other packages in v1.** Scope is light_cli only. Adding other packages requires a separate diff + operator confirm.

Why this exists:
Operator request 2026-05-13 in spaces/AAQAVOjYc80 thread lnV0WzX9rRE: "Address the disk capacity issue ... Fix it by yourself."

Direct mitigation attempted via `fbpkg meta light_cli --version-limit=1200` was blocked by an `ephemeral_limit > 255` validation error inside the fbpkg meta CLI (existing package state has 1086 ephemerals, validation refuses any meta change on the package). Cap raise requires fbpkg oncall help per the error message itself.

Direct count=0 version cleanup was non-viable: all 10 count=0 versions are in the Archived list (intentionally preserved from auto-delete; deletion would lose discoverability of named historical builds like `explore_lsr_mb2_base_layer_custom_build_v2`).

What IS in scope for the bot: orphan-tag detection. Each `in_use_by_model_<id>` tag pins one version slot. Decommissioned models that left their tag behind are pure orphan references — removing the tag frees the version for auto-cleanup with zero risk to live models. v1 of this cron does the detection + recommendation; v2 will auto-delete after operator validates the false-positive rate stays low.
