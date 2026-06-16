---
name: gdoc-cheatsheet-minimal-fields-comment-read
human_involved: true
thread_id: igwh_-xIFmk
space: spaces/AAQAVOjYc80
first_msg: 2026-06-02T22:29:55Z
last_msg: 2026-06-02T22:37:59Z
messages: 14
summarized: 2026-06-03 00:43 PT
---

# Thread Summary: Gdoc Cheatsheet — Minimal-Fields Raw API Fixes Comment-Read Timeouts

_Source: spaces/AAQAVOjYc80 thread `igwh_-xIFmk` · 14 messages · 2026-06-02 15:29–15:37 PT_
_Summarized: 2026-06-03 00:43 PT · last-msg-time: 2026-06-02T22:37Z_

## What was discussed

Denny asked whether the bot had loaded the gdoc cheatsheet before working on the comment-read problem that had been timing out all afternoon. Bot admitted it hadn't consulted the cheatsheet for *this specific* problem. Consulting it immediately revealed the actual fix: cheatsheet line 140 (raw Drive API + minimal field set) returns in ~5s vs the full call timing out. Bot applied the fix, resolved 3 unresolved operator comments, and shipped RULE 72 + a SLICK probe fix.

## Key decisions made

- **Cheatsheet line 140 is the fix for gdoc comment-read timeouts** (2026-06-02T22:31): raw Drive API with minimal field set (`comments(id,resolved,content)`) — drops `quotedFileContent` + `replies`. Returns in ~5s. The bot had been brute-forcing the heavy call all afternoon.
- **Daemon restart (line 217) was NOT the fix here** (2026-06-02T22:31): single daemon, not a duplicate-daemon socket contention issue; it was payload size.
- **3 unresolved comments addressed** (2026-06-02T22:34–22:36) — all via `[myclaw-ot bot reply]` prefix replies (no anchor text touched, per cheatsheet):
  - `jVk` ("leave a template placeholder"): `{{LOCAL_NOTES}}` added to shift-summary template; RULE 72 → preserve operator Local-notes verbatim across every render, bot read-only on it. Live in sqlite, mirrored to fbcode.
  - `jRM` ("adds no value" on Paul-shift-start line): covered by R67 (that line is dropped); replied.
  - `jQo` ("slick.sli probe failed — debug and fix"): root cause is wrong service-id (`mrs_online_training`); canonical IDs are `mrs_ml/v1_discovery` / `mrs_ml/v1_instagram` (already in template). Interim R66 emits hardcoded dashboard links; real probe fix is the next step.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/ot-shift-summary-template.html` | `{{LOCAL_NOTES}}` placeholder added; SLICK canonical service-ids confirmed present |
| `notes/.../cron-jobs/ot-shift-summary.md` | RULE 72 (preserve Local-notes) added |
| sqlite `cron_jobs` | prompt update pushed live |
| fbcode mirror | mirrored from notes |

## Cluster / pattern references

_(No CL-NNN clusters defined in failure-patterns.md)_

- Net lesson: load the cheatsheet for the specific modality *before* brute-forcing. The minimal-fields raw read would have saved the whole afternoon of timeouts.

## Followup items (not yet done)

1. SLICK probe fix: update the service-id from `mrs_online_training` to `mrs_ml/v1_discovery` + `mrs_ml/v1_instagram` in the actual probe invocation (R66 currently hardcodes dashboard links as interim fallback).

## Cross-refs

- Related threads: `blGfifF3vKU` (same-session gdoc work; same timeout issues)
- Related threads: `8IyKRxB9wPE` (gdoc comment deletion that motivated cheatsheet pre-load rule)
