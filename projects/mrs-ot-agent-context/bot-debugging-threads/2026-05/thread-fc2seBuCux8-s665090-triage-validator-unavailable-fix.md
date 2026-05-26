# Thread Summary: S665090 Triage Review + Validator-Unavailable Cron Fix

_Source: spaces/AAQAVOjYc80 thread `fc2seBuCux8` · 7 messages · 2026-05-16 00:25 PT → 2026-05-16 10:37 PT_
_Summarized: 2026-05-16 21:32 PT · last-msg-time: 2026-05-16T17:37:47Z_

## What was discussed

Operator posted S665090 triage (mvai/light_cli fbpkg Build Node blocked 5h — D105369549 compile error, fixed by D105404656). Bot gave qualitative feedback on triage quality. Inline validator ran DEGRADED (no subagent tool in cron context). Discussion identified validator-unavailable as a recurring pattern across 3+ cron runs. Operator asked bot to fix it directly rather than file a followup task.

## Key decisions made

- **2026-05-16T07:26Z** — Validator-unavailable feedback: inline self-check (same model, same context) is not real validation — false confidence. `DEGRADED` tag is honest; structural fix is making subagent available in cron env.
- **2026-05-16T07:26Z** — Auto-tag `mvai-online-training` on S665090 flagged as potentially over-broad (release oncall owns it, not OT oncall). No untag action taken.
- **2026-05-16T17:34Z** — Operator directed: "you should fix it, right?" → 4 cron prompts patched with explicit `validator-unavailable` handling (skip step, emit `🚫 Validator unavailable`, set `validator_status: unavailable`; forbid inline recheck). Prompts migrated to notes.
- **2026-05-16T17:37Z** — Operator approved migrating remaining 13 fbcode-only cron prompts to notes (pure mirror copy, no semantic changes).

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-src/team_bot/cron-jobs/ot-daily-learning-mitigated-alerts.md` | validator-unavailable handling added |
| `mrs-ot-agent-src/team_bot/cron-jobs/ot-daily-learning-mitigated-posts.md` | same |
| `mrs-ot-agent-src/team_bot/cron-jobs/ot-daily-learning-mitigated-sevs.md` | same |
| `mrs-ot-agent-src/team_bot/cron-jobs/ot-knowledge-curation.md` | same; D1 blocked when unavailable |

## Cluster / pattern references

- [CL-004] — Cogwheel/conveyor publish failures (S665090 is in this class — Build Node blocked by compile error in the publish toolchain).

## Followup items (not yet done)

_(None — fix was fully applied in this thread.)_

## Cross-refs

- SEVs: S665090 (light_cli Build Node blocked, compile error D105369549, fixed D105404656), S661987 (CLOSED, capacity — separate)
- Related threads: `PvDkZtj_nyo` (mitigated-alerts missed fire, same cron-health context)
