---
human_involved: true
---

# Thread Summary: Gdoc shift-summary 6/9 tab — two operator comments addressed (major alerts + user posts)

_Source: spaces/AAQAVOjYc80 thread `La6YhlkSkqo` · 19 messages · 2026-06-04 06:29–06:45 UTC_
_Summarized: 2026-06-04 21:45 PT · last-msg-time: 2026-06-04T06:45:10Z_

## What was discussed

Denny left two inline comments on the 6/9 shift-summary gdoc tab. The bot addressed both, with a key technical challenge: the `gdocs edit` (all-tabs export) API was hanging repeatedly throughout the session, requiring fallback to targeted `insert-html` commands (which preserve comment anchors). Both content inserts landed (rc=0) and both operator comments survived (verified via raw Drive API).

## Key decisions made

- **Comment AAAB8zSlyDY ("Also list major alerts as they will call oncall"):** Added major-alert line to 🚨 Critical section listing publishing-stability page-eligible alerts. Generalized to v5 template as a standing rule. Timestamp: Denny 2026-06-04T06:29 UTC.
- **Comment AAAB8zSlyDU ("Why user post is missing?"):** Added WP user reports (W1332046782223398 Threads-U2M, W1336024098492333 MC12 arm3) to 6/3 Daily Timeline. Generalized to v5 template. Timestamp: Denny 2026-06-04T06:29 UTC.
- **insert-html over full-replace**: when a tab has operator comments, use targeted inserts; `gdocs replace` on a commented tab orphans anchors. This is now the standing method. Timestamp: 2026-06-04T06:34 UTC.
- **Template generalization (P-003)**: both feedback items written into `ot-shift-summary-template.html` v5 as standing rules so every future render includes them automatically.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/cron-jobs/ot-shift-summary-template.html` | v5 — added major-alerts rule to Critical section; added WP user-posts rule to Daily Timeline |
| gdoc `[Bot] OT Oncall Shift` tab `6/9` | two insert-html content additions (comment-safe); both operator comments preserved + replied with `[myclaw-ot bot reply]` prefix |

## Cluster / pattern references

_(none)_

## Followup items (not yet done)

1. Tab positioning: 6/9 tab is at the bottom of the tab list (Docs API cannot reorder); Denny to manually drag it to the top. Status: pending operator action.

## Cross-refs

- Related threads: `KZ2XHFg36cI` (follow-up gdoc comments on same tab — tab positioning + dedup)
- Posts: W1332046782223398, W1336024098492333 (content added to gdoc)
