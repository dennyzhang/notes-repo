# Thread Summary: S668828 — IFR Cogwheel TGIF Triton Kernel Missing

_Source: spaces/AAQAVOjYc80 thread `gRHL9HGD77Q` · 3 messages · 2026-05-28T05:59–06:04Z_
_Summarized: 2026-05-29 00:46 PT · last-msg-time: 2026-05-28T06:04:28Z_

## What was discussed

L4 SEV S668828: cogwheel TGIF model validation for ifr_prospector failed on R980.1 (rev 303e0ad7) with `AttributeError: triton_cc_group_layer_norm has no attribute "_group_layer_norm_fwd_esr_cint_mc4"`. MAST job fire-mrs_ml_release_oncall-mrs_cog-test-eba0f7 attempt 0 was DEAD after 1h8m. Conveyor blocked — no new ifr_prospector trunk releases, model freshness degrading.

## Key decisions made

- Root cause (2026-05-28T06:04Z): D105917200 (IFR-ESR MC4 Launch) migrated HSTUCint → group_hstu; the esr_cint_mc4 Triton kernel variant is absent from the R980.1 hammer fbpkg. Same diff implicated in S668320 (Hopper-only online_train crash, Fix Ready).
- Class: CONVEYOR_REGRESSION · Owner: andrewxmao / mrs_ml_release_oncall.
- Ruled out: P44 GIL hang (TGIF validation step, deterministic Python AttributeError, no active trainer) and MAST infra failure.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — triage report only, no local file changes) | |

## Cluster / pattern references

_(No CL- clusters defined yet.)_

- Related SEVs in family: S668293 (cogwheel hstu_cint), S668542 (scribe), S659671 (serving)
- D105917200 is root-cause diff for both S668320 and S668828

## Followup items (not yet done)

1. andrewxmao: verify if S668320 fix covers TGIF `_group_layer_norm_fwd_esr_cint_mc4` kernel packaging.
2. Check `fbcode/hammer/v2/ops/triton/cc/group_layer_norm/` — esr_cint_mc4 variant needs explicit compilation/registration.
3. If kernel missing: rebuild R980.1 with MC4/esr_cint kernel or revert D105917200.

## Cross-refs

- SEVs discussed: S668828, S668320, S668293, S668542, S659671
- Diffs: D105917200, D105765209, D104452948
- Posts: none
- Related threads: none
