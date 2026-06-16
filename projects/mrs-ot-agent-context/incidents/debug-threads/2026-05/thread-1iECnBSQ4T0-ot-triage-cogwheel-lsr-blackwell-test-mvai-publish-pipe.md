# Thread Summary: S664099 cogwheel_lsr_blackwell_test B200 NCCL + path-rename bug discovery and repair

_Source: spaces/AAQAVOjYc80 thread `1iECnBSQ4T0` · 8 messages · 2026-05-15_
_Summarized: 2026-05-16 15:32 PT · last-msg-time: 2026-05-15T23:42:01Z_

## What was discussed

Denny pasted a second triage for S664099 (cogwheel_lsr_blackwell_test — NCCL ALLTOALL_BASE 600s timeout on B200/maz hosts, 4 consecutive failures across att2/3/4). MyClaw flagged that S664099 had already been triaged in thread `pAM4x2WxE0c` (04:32 PT same day) and questioned whether ot-sev-monitor's dedup was working. Denny directed MyClaw to investigate. MyClaw traced the re-fire to stale `~/.myclaw-ot-team/` path references in 12 cron prompts, but then corrected: the live state file was at the right path, so the stale paths weren't the root cause. The real culprit: a parallel `~/.myclaw-ot-team/` stub directory had grown silently; two state files diverged, causing dedup misses for S664296 + S664024. MyClaw executed a full repair: rewrote 40 occurrences across 16 files, replaced the stub directory with a symlink, re-asserted 11 cron prompts to the daemon DB, and merged the authoritative ot-sev-state.json to 40 IDs.

## Key decisions made

- [2026-05-15T23:40:33Z] Denny approved rewriting `myclaw-ot-team` → `myclaw-ot-bot` across all 12 cron files (Denny: "Yes").
- [2026-05-15T23:40:45Z] Denny directed full, complete repair (Denny: "Attack the solution to be complete and reliable").
- [2026-05-15T23:42:01Z] MyClaw implemented belt-and-suspenders: `~/.myclaw-ot-team/` replaced with symlink → `~/.myclaw-ot-bot/`; even a future stale-path prompt auto-redirects.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../mrs-ot-agent-src/team_bot/cron-jobs/*.md` (12 files) | `myclaw-ot-team` → `myclaw-ot-bot` (40 occurrences across 16 files) |
| `~/.myclaw-ot-team/` | Replaced with symlink → `~/.myclaw-ot-bot/` |
| `~/.myclaw-ot-bot/.../ot-sev-state.json` | Merged to 40 IDs including today's S664099/S664296/S664024/S664499/S664344 |
| `~/myclaw-ot-team-backup-2026-05-15-1640/` | Backup of removed stub directory |

## Cluster / pattern references

- [CL-004] — S664099 (cogwheel_lsr_blackwell_test NCCL ALLTOALL_BASE, B200/maz) is a conveyor/cogwheel publish failure. tsp_maz-specific; tsp_snb baseline succeeded → hardware/fabric root, not code.

## Followup items (not yet done)

1. Verify next ot-sev-monitor cron run (~17:16 PT) does NOT re-trigger S664099/S664296/S664024 now that they're in diagnosed_ids — status: open at thread close.

## Cross-refs

- SEVs discussed: S664099 (B200 NCCL ALLTOALL maz hang), S664296, S664024, S664499, S664344
- Related threads: `pAM4x2WxE0c` (earlier S664099 triage same day)
