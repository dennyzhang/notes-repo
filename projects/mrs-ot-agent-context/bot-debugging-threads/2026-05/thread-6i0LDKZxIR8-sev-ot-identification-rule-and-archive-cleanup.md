# Thread Summary: OT SEV identification rule + false-positive archive cleanup

_Source: spaces/AAQAVOjYc80 thread `6i0LDKZxIR8` · 8 messages · 2026-05-17T22:29–2026-05-18T04:29 UTC_
_Summarized: 2026-05-18 22:42 PT · last-msg-time: 2026-05-18T04:29:46Z_

## What was discussed

Operator provided a batch of SEV IDs and established a general rule for distinguishing OT SEVs from non-OT. Bot applied the rule, removed 36 false-positive archives from `resolved-sevs/2026-05/`, and updated `MISSING.md` to document the rejections as a regression fixture. Subsequent discussion covered why MISSING.md was still long (it's a regression ledger, not a TODO list) and operator pushed notes repo immediately after.

## Key decisions made

- (2026-05-17T22:29:52Z) Rule: If a SEV has `mrs_ml_release_oncall` tag, it is NOT an OT SEV unless the title contains "online" keywords. Cogwheel-prefixed titles are excluded even if they contain "online_train_publish".
- (2026-05-17T22:29:52Z) Full OT title-matching criteria: `online`/`OT job`/`mvai-training-online-`/`teacher.*online` in title → include; `cogwheel-` prefix → exclude regardless.
- (2026-05-17T22:31:02Z) 36 false-positive archives moved to `/tmp/sev-archive-trash/` (recoverable); 9 true-OT stubs retained for May.
- (2026-05-18T04:28:21Z) Push notes repo immediately after MISSING.md update — don't wait for the scheduled `ot-notes-commit-push`.
- MISSING.md is a *regression fixture* (67-SEV test set for future scope_check.py tightening), not a TODO list. Should not be shortened until scope_check.py tightening is validated against it.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-sevs/2026-05/MISSING.md` | Updated with April+March rejection buckets; expanded from 159 to 315 lines |
| `incidents/resolved-sevs/2026-05/` | 36 false-positive stubs removed; 9 true-OT stubs retained |
| `/tmp/sev-archive-trash/` | 36 recovered false-positive stubs moved here |
| notes repo (remote/master) | Commit `1a0665419916` pushed |

## Cluster / pattern references

- [CL-007] — cross-org leaks via tag broadness; the `mrs_ml_release_oncall` tag was too broad, admitting cogwheel/release-pipeline SEVs
- [CL-004] — Cogwheel publish failures (not OT-owned); exclusion rule now correctly filters these at the source

## Followup items (not yet done)

1. Tighten `scope_check.py` / `team_lane_scope.py` upstream regex (the `mtml` and `mvai` patterns in `_EXPLICIT_PATTERNS_DEFAULT` are too broad). Needs diff + tests against 67-SEV MISSING.md fixture before landing.

## Cross-refs

- SEVs discussed: S661983, S661020, S663166, S658649, S664024, S661851, S661169, S658369, S659167, S664258, S662694, S662535, S658691, S661922, S662650, S663866, S662279, S661783, S661239, S662458, S661170, S661752, S659097, S658188, S659215, S658534, S658769, S661149, S659631, S659617, S658462
- Posts: none
- Related threads: none
