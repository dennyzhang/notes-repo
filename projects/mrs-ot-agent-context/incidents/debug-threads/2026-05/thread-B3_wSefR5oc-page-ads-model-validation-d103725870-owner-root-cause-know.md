# Thread Summary: S667355 Conveyor Regression + Phase A fbcode-as-SoT + Notes-as-SoT Decision

_Source: spaces/AAQAVOjYc80 thread `B3_wSefR5oc` · 15 messages · 2026-05-22_
_Summarized: 2026-05-23 05:50 UTC · last-msg-time: 2026-05-22T20:23:38Z_

## What was discussed

Two distinct topics. (1) Denny posted a 🔴 PAGE triage result for S667355 (IG CTR mtml_ctr_instagram_model, 21 VM/HIM combo models failing snapshot validation with EVALUATOR_PREDICTOR_CLIENT_INFERENCE_TIMEOUT). Root cause: D103725870 broke the SV (Snapshot Validator) scheduler entry point; Conveyor deployed broken binary at 2026-05-20 22:29 PT, causing zero SV scheduling events for 25+ hours. Three sibling SEVs all share root: S667329 (root), S667355 (IG CTR), S666941 (AF DC), S667061 (mtml_leadgen_cvr holdout >48h). Bot surfaced a known-patterns improvement: "don't filter by sev_type alone when SV/scheduler/conveyor language is present in title." (2) Denny approved Phase A (backport sqlite cron prompts into fbcode audit trail) as 3 draft diffs, then made the architectural decision: **Notes as SoT** for cron prompts. Bot executed Phase A immediately: 3 diffs filed (D106126551/D106126552/D106126550), zero runtime behavior change.

## Key decisions made

- **2026-05-22T20:06:47Z** Denny: "Make your own decision, if you can" — bot chose NOT to apply PAGE-gate prompt change (would lose cluster-signal), ran sqlite-vs-fbcode audit instead.
- **2026-05-22T20:12:35Z** Denny: "Notes as SoT" — canonical source for cron prompts is fbcode/.../team_bot/cron-jobs/*.md; sqlite is derived. Phase B (auto-sync fbcode→sqlite) follows after Phase A lands.
- **2026-05-22T20:15:43Z** Bot: Green-lit Phase A as 3 stacked diffs (monitor-family / learning+misc / sqlite-only-new). Filed immediately.
- **2026-05-22T20:23:38Z** Bot: Phase A landed as D106126551/D106126552/D106126550.

## Files / artifacts touched

| path | what changed |
|---|---|
| `fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/cron-jobs/` (monitor family) | D106126551: ot-{alert,sev,post}-monitor + ot-cron-health-watch backported (+779/-141) |
| `fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/cron-jobs/` (learning + misc) | D106126552: 8 files backported (+584/-147) |
| `fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/cron-jobs/` (9 sqlite-only new) | D106126550: new .md + MANIFEST entries (+1300/-1) |

## Cluster / pattern references

- [CL-004] — Conveyor / cogwheel publish failures. S667329/S667355 root is D103725870 breaking SV scheduler entry point via Conveyor binary push — consistent with this cluster.
- Known-patterns improvement (not yet filed): filter logic should NOT exclude SEVs by `sev_type` alone when "SV/scheduler/conveyor" appears in title — cross-org root (Ads+Instagram) was missed by earlier scope filter.

## Followup items (not yet done)

1. Phase A diffs (D106126551/D106126552/D106126550) pending review and landing.
2. Phase B: wire `setup-cron-jobs.sh` hourly (fbcode→sqlite auto-propagation) — blocked on Phase A landing.
3. Phase B: extend `ot-prompt-change-validator` to flag sqlite-vs-fbcode drift.
4. Phase B: update `team_bot/CLAUDE.md` with SoT enforcement rule.
5. S667355: monitor D103725870 revert + S667329 mitigation to confirm all 4 SEVs clear.

## Cross-refs

- SEVs discussed: S667329, S667355, S666941, S667061, S667158
- Diffs: D103725870 (broken, needs revert), D106126550/D106126551/D106126552 (Phase A backports, DRAFT)
- Related threads: `8I2DbESTJrw` (D106052922 rebase earlier same day), `SI-eCb6Dq44` (prior bot improvement discussion)
