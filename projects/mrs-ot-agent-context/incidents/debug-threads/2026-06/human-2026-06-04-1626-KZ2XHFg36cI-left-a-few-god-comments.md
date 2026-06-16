---
human_involved: true
---

# Thread Summary: Gdoc shift-summary 6/9 tab — tab positioning + dedup/link-on-title fix

_Source: spaces/AAQAVOjYc80 thread `KZ2XHFg36cI` · 10 messages · 2026-06-04 16:26–16:36 UTC_
_Summarized: 2026-06-04 21:45 PT · last-msg-time: 2026-06-04T16:36:52Z_

## What was discussed

Denny left two more gdoc comments on the 6/9 shift-summary tab following the earlier session (`La6YhlkSkqo`). Both addressed: (1) tab can't be auto-positioned to top (API limitation); (2) Overview WP lines duplicated the timeline entries and links weren't hyperlinked on title text. The `gdocs edit` export API was hanging again, so the live recompact was deferred; both fixes were applied durably to the v5 template.

## Key decisions made

- **Comment AAAB81zHo3k ("why the new tab is not inserted to the top?"):** Google Docs API v1 has no `moveTab`/tab-position field — new tabs always append to the bottom. Alternative proposed: switch from one-new-tab-per-week to updating the top tab in place each week. Denny decision pending. Timestamp: 2026-06-04T16:26 UTC.
- **Comment AAAB81zHo3Q ("duplicate rows / attach link to title"):** two template rules updated:
  - *Dedup*: a post authored pre-shift and resolved this shift → Overview WP-reports summary ONLY, never also in Timeline. A post authored during the shift → Timeline.
  - *Link-on-title*: hyperlink sits on topic text, no bare `W###` token (saves space).
  Both generalized to v5 template. Timestamp: 2026-06-04T16:35 UTC.
- **Live recompact deferred**: `gdocs edit` (heavy all-tabs export) was hanging even at max timeout; blind find-replace risks worsening the tab. Template fix is durable; 6/9 self-corrects on next render, or recompact when export API responds.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/cron-jobs/ot-shift-summary-template.html` | v5 — dedup rule (authored-during-shift = timeline, pre-shift = Overview only); link-on-title rule (no bare W###) |
| gdoc `[Bot] OT Oncall Shift` tab `6/9` | replied to both comments (AAAB81zHo3k, AAAB81zHo3Q) with `[myclaw-ot bot reply]` prefix; live content NOT recompacted (API unavailable) |

## Cluster / pattern references

_(none)_

## Followup items (not yet done)

1. Recompact 6/9 tab live (dedup + link-on-title) when `gdocs edit` export API is responsive. Owner: dennyzhang/bot. Status: blocked on API flakiness.
2. Decide on tab-convention change: one-tab-per-week (current) vs update-top-tab-in-place (avoids positioning issue). Owner: Denny. Status: pending.

## Cross-refs

- Related threads: `La6YhlkSkqo` (earlier session same tab — major alerts + user posts comments)
