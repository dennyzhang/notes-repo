---
name: Bc8BTmRhGCQ-alert-url-invalid-lib-url-shared-helper
description: Operator traced invalid alert URL (bare numeric OneDetection key) to a P-004 violation; escalated to building shared lib-url.sh helper (#1+#2) + post-hoc backstop (#3); principle 14c added to cheatsheet
metadata:
  type: project
  human_involved: true
---

# Thread Summary: Invalid alert URL → shared lib-url helper + URL validation architecture

_Source: spaces/AAQAVOjYc80 thread `Bc8BTmRhGCQ` · 66 messages · 2026-06-06 16:16–17:11 UTC_
_Summarized: 2026-06-06 21:45 PT · last-msg-time: 2026-06-06T17:11:03Z_

## What was discussed

Operator asked why alert URL `?alert_id=27273086059047715` showed "invalid" in OneDetection. Bot diagnosed: bare numeric is not a resolvable OneDetection key — real keys are long `@#$`-delimited composites. The initial per-cron fix (add resolvable-URL assert to ot-alert-monitor) was immediately escalated by the operator ("why wait") into a structural solution: shared URL-builder lib in `tools/lib-url.sh`. A send-hook attempt false-positived on the discussion of the bad URL pattern (same trap as earlier today), was reverted, and the lesson was codified. Operator also asked how to improve the autonomous-workflow cheatsheet, which led to principle 14c being added.

## Key decisions made

- **2026-06-06 16:18 UTC** — Root cause confirmed: `?alert_id=<bare-numeric>` has no detector/entity path → OneDetection renders "invalid." Cron's `short_id` rule existed but was skipped. Per-cron assert added to ot-alert-monitor (`e5882b55f98a`).
- **2026-06-06 16:24 UTC** — Operator: "you should already have check steps: all urls should be validated before return." URL validity is a principle (P-004) but was not enforced.
- **2026-06-06 16:29 UTC** — Universal send-hook attempted, immediately false-positived on the very reply that explained the hook (reply quoted the placeholder patterns as examples). Reverted. Decision: **send-path content-scan cannot distinguish a real render-bug from prose discussing it**. Hooks stay for command-shape rules only.
- **2026-06-06 16:42 UTC** — Operator: "why wait" + "if a problem could remain in multiple jobs, this learning should be applicable." Bot built #1+#2 without further confirmation.
- **2026-06-06 16:53 UTC** — `tools/lib-url.sh` shipped: id-typed builders (mast/sev/diff/task/alert) + `assert_resolvable`. Self-test 19/19 pass. 5 link-emitting scripts wired to use it. Backtest: 55 emitted URLs, 0 non-resolvable. Committed `d51775e8ca5a`.
- **2026-06-06 16:58 UTC** — Post-hoc dead-link audit (#3) added to ot-bot-volume-watch: scans cron-generated posts only (rendered `<…|…>` links), skips interactive replies. Committed `d1bafc374605`.
- **2026-06-06 17:02 UTC** — Operator added principle 14c to autonomous-workflow cheatsheet: "a fix for one job is a fix for its whole CLASS" — grep the same shape across siblings, extract into a shared helper, ask "which other jobs have this shape?" before calling a fix done.

## Files / artifacts touched

| path | what changed |
|---|---|
| `tools/lib-url.sh` | NEW — shared id-typed URL builders + assert_resolvable |
| `tools/scan-zombie-jobs.sh` + `scan-scribe-lag.sh` + `scan-perf-regression.sh` + `scan-weekly-digest.sh` + `render-fleet-digest.py` | wired to lib-url.sh |
| `team_bot/cron-jobs/ot-alert-monitor.md` | per-cron resolvable-URL assert (interim for LLM-composed links) |
| `team_bot/cron-jobs/ot-bot-volume-watch.md` | #3 post-hoc dead-link audit step |
| `cheatsheets/autonomous-workflow.md` | principle 14c added |

Commits: `e5882b55f98a`, `0356fd18c5bd`, `d51775e8ca5a`, `d1bafc374605`

## Cluster / pattern references

_Not an incident triage — no CL-NNN applicable._

## Followup items (not yet done)

1. T274682737, T274590132, T274264882 open auto-fix tasks (detector recalibration diffs) — gap exists: triage creates tasks but nothing drafts the mitigation diff automatically. Operator asked bot to build a cron for this; discussion ended with a scope question (auto-draft vs surface-only). Decision pending.
2. #3's link-extraction is LLM-regex (noted as hardenable to `tools/scan-dead-links.sh`).

## Cross-refs

- SEVs discussed: S668542 (Feed scribe quota exhaustion — root cause of recurring e2e Scribe-lag alerts)
- Tasks: T274682737, T274590132, T274264882
- Related threads: `7GKCIVDMtz8` (same session, gdoc comment-safe operations)
