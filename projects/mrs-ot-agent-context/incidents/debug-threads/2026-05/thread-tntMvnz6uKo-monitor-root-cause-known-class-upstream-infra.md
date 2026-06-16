# Thread Summary: Model 2121953369 (fb_reels_hstu) + triage discipline + "act don't ask" preference

_Source: spaces/AAQAVOjYc80 thread `tntMvnz6uKo` · 8 messages · 2026-05-23T10:58Z → 2026-05-23T12:55Z_
_Summarized: 2026-05-23 21:47 PT · last-msg-time: 2026-05-23T12:55:17Z_

## What was discussed

Two things happened in this thread: (1) triage for model 2121953369 stuck PENDING due to S667390 SMC write throttling; (2) bot self-critique about having 35 triage rules but not applying them systematically, followed by Denny delivering the key preference "Act; don't ask if unnecessary." The bot then acted on this preference to clean up outstanding parked items (notes .bak cleanup, Sapling-gitignore gotcha capture).

## Key decisions made

- **2026-05-23T10:58:43Z** — Verdict 🟡 MONITOR / UPSTREAM_INFRA: S667390 (SMC write throttling) MITIGATED; MAST v8 PENDING startup, expect RUNNING ≤20 min. v5 killed by xchen14 manually. No OT infra action — route to MAST/SMC tier config if v8 stays stuck.
- **2026-05-23T12:49:43Z** — Denny: "Act; don't ask if unnecessary." Preference anchored — bias toward action when reversible or clear best answer; stop multiple-choice (a/b/c) endings.
- **2026-05-23T12:55:17Z** — Bot acted on preference: updated memory with `act-dont-ask` preference + Sapling-uses-.gitignore gotcha; notes .bak cleanup completed in same pass.

## Files / artifacts touched

| path | what changed |
|---|---|
| `memory/preference_act-dont-ask.md` | Created (new preference from 2026-05-23T12:49) |
| `memory/gotcha_sapling-uses-gitignore.md` | Created (Sapling uses .gitignore semantics) |
| `memory/MEMORY.md` | Both entries added |
| `~/notes/` | `.bak` files cleaned up |
| paste P2348831284 | Machine fields for m2121953369 |

## Cluster / pattern references

_(No CL match — S667390 SMC write throttling is infra-level, not an OT failure pattern)_

## Followup items (not yet done)

1. Monitor v8 (`mvai-training-online-2121953369`): expect RUNNING ≤20 min post-S667390 mitigation — owner: xchen14.
2. If recurs: fix tier config for `flow_entitlement=fb_video_lsr_qe` in SMC tier registry — owner: MVAI-infra.

## Cross-refs

- SEVs discussed: S667390 (SMC write throttling, MITIGATED), S667493 (same blast radius)
- Posts: none
- Related threads: none
