# Thread Summary: Shift summary format regression — journal → dense, template v5 codified

_Source: spaces/AAQAVOjYc80 thread `3tFk1T8bbyM` · 24 messages · 2026-05-29T17:02–17:43 UTC_
_Summarized: 2026-05-29 16:45 PT · last-msg-time: 2026-05-29T17:43:57Z_

## What was discussed

Denny flagged that today's oncall shift summary regressed to journal-style prose bullets instead of the dense tabular format. Denny also questioned why the bot replied to the main GChat space instead of in-thread (separate violation). Root cause of the format regression: bot bypassed `ot-shift-summary-template.html` and free-styled the ghtml. Bot re-rendered the 6/2 tab dense, then codified template v5 with Critical-alerts first + density rules + `{{CRITICAL_ALERTS}}` placeholder. Gdoc had 13 orphaned comments from prior full-replace rewrites; 11 resolved, 2 open. Standing item added: hyperlinks for SEVs/alerts/posts in the gdoc.

## Key decisions made

- **Template v5 = FORMAT SOURCE OF TRUTH** (2026-05-29T17:13Z) — fill `{{PLACEHOLDER}}`s, never free-style ghtml. Critical-alerts section added to template body with dedicated placeholder.
- **Full-replace rewrites orphan gdoc comments** (2026-05-29T17:31Z) — root cause of 13-comment pile-up. Fix: switch to targeted `find-replace`/`batch-update` edits for mid-shift updates so comment anchors survive.
- **Hyperlinks standing open item added to ot-shift-gdoc-config.json** — SEV → sevmanager URL, alert A<id> → AIP URL, post W<id> → WP permalink, diff D<N> → auto-render. Same recurring issue as gdoc comment AAAB6SHJh-4 (2026-05-26).

## Files / artifacts touched

| path | what changed |
|---|---|
| ot-shift-summary-template.html | v5: Critical-alerts section + {{CRITICAL_ALERTS}} placeholder + density rules |
| ot-shift-gdoc-config.json | standing_open_items: `o_daily_timeline_hyperlinks` added |
| memory/gotcha_shift-summary-always-fill-template.md | created/updated |
| 6/2 oncall shift gdoc tab | re-rendered dense (revision 3149 pinned) |

## Cluster / pattern references

_(none — failure-patterns.md absent or no matching cluster)_

## Followup items (not yet done)

1. gdoc 6/2 tab scrub: bot-content + trunk-health section removal — mentioned, status unclear.
2. 5/23-24 robocall SEV identification for prior-shift section — Denny to clarify which SEV.
3. carryover placement toggle — quick fix, awaiting Denny confirmation.

## Cross-refs

- Related threads: `HJG9Ec2LuX4` (validator FAILs + thread-folding, same session)
- SEVs discussed: (prior-shift robocalls — specific S# not confirmed)
