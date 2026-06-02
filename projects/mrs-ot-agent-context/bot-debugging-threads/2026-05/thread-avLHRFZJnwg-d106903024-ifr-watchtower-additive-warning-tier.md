# Thread Summary: D106903024 — IFR Watchtower alert additive WARNING tier

_Source: spaces/AAQAVOjYc80 thread `avLHRFZJnwg` · 34 messages · 2026-05-30T04:47Z – 05:27Z_
_Summarized: 2026-05-30 03:45 PT · last-msg-time: 2026-05-30T05:27:37Z_

## What was discussed

Denny reviewed D106903024 (IFR Watchtower "too few delta snapshots" alert shift-left) and caught that the bot's initial design changed existing MAJOR behavior (moved page threshold from <14 to <7). He directed an additive "+2" design: keep MAJOR at <14 unchanged, add non-paging WARNING at <16. The thread also covers: real-data validation via Scuba (MC8 healthy range 15-18 → WARNING band is narrow; Prod MTML steady 16-18 → clean), conf submit gotcha (code updated but Phabricator summary/test-plan fields stay stale), and a late diff-cheatsheet run that found missing reviewers and tags.

## Key decisions made

- **Additive +2 design chosen** — WARNING (non-paging) at `count < 16`, MAJOR unchanged at `count < 14`. Purely additive: no existing paging behavior changed. (2026-05-30T04:50:45Z Denny: "the value + 2?")
- **Diff cheatsheet must apply to `conf submit` / configerator diffs** — not only `jf submit`. Ran late here; found missing reviewers (weijialiu, bbanavige) and missing `publish_when_ready` tag. (2026-05-30T04:57:59Z Denny catch)
- **`#mrs-ot-reliability` reviewer + T259215482 task** — both required per `ot-agent-conventions.md`, both initially missing. Added by Denny in closing message. (2026-05-30T05:27:37Z)
- **`conf submit` gotcha** — updates committed code but does NOT update Phabricator summary/test-plan fields. Must sync explicitly via `phabricator.diff update` after `conf submit`. (2026-05-30T04:55:53Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| IFR Watchtower configerator alert config | Added WARNING tier `count < 16`; MAJOR `count < 14` unchanged |
| D106903024 Phabricator summary/test-plan | Updated to match additive design (previously stale `<7` reference) |

## Cluster / pattern references

_(No cluster IDs cited — omitted to avoid fabrication)_

## Followup items (not yet done)

1. Publish D106903024 (currently draft). Awaiting Denny's go-signal to loop in IFR/feed-rec owners + mrs_online_training. Owner: bot. Status: pending Denny approval.

## Cross-refs

- SEVs discussed: none directly (alert 886797001 MC8 referenced for real-data validation)
- Posts: none
- Related threads: `omDkxkD7Sr0` (earlier shift-left triage thread per memory)
