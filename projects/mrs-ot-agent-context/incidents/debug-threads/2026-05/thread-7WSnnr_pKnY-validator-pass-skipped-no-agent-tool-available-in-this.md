# Thread Summary: External-Write Policy — Bot Read-Only on Workplace/SEVs/Alerts

_Source: spaces/AAQAVOjYc80 thread `7WSnnr_pKnY` · 17 messages · 2026-05-15T12:45–14:14 UTC_
_Summarized: 2026-05-16 14:31 PT · last-msg-time: 2026-05-15T14:14:54Z_

## What was discussed

Operator discovered bot had posted a triage comment to a Workplace post (Rudra Barua's `_preload_item_pool()` deadlock post) and commented on SEVs S664296/S664099 — without explicit authorization. Thread established the standing rule: bot is READ-ONLY on all external surfaces (Workplace posts, SEVs, alerts, Phab, OMH). Sole exception: `meta sevmanager.sev update --add-tag=mvai-online-training`. Rules persisted to notes repo. Thread ended at idle timeout with one unresolved question (which SEV numbers the bot had commented on).

## Key decisions made

- (2026-05-15T13:43:50Z) Bot MUST NEVER write to Workplace posts, SEVs, or alerts — read-only on all external surfaces; GChat is the only write surface
- (2026-05-15T13:44:38Z) Rule must live in notes repo (not just `~/.myclaw-ot-bot/`) so it survives devserver reinstall
- (2026-05-15T13:55:54Z) Sole carve-out confirmed: `--add-tag=mvai-online-training` on SEVs (org-routing metadata only; no other tag value allowed)
- Phase 1 neutering: 5 files updated with explicit write-ban + carve-out documentation

## Files / artifacts touched

| path | what changed |
|---|---|
| `team_bot/CLAUDE.md` (notes) | Added external-surface meta-rule + SEV-tag carve-out |
| `cron-jobs/ot-post-monitor.md` | READ-ONLY block; cited Rudra Barua incident |
| `cron-jobs/ot-daily-learning-mitigated-posts.md` | Ban on `workplace.*` mutations |
| `cron-jobs/ot-daily-learning-mitigated-alerts.md` | Ban on `oncall.feed` mutations |
| `cron-jobs/ot-triage-summary.md` | Ban on all external writes |
| `~/.myclaw-ot-bot/RULES.md` | Carve-out documented for session-start checklist |

## Cluster / pattern references

_(No cluster IDs relevant — this is a policy/governance thread, not a model failure.)_

## Followup items (not yet done)

1. Thread hit idle timeout while operator asked "Give me the SEV numbers" (bot had commented). Response not delivered — unresolved. Operator may want to re-ask.
2. `ot-notes-fbcode-sync` was blocked by dirty fbcode tree at time of thread; rule updates were notes-only until that sync ran.

## Cross-refs

- SEVs discussed: S664296, S664099 (SEVs where bot had added comments/tags)
- Posts: Workplace post `1324864999608243` (Rudra Barua `_preload_item_pool()` deadlock) — the unauthorized comment trigger
- Related threads: `AkDeocSaNSQ`, `pAM4x2WxE0c` (concurrent triage threads; same bot session)
