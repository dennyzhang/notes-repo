# Catchup audit — all crons vs autonomous-workflow cheatsheet (2026-06-04)

Operator: "apply your autonomous workflow [cheatsheet] to all existing jobs. Do a catchup improvement."
Method: 3 parallel read-only auditors over 37 cron prompts vs `cheatsheets/system/autonomous-workflow-principles.md`.

**9 clean** (good — principles largely followed): ot-fleet-health, ot-cron-health-watch, ot-prompt-change-validator, ot-triage-summary, ot-metrics-rollup, ot-daily-learning-digest, ot-sev-tag-review, ot-notes-weekly-review-paste, server-disk-guard.

## DONE this run
- **[HIGH #5/#6] known-patterns.md broken path** — 6 crons read a nonexistent path (`human-input-domain/how/known-patterns.md` bogus `how/`; `mrs-ot-agent-src/known_patterns.md` nonexistent) → every dedup/novelty/falsifier read returned nothing → duplicate P-rows, broken self-improvement loop. Fixed → `human-input-domain/known-patterns.md` in ot-daily-learning-debugging, -mitigated-sevs, -knowledge-distillation, -knowledge-curation, -postmortem-validator, -human-attention-brief. Synced (updates=6). Verified: 0 bogus refs; canonical exists.

## QUEUED — low-risk, mechanical (batch next; rides weekly sync)
- [MED #6] Surface silent caps in run summaries: ot-sev-monitor (3-cluster cap → `deferred:N`), ot-post-monitor (5-post cap), ot-alert-monitor (snap-miss count), ot-bot-volume-watch (`--limit 250` → mandatory pagination + `truncated` flag).
- [MED #15] ot-oauth-refresher: `last_alert_epoch` hard-set null every write → anti-spam never persists; only set on alert fire.
- [MED #12] ot-debug-quality-weekly: Mon-only week math mis-computes on the Thu run; compute window from actual run-day.
- [MED #1/#2] context-ingestor-gchat + -posts: drop the always-on weekly status post (the .md catch-up file IS the deliverable); post only on a P0 item. (Same class operator killed on thread-summarizer.)
- [MED #5/#8] daily-brief: "triage_events empty, do NOT query" is stale — table has 20 rows + metrics-rollup uses it; reconcile.
- [MED #0] ot-human-attention-brief: "ONE ~500-line brief" contradicts the 3500-char cap; dedup the AI-needs-help bucket vs daily-brief (one owner).

## NEEDS OPERATOR DECISION — higher blast radius
- [HIGH] ot-triage-auditor: stalled in DRAFT/not-enabled ~2 weeks, 0 coverage while owning 14 backlog items. Enable (3-day calibration) OR fold R-VC2/R-VC3 into live crons.
- [MED #12] Shared notes-repo lockfile: ot-notes-commit-push, ot-notes-deletion-watch, ot-myclaw-backup-nightly Phase A all mutate ~/notes hourly/nightly with no mutual exclusion → mid-op corruption risk. One shared flock.
- [MED #16] Backup-before-mutate on destructive paths: ot-notes-fbcode-commit auto-`sl revert`, ot-notes-deletion-watch auto-`sl push --to master`, ot-channel-rollout bulk live-sqlite UPDATE — all destroy prior state with no recoverable pre-image.
- [MED #14b] Convert prose audience/scope gates → mechanical (PreToolUse send hook): ot-postmortem-validator (leaked to team 2026-06-03), ot-sev-monitor team-gate. (Tied to the D107579040 send-path work.)
- [MED #11] ot-myclaw-weekly-restart: post-restart verify only runs NEXT week; add a 5-min smoke check.
- [MED #18] Privacy at write-time: thread-summarizer / context-ingestors / backup-nightly write distilled content to world-readable notes; add content-class allow-list before write.

See [[backtest-by-default]], [[autonomous-workflow-cheatsheet]].
