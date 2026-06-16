# Thread Summary: S665129 mvai/light_cli Conveyor Blocked by Sandcastle OOM

_Source: spaces/AAQAVOjYc80 thread `qf-_sYisFbM` · 3 messages · 2026-05-16T18:24–18:25 UTC_
_Summarized: 2026-05-16 23:33 PT · last-msg-time: 2026-05-16T18:25:34Z_

## What was discussed

Denny posted a triage for S665129: 34 mvai/light_cli conveyor releases blocked since ~18:30 PDT May 15 (16h+). Root cause: two compounding Sandcastle vectors — chronic OOM on build nodes (recurrence of S648404) and capacity-rebalancing preemptions on gang-scheduled workers. Training jobs were unaffected; blockage was T3 (fbpkg build phase) only. Bot classified this as UPSTREAM_INFRA vs CONVEYOR_CODE_REGRESSION.

## Key decisions made

- **Class should be UPSTREAM_INFRA, not CONVEYOR_REGRESSION** (2026-05-16T18:25:14Z): CONVEYOR_REGRESSION reserved for code-side breaks (e.g., S665090 D105369549 compilation error); S665129 is Sandcastle infra failure — different owner, different fix path.
- **T3-only impact framing is the most operationally useful sentence** (same): "training jobs unaffected; blockage is in fbpkg build phase only" tells model owners not to chase their job.
- **Class enum refinement proposed**: split CONVEYOR_REGRESSION → CONVEYOR_CODE_REGRESSION / CONVEYOR_INFRA_FAILURE to disambiguate for mega-learning clustering.
- **Auto-tag executed**: `mvai-online-training` added to S665129 (2026-05-16T18:25:34Z — Denny message confirming auto-tag ✓).

## Files / artifacts touched

| path | what changed |
|---|---|
| `ot-alert-monitor.md` / `ot-sev-monitor.md` / `ot-post-monitor.md` | Class enum split (CONVEYOR_CODE_REGRESSION / CONVEYOR_INFRA_FAILURE) proposed; to be landed |
| `mega-learnings/2026-W20.md` | Cluster F-prime Sandcastle sub-class entry proposed |

## Cluster / pattern references

- [CL-004] — Cogwheel/conveyor publish failures; S665129 is a Sandcastle-infra sub-class (N=2 with "chronic/recurrence" in SEV text; S648404 + S665129)

## Followup items (not yet done)

(none — S665129 was self-resolving via manual retry; class enum split was folded into other cron-prompt edits in thread `1cVsOXXSa34`)

## Cross-refs

- SEVs discussed: S665129, S665090, S648404
- Related threads: `6pKeH_XqjcE` (class enum was designed there), `1cVsOXXSa34` (class enum edit landed there)
