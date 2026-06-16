---
name: auto-2026-06-05-1549-TMSbFoqItA0-weekly-reliability-digest-routing-to-team
description: Re-routing ot-weekly-reliability-digest from operator 1:1 to team space; committing untracked notes files
human_involved: false
---

# Thread Summary: Re-routing ot-weekly-reliability-digest to team space

_Source: spaces/AAQAVOjYc80 thread `TMSbFoqItA0` · 16 messages · 2026-06-05_
_Summarized: 2026-06-05 23:43 PT · last-msg-time: 2026-06-05T22:54:08Z_

## What was discussed

Denny directed the bot to re-route the `ot-weekly-reliability-digest` cron (per-PG crash counts, error patterns, top challenges) from the operator 1:1 to the team space (`spaces/AAQA2bZMw24`). The bot had originally set up the cron to deliver to the 1:1 with an explicit "promotable to team" hook; Denny triggered that promotion. While committing the routing change, the bot discovered that the cron file, its scan script (`scan-weekly-failures.sh`), the MANIFEST entry, and `lib_qps.py` were all untracked in notes from earlier that day's cross-space build work.

## Key decisions made

- **Route per-PG fleet reliability to team space** — per-PG crashes/error-patterns/top-challenges qualifies as "one team digest" under the Send-Gate (same class as `ot-fleet-health`). Decision driven by Denny's explicit direction at 22:49:09Z.
- **Check-could-not-run error stays on 1:1** — plumbing/error signal is operator-facing, not team-facing.
- **Add VERIFY-BY-READBACK on team sends** — strengthens team-chat-send-gate compliance.
- **Commit all untracked notes files in one pass** — untracked cron, scan script, MANIFEST, and lib_qps.py committed together (commits `2a7731` / `621b96` / `939c54`); durability gap closed.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/…/cron-jobs/ot-weekly-reliability-digest.md` | Delivery target changed to team space; density rule updated |
| `notes/…/team_bot/scan-weekly-failures.sh` | Committed (was untracked) |
| `notes/…/team_bot/MANIFEST.json` | Registration entry committed |
| `notes/…/lib_qps.py` | Committed (was untracked from cross-space build) |

## Cluster / pattern references

_(no cluster IDs cited — none verified against failure-patterns.md)_

## Followup items (not yet done)

_(none explicitly discussed — first team post on Mon 08:30 schedule)_

## Cross-refs

- SEVs discussed: none
- Related threads: `5rwiSwCGHBo` (prior thread on ot-thread-summarizer purpose), `C2naImRX58I` (digest noise discussion)
