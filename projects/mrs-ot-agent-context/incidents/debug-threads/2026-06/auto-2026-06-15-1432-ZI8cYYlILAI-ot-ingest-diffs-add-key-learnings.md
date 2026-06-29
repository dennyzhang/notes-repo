---
name: ot-ingest-diffs-add-key-learnings
description: Operator asked the ingest-diffs report to surface key learnings from the ingested diffs, not just a bare count. Bot added a deterministic change-delta sidecar and synthesis step. Backtested on 57 diffs.
metadata:
  type: project
  human_involved: false
---

# Thread Summary: ot-ingest-diffs — add key learnings to ingestion report

_Source: spaces/AAQAVOjYc80 thread `ZI8cYYlILAI` · 16 messages · 2026-06-15_
_Summarized: 2026-06-17 10:04 PT · last-msg-time: 2026-06-15T21:58:49Z_

## What was discussed

Operator: "your report should also show key things you have learned from this ingestion." The `ot-ingest-diffs` report was emitting only a bare count (`synced 300 diffs, 8/8 authors`) — zero signal about what was in the diffs. Bot diagnosed, applied the Cron Output Effectiveness rule, and made two changes: (1) the ingest tool now emits a deterministic change-delta sidecar each run (diffs new or status-changed since last sync, trust-sorted), and (2) the prompt synthesizes 2-4 themed bullets from that delta, each explaining what the change means for OT, not just echoing the title. Backtested on 7-day real data (57 diffs): `cron_precision` verified, synthesis examples confirmed useful (e.g., OT detector false-alarm reduction diffs, TMS refresh, delta-update subscriber adds).

Bot also checked sibling `ot-ingest-gdocs` — it already names which docs changed, but content-level diff would need a bigger lift (retained render comparison); deferred to a real doc-drift run rather than shipping unbacktested.

## Key decisions made

- Per-item compute (change detection, delta selection) goes in the scan tool (deterministic); LLM synthesizes from the output — not the other way around. This generalizes to all ingestion crons. (2026-06-15T21:33:36Z)
- `ot-ingest-gdocs` follow-up deferred until a real doc-drift run justifies the retained-render lift. (2026-06-15T21:39:13Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../tools/ingest-diffs.sh` (or equivalent) | Added delta-detection loop + sidecar emit |
| `notes/.../team_bot/cron-jobs/ot-ingest-diffs.md` | Step 4 + step 6 updated for synthesis from sidecar |
| sqlite `myclaw.db` | Updated (`updates=1`), verified content present |
| notes repo | Committed (`569c20f57400`) + cloud-synced |

## Cluster / pattern references

_(No confirmed cluster IDs in failure-patterns.md — omitted)_

## Followup items (not yet done)

1. `ot-ingest-gdocs` content-level diff (what changed in the doc body) — deferred until a real doc-drift run warrants the retained-render approach.

## Cross-refs

- Related threads: none directly
