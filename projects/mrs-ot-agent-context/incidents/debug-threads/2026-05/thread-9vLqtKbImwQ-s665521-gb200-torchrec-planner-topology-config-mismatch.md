# Thread Summary: S665521 Deep-Dive — GB200_HP torchrec Planner/Runtime Topology Config Mismatch

_Source: spaces/AAQAVOjYc80 thread `9vLqtKbImwQ` · 19 messages · 2026-05-19_
_Summarized: 2026-05-19 22:41 PT · last-msg-time: 2026-05-19T16:55:07Z_

## What was discussed

Denny opened asking why the bot hadn't debugged S665521. Initial reply landed in wrong thread (`-QYYCRmS75s`); re-delivered here after correction. Full first-principles debug: 3 ig_reels_tab_esr_ttsn jobs crash-looping on GB200_HP with `RuntimeError: Number of local shards (0) does not match metadata (1) on rank (46)` at `ShardedEmbeddingBagCollection._initialize_torch_state()`. Root cause: D99725267 added `host_count_per_domain` to `MAST_HW_CONFIG_ENV`; torchrec planner reads it first (intra_group_size=72); runtime reads `TOPOLOGY_DOMAIN_MULTIPLE` (intra_group_size=8) — plan/runtime mismatch. Fix in flight: D105651338 (zhaokangke, Unpublished). Model 2123867502 ran 63h fine on old hosts, crashed after MAST preemption moved it to new-field hosts at 16:22 PT.

Denny asked educational questions: concepts of sharding, MAST scheduling, topology domains (all answered). Then: "what are remaining improvements?" — bot listed 6 improvements (#1 startup contract check, #2 MAST env-field registry, #3 topology-config unification library, #4 cross-team CI matrix, #5 crash-loop auto-page, #6 canary on new hardware). Denny's final call: "leave it to POC."

## Key decisions made

- **[2026-05-19T16:34:32Z]** Denny's summary ("two envs don't agree with each other") confirmed as mostly accurate; bot tightened: the fight is planner vs runtime reading different configs, not the configs fighting each other.
- **[2026-05-19T16:54:47Z]** "Leave it to POC" — bot does NOT file tasks for improvements #1-6, does NOT comment on S665521, does NOT ping torchrec or MAST infra oncalls. POC (zhaokangke for D105651338; SEV retro owner for prevention field) owns org-fix decisions.

## Files / artifacts touched

| path | what changed |
|---|---|
| (no files written) | Debug and educational content in-thread only |

## Cluster / pattern references

- [CL-006] — MAST scheduling/capacity as silent root: job ran fine, got preempted, new hosts have different env → different behavior. Matches CL-006 "environment change at restart" pattern.

## Followup items (not yet done)

_(none — all improvement follow-ups explicitly delegated to POC by Denny at 2026-05-19T16:54:47Z)_

## Cross-refs

- SEVs discussed: S665521
- Diffs: D99725267 (root-cause introduce), D105651338 (fix, in review)
- Related threads: `-QYYCRmS75s` (original wrong-thread reply, full debug also there), `bu_6JUetxfk` (same session: bot-infra fixes)
