---
name: shift-gdoc-comment-reply-threading
description: Denny flagged missing WP posts in shift gdoc and that bot was not replying in gdoc comment threads. Both root-caused and fixed. T275803389 (missing-posts) + T275803195 (font fix).
metadata:
  type: project
  human_involved: true
---

# Thread Summary: Shift Gdoc — Missing WP Posts + Reply in Comment Threads

_Source: spaces/AAQAVOjYc80 thread `0J2jhgZrS6c` · 11 messages · 2026-06-13 22:53–2026-06-14 06:04 PDT_
_Summarized: 2026-06-14 21:04 PDT · last-msg-time: 2026-06-14T06:04 UTC_

## What was discussed

Denny left comments in the OT oncall shift gdoc and told the bot to reply in the comment threads per the cheatsheet, not just summarize in chat. Two issues were addressed:

1. **Missing WP post W1350388963722513** (Ziwei's checkpoint post, mrs.ot, Jun 13 10:57 PT) absent from the Daily Timeline. Root cause: `ot-shift-summary` runs ~08:30 PT and writes each day's section once; any post arriving after the scan is permanently missing from that day. The `[h]` count cross-check is unenforced prose.

2. **Bot not replying in gdoc comment threads** — bot was summarizing in gchat instead of posting `[myclaw-ot bot reply]` in the comment itself.

Daemon behavior confirmed for this specific doc: large fetches need `--no-daemon` (daemon hangs), but small writes (comment replies) need the daemon (`--no-daemon` hangs). Opposite of fetch.

## Key decisions made

- **T275803389 filed**: `ot-shift-summary` must re-scan the full shift window every run and reconcile missing WP posts into each day's timeline. Hard count-assert vs `ot-post-monitor` to be added.
- **T275803195**: font normalization fix — `normalize-shift-timeline-fonts.sh` built; forces Daily-Timeline entries to NORMAL_TEXT, day-headings stay HEADING_4; 26 mis-styled→0.
- **Gdoc comment reply correctly sent** in the comment thread (verified 1 reply posted); cheatsheet updated with the fetch-vs-write daemon split for this doc.

## Files / artifacts touched

| path | what changed |
|---|---|
| `cheatsheets/gdocs/rules.md` | Fetch-vs-write daemon nuance for large docs; comment reply routing rule |

## Cluster / pattern references

_(No existing CL-NNN matched)_

## Followup items (not yet done)

1. T275803389 — reconcile-missing-WP-posts fix: implement re-scan + count-assert in `ot-shift-summary`
2. T275803195 — verify font fix is wired into cron and holding

## Cross-refs

- Tasks: T275803389, T275803195
- Related threads: `xq9U9j0tvgU` (same session, same threading correction)
