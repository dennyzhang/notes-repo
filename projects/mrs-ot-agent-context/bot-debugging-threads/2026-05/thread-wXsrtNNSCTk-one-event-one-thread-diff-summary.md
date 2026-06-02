# Thread Summary: One-Event-One-Thread Rule + D106890247 File-Inventory Summary Complaint

_Source: spaces/AAQAVOjYc80 thread `wXsrtNNSCTk` · 5 messages · 2026-05-31_
_Summarized: 2026-06-01 04:45 PT · last-msg-time: 2026-05-31T02:31:28Z_

## What was discussed

Denny corrected the bot for posting top-level GChat messages instead of replying in-thread. Two issues surfaced: (1) the bot had been leaking main-loop summaries as top-level messages rather than folding them into the originating thread; (2) D106890247's diff summary contained a "Synced files:" file inventory, which violates the cheatsheet rule (diff stat already shows files; never enumerate them in the summary).

## Key decisions made

- **2026-05-31T02:26** Bot confirmed: every event gets one thread; main-loop summaries must not spawn top-level messages.
- **2026-05-31T02:27** D106890247's summary stripped of the "Synced files:" inventory. Root cause: the weekly-sync script's default commit template dumps a file list; the proper weekly-fold template doesn't. Fixed.

## Files / artifacts touched

| path | what changed |
|---|---|
| D106890247 | diff summary amended — file inventory removed |

## Cluster / pattern references

_(omitted — failure-patterns.md does not exist yet)_

## Followup items (not yet done)

_(none explicitly discussed)_

## Cross-refs

- Diffs: D106890247
- Related threads: `S2zrir2qpBY` (stray submit root cause), `HJG9Ec2LuX4` (original thread-reply threading fix)
