---
name: s674995-light-cli-bxl-build-node-failure
thread_id: Xg5wdMstMuQ
human_involved: true
summarized: 2026-06-12
---

# Thread Summary: S674995 — light_cli build nodes BXL analysis failure

_Source: spaces/AAQAVOjYc80 thread `Xg5wdMstMuQ` · 4 messages · 2026-06-12T00:32–00:35 UTC_
_Summarized: 2026-06-12 14:05 PT · last-msg-time: 2026-06-12T00:35:51Z_

## What was discussed

Automated triage of S674995: all 3 mvai/light_cli fbpkg build nodes failed simultaneously at ~17:13 PT with identical BXL analysis error on `arvr/firmware/ar/build_defs/constraints:logging_disabled`. Operator (msg 2) corrected the bot's revision attribution — the bot named R40931 as the bad revision, but the operator identified R40956.1 as the actual BXL-break revision (R40931 belongs to S674926's RE-capacity issue). The bot confirmed in-thread and corrected the validator note.

## Key decisions made

- **Route to mrs_ml_release_oncall** (2026-06-12T00:32 UTC): P58 pattern match — build-node failure from landed code regression → release oncall owns revert authority, not the light_cli code owner (trevormathisen). This corrected a routing error in an earlier crisp triage.
- **Bad revision is R40956.1, not R40931** (2026-06-12T00:34 UTC): Operator correction. R40931 = S674926's RE-capacity trigger; R40956.1 = the BXL analysis break that took down all 3 nodes.

## Files / artifacts touched

| path | what changed |
|---|---|
| P2375235397 (paste) | Machine fields for S674995 triage |

## Cluster / pattern references

- P58 — build-node failure from upstream code regression, T3 (mvai_publish_pipeline), owner: mrs_ml_release_oncall

## Followup items (not yet done)

1. mrs_ml_release_oncall: find + revert R40956.1 or diff touching `arvr/firmware/ar/build_defs/constraints:logging_disabled`; verify recovery via `fbpkg info mvai/light_cli | grep LATEST`.

## Cross-refs

- SEVs discussed: S674995, S674670, S674926, S674930
- Related threads: none identified
