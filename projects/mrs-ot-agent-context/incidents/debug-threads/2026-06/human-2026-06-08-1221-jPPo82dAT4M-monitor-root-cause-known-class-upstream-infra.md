---
thread_id: jPPo82dAT4M
human_involved: true
space: spaces/AAQAVOjYc80
msg_count: 25
first_msg_time: 2026-06-08T19:21:06Z
last_msg_time: 2026-06-09T14:15:30Z
---

# Thread Summary: P-017 Codification — Upstream Issue Handling Principle

_Source: spaces/AAQAVOjYc80 thread `jPPo82dAT4M` · 25 messages · 2026-06-08 to 2026-06-09_
_Summarized: 2026-06-09 22:04 PT · last-msg-time: 2026-06-09T14:15:30Z_

## What was discussed

Thread began with a cron triage output (🟡 MONITOR) for S668542 scribe lag affecting two IG reels retrieval models (2144816217 + 2130305043); validator confirmed. The following day, operator pushed for a generic next step for recurring+upstream issues: file ONE task anchored on a decisive, reproducible metric query that confirms from ground truth and doubles as the acceptance test. The bot built `tools/team-space-precision.sh`, filed a decisive-metric task (T275142534), and then formally codified the lesson as P-017.

Operator also caught a confirmation-bait ending ("Want me to, or keep it as practice?") emitted in the very message proposing the anti-confirmation-bait principle — a direct P-016/no-confirmation-bait rule violation.

## Key decisions made

- [2026-06-09T14:03] Generalize: recurring+high-confidence+**upstream** issues → always produce one decisive-query task; never re-narrate the symptom.
- [2026-06-09T14:07] P-017 is the **upstream counterpart to P-016**: P-016 = fix in-lane; P-017 = measure+track+hand-off what you can't fix.
- [2026-06-09T14:07] Codify as a new principle file `P-017-upstream-issue-decisive-metric-task.md` + INDEX row.
- [2026-06-09T14:08] Wire P-017 into both CLAUDE.md (notes canonical) and RULES.md as a cross-cutting always-in-force principle.
- [2026-06-09T14:15] Operator confirmed "why ask" on the confirmation-bait ending — added to no-confirmation-bait memory.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../principles/P-017-upstream-issue-decisive-metric-task.md` | NEW — principle file |
| `notes/.../principles/INDEX.md` | P-017 row added |
| `notes/mrs-ot-agent-src/team_bot/CLAUDE.md` (canonical) | Cross-cutting P-017 line added |
| `agent_identity/RULES.md` (canonical) | P-017 enforcement section added |
| `tools/team-space-precision.sh` | NEW — ground-truth precision query script |

## Cluster / pattern references

_(no verified CL-NNN in failure-patterns.md at time of summary)_

## Followup items (not yet done)

_(none — P-017 codification fully landed in all 4 enforcement surfaces per thread)_

## Cross-refs

- SEVs discussed: S668542
- Tasks: T275142534 (founding decisive-metric task), T275122535 (upstream interactive-leak tracking)
- Related threads: `pnL5GSkFRW0` (where the helper was built and wired)
