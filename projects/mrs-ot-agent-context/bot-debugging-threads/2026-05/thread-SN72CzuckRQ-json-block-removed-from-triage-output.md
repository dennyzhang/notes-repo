# Thread Summary: JSON block removed from triage gchat output

_Source: spaces/AAQAVOjYc80 thread `SN72CzuckRQ` · 4 messages · 2026-05-18T00:36–00:53 UTC_
_Summarized: 2026-05-18 22:42 PT · last-msg-time: 2026-05-18T00:53:11Z_

## What was discussed

Bot posted a full triage with a large JSON block at the bottom. Operator asked (2026-05-18T00:52:52Z): "The json output is good. But do I really need to see it as a human?" Bot agreed, removed the JSON block from gchat messages across all three live triage crons, replacing it with a one-line `📊 Machine fields: <paste_url>` link.

## Key decisions made

- (2026-05-18T00:52:52Z) JSON block removed from gchat triage output — full JSON still written to sqlite `raw_response` column; surface via paste link only
- Paste link kept stable via `pastry` overwrite; fallback: inline JSON with `⚠️ paste creation failed` prefix if pastry times out (>10s)
- Validator status flip (`pending → confirmed/discrepancy`) updates paste content, not the gchat message

## Files / artifacts touched

| path | what changed |
|---|---|
| (3 live triage cron prompts) | JSON block stripped from gchat output; replaced with paste link |
| sqlite `raw_response` | unchanged — machine consumers read from here unaffected |

## Cluster / pattern references

- No cluster directly implicated. Relates to output-format hygiene for CL-NNN triage posts.

## Followup items (not yet done)

_(none explicitly discussed)_

## Cross-refs

- SEVs discussed: S665222, S665067
- Posts: none
- Related threads: none
