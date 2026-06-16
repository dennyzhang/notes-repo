# Thread Summary: Post-postmortem digest validation — 3 Workplace posts (2026-05-20)

_Source: spaces/AAQAVOjYc80 thread `DKEswmprWqA` · 10 messages · 2026-05-21 04:39–04:41 UTC_
_Summarized: 2026-05-24 17:50 PT · last-msg-time: 2026-05-21T04:41:32Z_

## What was discussed

The `ot-post-postmortem-digest` cron posted verdicts for 3 Workplace posts; the operator and conversational bot validated each. Two were confirmed clean; one needed a cluster nit; two cron bugs were surfaced.

## Key decisions made

- `2026-05-21T04:40:04Z` — **W1330685625692847** confirmed: REAL_OT_FAILURE_RECURRING, CL-001/M-013 (STUS kmeans corpus collapse, T2I 22K→1,315 embs). P63 (L22) applies. Ask: ronghuang to confirm corpus-size monitor.
- `2026-05-21T04:40:22Z` — **W1321547686606641** confirmed with cluster nit: should be `(HOWTO, no cluster)` + cross-reference CL-013, not mapped INTO CL-013. HOWTOs should not increment cluster fire-counts.
- `2026-05-21T04:40:22Z` — **W1324845696276840** confirmed: CL-003 (GMPP publisher ZippyDB/Scribe dependency). New P-row suggested: SilverTorch OT with GMPP publisher = ZippyDB/Scribe-dependent; in-trainer mvai publishers insulated.
- `2026-05-21T04:40:45Z` — Post-emit in-thread validation pattern endorsed as standard flow for validator-unavailable cron context (path-2, no new code).

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-posts/2026-05/2026-05-20-W1330685625692847.md` | Archived (bot-created) |
| `incidents/resolved-posts/2026-05/2026-05-17-W1321547686606641.md` | Updated (bot-created) |
| `incidents/resolved-posts/2026-05/2026-05-20-W1324845696276840.md` | Archived (bot-created) |

## Cluster / pattern references

- [CL-001] — W1330685625692847: snapshot-stuck-CREATING, M-013 STUS kmeans corpus collapse
- [CL-003] — W1324845696276840: GMPP publisher ZippyDB/Scribe dependency; new P-row candidate
- [CL-013] — W1321547686606641: cross-referenced (not incremented — HOWTO, not a real failure)

## Followup items (not yet done)

1. New P-row for SilverTorch GMPP+ZippyDB architectural dependency — to be drafted for next weekly diff, pair with CL-003.
2. `ot-triage-summary.md` filename convention fix (old `<sev>-<date>-A<id>.md` format still emitting) — priority-bump requested.
3. Alert URL binding bug in digest cron — multiple entries pointing to wrong/shared alert IDs. Needs fix in prompt.

## Cross-refs

- SEVs discussed: none (alert URLs present but some were incorrect — see followup 3)
- Posts: W1330685625692847, W1321547686606641, W1324845696276840
- Related threads: none cited
