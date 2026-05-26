# Thread Summary: Build Automation to Pull Project Context Weekly — context-ingestor-gchat + context-ingestor-posts

_Source: spaces/AAQAVOjYc80 thread `Oe2XG0WVOMY` · 4 messages · 2026-05-18T17:14–T17:22Z_
_Summarized: 2026-05-19 00:41 PT · last-msg-time: 2026-05-18T17:22:40Z_

## What was discussed

Denny directed the bot to build weekly automation for pulling project context from team GChat spaces and expert Workplace posts. Two new cron jobs were created and registered: `context-ingestor-gchat` (Mondays 09:00 PT) watching 4 spaces, and `context-ingestor-posts` (Mondays 09:15 PT) covering 7 OT experts. Both jobs produce catch-up markdown files in `human-input-domain/`.

## Key decisions made

- **2026-05-18T17:14Z** — `context-ingestor-gchat` created: watches 4 spaces (RT Infra WS2, MVAI OT Dev, IG ATS Alerting, MRS OT Oncall); 7d window default, 14d first-run; drops BOT senders to avoid feedback loops.
- **2026-05-18T17:22Z** — `context-ingestor-posts` created: 7 experts (dennyzhang, lupaul, llu6, yabinzh, dkotfis, prgzz, peiyangy); single combined weekly file; OT-related groups only, no DM/1:1 content.
- Both land as jobs 28 and 29 in MANIFEST; first outputs target 2026-05-25.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-src/MANIFEST.json` | Added `context-ingestor-gchat` (job 28) and `context-ingestor-posts` (job 29) |
| `human-input-domain/` | Output dir for weekly catch-up files (one per space per run for gchat; one combined for posts) |

## Cluster / pattern references

_(No failure-cluster references — this thread is about cron creation, not incident triage.)_

## Followup items (not yet done)

_(None explicitly discussed.)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: `8Nzx9nUrsOI` (context-ingestor jobs missing from daemon on first Monday)
