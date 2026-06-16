# Thread Summary: dry_run Bug Audit in MRS OT Infra Code → Mitigation Diff D106710214

_Source: spaces/AAQAVOjYc80 thread `57Pg3CxxzdQ` · 38 messages · 2026-05-28_
_Summarized: 2026-05-29 01:45 PT · last-msg-time: 2026-05-28T21:42:09Z_

## What was discussed

Denny asked the bot to read D106588525 (existing dry_run gate fix) and check MRS online training infra code for similar issues — initially bot scoped too narrowly to OT-agent code, Denny clarified "MRS online training infra code." Bot performed a broader audit and found 4 findings: #1 pyper_online_cli cosmetic flag (owning team, TODO), #2 `update_config_wrapper` redesign candidate, #3 `_update_gmpp_config` missing internal dry_run guard (vs sibling `_update_model_store_publish_config` that has one), #4 `os.system("fbpkg expire ...")` runs BEFORE `if dry_run:` check in fire_impl.py (statement-order bug). Denny approved fixing #3 + #4. Bot applied both fixes, ran lint + pyre + 2 unit tests (all green), and submitted D106710214 as draft.

## Key decisions made

- [2026-05-28T21:10:51Z] Approved: ship fix #4 (fire_impl.py fbpkg expire statement order) + fix #3 (_update_gmpp_config missing internal guard) as one diff.
- [2026-05-28T21:10:51Z] Deferred: fix #2 (update_config_wrapper) as separate redesign; fix #1 (pyper flag) to owning team.

## Files / artifacts touched

| path | what changed |
|---|---|
| fbcode/…/fire_impl.py | fix #4: moved `os.system("fbpkg expire ...")` after dry_run guard |
| fbcode/…/fire_impl.py | fix #3: added `if not dry_run:` guard to `_update_gmpp_config` |
| D106710214 | draft diff submitted, reviewers: mrs-ot-reliability, task: T273199101 |

## Cluster / pattern references

_(none — failure-patterns.md not consulted; no confirmed cluster IDs)_

## Followup items (not yet done)

1. D106710214 needs review + land (owner: Denny / mrs-ot-reliability)

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none
- Diffs: D106588525 (original fix), D106710214 (mitigation)
- Tasks: T273199101
