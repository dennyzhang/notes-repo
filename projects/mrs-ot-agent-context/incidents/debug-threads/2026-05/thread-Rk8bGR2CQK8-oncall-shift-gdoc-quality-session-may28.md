# Thread Summary: Oncall Shift GDoc Quality Session — May 28

_Source: spaces/AAQAVOjYc80 thread `Rk8bGR2CQK8` · 77 messages · 2026-05-28_
_Summarized: 2026-05-29 01:45 PT · last-msg-time: 2026-05-28T19:25:46Z_

## What was discussed

Denny left multiple rounds of feedback on the oncall shift Google Doc (tab `6/2`) and inline doc comments. Issues addressed: (1) stale "[Bot] OT Oncall Shift" prefix caused by resolved comments anchoring that text — fixed via gdocs round-trip; (2) new tab landing at bottom due to Docs API v1 lacking createTab/moveTab — confirmed limitation, UI drag still required; (3) TODO markers for human-input not obvious enough — styled with yellow background + bold; (4) SEVs tagged `mrs_ml_release_oncall` (trunk health workstream) should be excluded — 9 dropped, headline 11→6; (5) user WP posts not showing — daily-brief filter was stripping non-SEV posts, fixed via live mrs.ot query; (6) S668272 not captured on first cron run due to sevmanager indexing lag (created 21:51, cron 21:57); (7) LEGACY_UNKNOWN entries in ot-sev-state were blocking re-detection on second run. UBN check: 0 UBNs this shift.

## Key decisions made

- [2026-05-28T16:57:17Z] Tab creation goes at index 0 via `gdocs add-tab --index 0`; current tab needs manual UI drag (API can't reorder post-creation).
- [2026-05-28T17:10:44Z] Drop `mrs_ml_release_oncall`-tagged SEVs from shift doc — RULE 62 added to cron.
- [2026-05-28T17:31:16Z] WP posts: always-live query with mandatory cross-check vs ot-monitor-state (not daily-brief filtered list).
- [2026-05-28T19:25:28Z] LEGACY_UNKNOWN entries must be re-eligible for detection (cap 5/run); drains 90-entry backlog over ~1 day.
- [2026-05-28T19:21:57Z] "Critical Alerts" subsection to be added to cron template; bot activity entries trimmed to ≤1 line.

## Files / artifacts touched

| path | what changed |
|---|---|
| oncall shift gdoc tab `6/2` | multiple rounds: prefix fix, TODO styling, SEV filter, WP posts, S668272, timeline restructure |
| ot-shift-summary cron (notes+sqlite) | RULE 61/62/63 added; WP always-live; LEGACY_UNKNOWN re-detection |
| ot-sev-monitor cron (notes+sqlite) | L62: LEGACY_UNKNOWN skip removed; auto-tag fix |

## Cluster / pattern references

_(none — failure-patterns.md not consulted; no confirmed cluster IDs)_

## Followup items (not yet done)

1. Manual UI drag: move tab `6/2` to leftmost position (owner: Denny)
2. "Critical Alerts" subsection rewrite — Denny asked if bot should take it; no explicit decision recorded

## Cross-refs

- SEVs discussed: S668272 (MRS OT robocall, May 26)
- Posts: Hao Sha + Sanket Karnik WP posts (May 27, now included)
- Related threads: none
