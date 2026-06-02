# Thread Summary: Bot Message Volume — 115 msgs/day, Threading Root Cause, Volume-Watch Cron

_Source: spaces/AAQAVOjYc80 thread `AL3dqJevKm0` · 7 messages · 2026-05-29T04:42–05:16 UTC_
_Summarized: 2026-05-29 13:46 PT · last-msg-time: 2026-05-29T05:16:26Z_

## What was discussed

Denny observed 115 bot messages in the space for the day — well above expected ~30–50. Root cause identified as bot not threading replies back into conversations, causing repeat follow-ups. Denny asked whether a monitoring cron existed; bot built and registered `ot-bot-volume-watch` (hourly, 33 cron jobs total). Discussion also confirmed cron manifests live in OT master agent and sync to fbcode.

## Key decisions made

- `ot-bot-volume-watch` cron registered as the volume monitor (2026-05-29T05:15Z); hourly cadence, three-tier silent/log/alert policy
- Thresholds (120–220 steady) flagged as higher than Denny's ≤25 busy target; re-baselining expected after 1 week of telemetry
- Cron job stored in OT master agent → eventually synced to fbcode (confirmed 2026-05-29T05:12Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| OT master agent cron manifest | ot-bot-volume-watch added (hourly) |
| sqlite telemetry table | new table created for volume tracking |

## Cluster / pattern references

_(failure-patterns.md not found — omitting cluster refs)_

## Followup items (not yet done)

1. Re-baseline thresholds after 1 week of telemetry data; owner: bot, status: pending

## Cross-refs

- Related threads: `HJG9Ec2LuX4` (threading discipline / 38-thread complaint)
