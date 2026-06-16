---
name: human-2026-06-10-2137-m-3h2Dpoklw
description: Operator flagged invalid Workplace link for W1346326357462107; bot traced canonical /permalink/ URL; identified /posts/+comment_id variant as the bad form
human_involved: true
metadata:
  type: project
  thread_id: m-3h2Dpoklw
  space: spaces/AAQAVOjYc80
  msg_count: 10
  first_msg_pt: "2026-06-10 21:37 PDT"
  last_msg_pt: "2026-06-10 21:41 PDT"
  summarized_pt: "2026-06-11 21:04 PDT"
---

# Thread Summary: Invalid Workplace link for W1346326357462107

_Source: spaces/AAQAVOjYc80 thread `m-3h2Dpoklw` · 10 messages · 2026-06-10 21:37–21:41 PDT_
_Summarized: 2026-06-11 21:04 PT · last-msg-time: 2026-06-11T04:41:50Z_

## What was discussed

Operator flagged "link is invalid" and provided post ID W1346326357462107. Bot investigated using `meta workplace.post describe` to get the canonical URL, then traced which cron output produced the bad link. The bad link was the `/posts/` + `?comment_id=` deep-link variant; the correct form is `/permalink/`.

## Key decisions made

- **Canonical URL confirmed** (2026-06-10 21:39): `https://fb.workplace.com/groups/mrs.ot/permalink/1346326357462107/` — resolved via `meta workplace.post describe`; author Jamey Zhang, the Jun-8 mrs.ot AGG-misconfig post.
- **Bad link source identified** (2026-06-10 21:39): the bad variant was `.../posts/1346326357462107/?comment_id=1346465457448197` — two bugs: `/posts/` instead of `/permalink/`, and a `comment_id` deep-link that dies if the comment was edited/removed.
- **Cron URL construction is correct** (2026-06-10 21:39): post-monitor already builds `/permalink/` form and avoids `internalfb.com/work/permalink/`; the bad link likely came from an older bot message or copied thread URL.
- **W### does not auto-linkify** (2026-06-10 21:41): only T###/D###/S###/A### auto-resolve in this space; W### is just the post ID, renders as plain text.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — read-only investigation) | — |

## Cluster / pattern references

- [P-004] — no 404 URLs; this was a live P-004 violation; confirmed cron source is clean

## Followup items (not yet done)

(none — investigation complete, canonical URL delivered)

## Cross-refs

- Posts: W1346326357462107 (Jamey Zhang, mrs.ot AGG-misconfig, 2026-06-08)
- Related threads: (none)
