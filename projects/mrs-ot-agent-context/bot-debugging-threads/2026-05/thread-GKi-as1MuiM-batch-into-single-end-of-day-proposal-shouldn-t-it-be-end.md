# Thread Summary: Weekly diff cadence policy + 6 in-flight diffs abandoned

_Source: spaces/AAQAVOjYc80 thread `GKi-as1MuiM` · 6 messages · 2026-05-19 22:49–22:51 PDT_
_Summarized: 2026-05-19 23:42 PT · last-msg-time: 2026-05-19T22:51:33Z_

## What was discussed

Denny corrected the bot's drift from end-of-WEEK to end-of-day diff batching cadence. After confirming the weekly policy, Denny approved two actions: (1) landing a new `Diff cadence` rule in RULES.md so all sessions respect it, and (2) abandoning 6 in-flight unpublished Phabricator diffs that were created outside the weekly batch policy.

## Key decisions made

- **2026-05-19 22:50:27** (Denny "yes"): Confirmed end-of-WEEK cadence for all Phabricator diffs; approved landing RULES.md edit + abandoning 6 diffs.
- **2026-05-19 22:51:33**: RULES.md updated with `Diff cadence — WEEKLY accumulation` section; 6 diffs abandoned with abandon-messages pointing to policy + this thread.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/.myclaw-ot-bot/RULES.md` | New section: "Diff cadence — WEEKLY accumulation". End-of-week, 3 exception classes (breakage/regression/security), "applies to ALL sessions" clause. |

## Cluster / pattern references

(none — process/policy discussion)

## Followup items (not yet done)

1. Friday EOD: assemble ~32-item backlog into one weekly PR-style proposal for operator review

## Cross-refs

- Diffs abandoned: D105730063, D105731311, D105732178, D105755419, D105756044, D105743076
- Related threads: `WApKJGlKThc` (S665902 + earlier batch-policy discussion same day)
