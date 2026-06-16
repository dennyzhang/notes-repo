# Thread Summary: ig_reels_tab_mtml TRANSIENT_NOISE triage + MyClaw diff revert forensics

_Source: spaces/AAQAVOjYc80 thread `zNu-DFBjb4g` · 24 messages · 2026-05-21_
_Summarized: 2026-05-21 23:47 PT · last-msg-time: 2026-05-21T18:53:58Z_

## What was discussed

Thread started with a TRANSIENT_NOISE/NO_ACTION triage of ig_reels_tab_mtml holdout (model 2132766001, scribe_read_proxy alert). The bot then failed to respond ("MyClaw failed to respond"). Operator asked why the "couldn't process that" message returned given a previous diff claimed to fix it. Investigation traced the regression to D104896267 being reverted by Itay Radotzki (radotzki) on 2026-05-15 05:03 PT via revert-hammer. Operator then approved drafting a fix-forward diff.

## Key decisions made

- `2026-05-21T18:08` — Operator asked to check past diffs for the prior fix. Confirmed D104896267 was reverted (`486a617881f7`) with message "An infra SEV is better than not reverting this diff."
- `2026-05-21T18:40` — Operator: "should we have a fix forward diff?" — triggering draft work.
- `2026-05-21T18:52` — Operator approved: "yes, draft the diff; also read the diff comment from Itay."
- Diff drafted as commit `5950cc06bac9`: differentiated empty-response handling by `num_turns` (0 → auth/SDK error path; >0 → response-lost path). Addresses Itay's stated concern ("user will not know something didn't work") while eliminating generic apology spam. Reviewers: radotzki, lupaul, parthvasa, pinih.

## Files / artifacts touched

| path | what changed |
|---|---|
| `fbcode/myclaw/src/daemon/poller.py` | +30/−7 — differentiated empty-response messages |
| `fbcode/myclaw/src/tests/test_poller_integration.py` | +37/−7 — two new test cases |

## Cluster / pattern references

- [CL-003] — ig_reels_tab_mtml alert classified TRANSIENT_NOISE; ZippyDB S654082 active as upstream cascade source

## Followup items (not yet done)

1. Submit `scho0cc06bac9` for review via `sl phabsubmit`. Ping radotzki with 1-liner referencing his revert comment. Owner: Denny.
2. Run buck2 tests locally before submit: `buck2 test fbcode//myclaw/src:tests_daemon -- --regex test_empty_response`. Owner: Denny.

## Cross-refs

- SEVs discussed: S654082 (ZippyDB AI training tier, active)
- Posts: D104896267 (reverted), D104895205 (targeted-diagnostics companion)
- Related threads: `pfOwfwvhbM0` (same session — bot improvements batch)
