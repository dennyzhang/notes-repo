# Thread Summary: S668828 — IFR Prospector TGIF Validation Fails (Triton Kernel Missing)

_Source: spaces/AAQAVOjYc80 thread `gRHL9HGD77Q` · 3 messages · 2026-05-28 05:59–06:04 PT_
_Summarized: 2026-06-01 03:45 PT · last-msg-time: 2026-05-28T06:04:28Z_

## What was discussed

Automated SEV triage for S668828 (L4, mvai_publish_pipeline). cogwheel_ifr_prospector_test (fire-mrs_ml_release_oncall-mrs_cog-test-eba0f7) failed TGIF model validation on R980.1 (rev 303e0ad7) with `TGIFRuntimeError: triton_cc_group_layer_norm has no attribute "_group_layer_norm_fwd_esr_cint_mc4"`. Attempt 0 DEAD after 1h8m; Conveyor blocked for ifr_prospector trunk releases. Root cause: D105917200 (IFR-ESR MC4 Launch, migrating HSTUCint → group_hstu) calls the ESR/CInt/MC4 Triton kernel variant at hammer/v2/modules/group_hstu.py:1038, but the kernel is absent from R980.1 hammer fbpkg. Second message was a test reply from Denny; third was the full triage output.

## Key decisions made

- [06:04:28] Root cause: D105917200 introduced group_hstu code path calling `_group_layer_norm_fwd_esr_cint_mc4`, which is unregistered in R980.1. Same diff links to S668320 (online_train Hopper-only crash, Fix Ready) — fix may or may not cover TGIF kernel packaging.
- Ruled out: trainer GIL hang (P44) — TGIF validation step, deterministic AttributeError, no active trainer; MAST infra failure — deterministic stack trace.
- Owner: andrewxmao / mrs_ml_release_oncall. Next actions: verify if S668320 fix covers TGIF kernel; check `fbcode/hammer/v2/ops/triton/cc/group_layer_norm/` for esr_cint_mc4 variant; rebuild R980.1 or revert D105917200 if missing.

## Files / artifacts touched

| path | what changed |
|---|---|
| _(triage output only — no notes files modified in this thread)_ | |

## Cluster / pattern references

_(failure-patterns.md not found — cluster IDs omitted)_

## Followup items (not yet done)

_(none explicit in thread — triage delivered, andrewxmao is owner)_

## Cross-refs

- SEVs discussed: S668828, S668320 (related, Fix Ready), S668293 (sibling cogwheel hstu_cint)
- Diffs: D105917200 (root cause), D105765209, D104452948 (related on S668828)
- Posts: P2353606685 (machine fields paste)
