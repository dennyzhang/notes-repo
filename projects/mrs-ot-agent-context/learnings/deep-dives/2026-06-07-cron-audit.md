# Cron audit vs autonomous-workflow cheatsheet (2026-06-07)

Operator: "load autonomous workflow cheatsheet, examine your cron jobs, see what improvements need to be made."
Method: 4 parallel read-only auditors over 41 crons vs cheatsheets/system/autonomous-workflow-principles.md.

## FIXED this run (verified on disk; silent-failure / broken bugs)
- **ot-knowledge-curation** — read DEAD paths `mitigated-{sevs,posts,alerts}/` (actual: `incidents/resolved-*/`) AND wrote to `references/triage-discipline.md` (actual: `human-input/`). Cron was a SILENT NO-OP (couldn't see corpus, couldn't dedup/write). Fixed both paths + added fail-loud on empty corpus.
- **ot-daily-learning-digest** — queried `job_runs.db` (nonexistent; correct=`myclaw.db`) → ot-knowledge-curation surface silently dropped from the digest. Fixed.
- **ot-oauth-refresher** — wrote `last_alert_epoch: null` every run → anti-spam + recovery edge dead; escalation fired only on the exact 2→3 tick (missed climbs past 3). Now preserves the field + fires on ">=3 AND not-yet-alerted". (This was also on the 2026-06-04 catchup queue — now done.)

## CLEAN (reference implementations): ot-fleet-health, feedback-coach, ot-channel-rollout, ot-perf-regression-watch, ot-notes-weekly-review-paste, ot-thread-summarizer, ot-weekly-reliability-digest. ot-sev-monitor/ot-post-monitor = best-hardened (residual is §14b/§14c only).

## QUEUED — the big themes (class fixes; not patch-per-cron)
- **[#1 SYSTEMIC §5] LLM-narrated numbers + no reconcile-assert — ~10 crons.** mitigated-{alerts,posts,sevs} Pareto/coverage, ot-debug-quality-weekly accuracy %, ot-metrics-rollup precision/lag, daily-brief BLUF counts, ot-human-attention-brief headline (triaged/confident/needed-you), context-ingestor-{gchat,posts}, ot-daily-learning-{debugging,digest}. FIX = the render-fleet-digest.py pattern (compute-in-code + reconcile-or-withhold + plain labels), swept. feedback-coach + fleet-health are the templates.
- **[§14c shared helpers]** (a) raw_response ID-parser duplicated in ot-triage-summary / ot-triage-auditor / ot-postmortem-validator. (b) R20-sweep + noisy-Pareto + UPSERT/stub duplicated across mitigated-{alerts,posts,sevs} trio. (c) notes scope-parse + commit/push duplicated across ot-notes-{commit-push,deletion-watch,fbcode-commit}. Extract one helper each.
- **[§14b logic-in-prompt]** validators/monitors/summaries classify+count in prose; worst = ot-triage-auditor (11 R-rules incl. literal TZ arithmetic), ot-alert-monitor (~750 lines), ot-sev-tag-review classifier, ot-metrics-rollup. Move deterministic parts to scripts.
- **[§16 destructive-action hardening]** add mass-cap + re-verify-before + audit-of-paths: server-disk-guard (rm, no mass-cap), ot-notes-deletion-watch (push, no re-verify-still-absent), ot-sev-tag-review (auto-tag, no cap), ot-triage-auditor (auto-PAGE, no re-verify-live), ot-notes-fbcode-sync-weekly (abandon loop no cap), ot-myclaw-backup-nightly (prune without keep-one-good), ot-fbpkg-cap-watch (CLI-error misclassified as DEAD).
- **[§11 marker-drift silent-coverage-loss]** ot-postmortem-validator + ot-triage-auditor gate input on `raw_response LIKE '%phrase%'`; if upstream wording drifts → 0 rows → silent no-op reported clean. Rule: "upstream ran but 0 matched my marker → fail loud."
- **[§2 audience guard]** ot-human-attention-brief + ot-debug-quality-weekly target 1:1 but lack the explicit send-then-HEARTBEAT_OK guard → daemon may default-deliver to TEAM. VERIFY the live channel first, then add the guard (daily-brief/distillation pattern).
- **[§16 windowed-query type]** ot-metrics-rollup (`ts_notified` type) + mitigated-alerts (mixed epoch forms): verify the window actually windows (two windows → different counts), per the cron-stats bug.

See [[digest-numbers-compute-in-code-reconcile-assert]], [[fleet-cron-logic-in-script-not-prompt]], [[autonomous-destructive-action-safety]], [[operator-output-plain-language]].
