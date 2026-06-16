# Thread Summary: mitigated-alerts folder deep-improvement session

_Source: spaces/AAQAVOjYc80 thread `Uc-pVBEXNQ8` · 36 messages · 2026-05-17_
_Summarized: 2026-05-18 07:33 PT · last-msg-time: 2026-05-17T18:25:00Z_

## What was discussed

Rapid-fire critique of `mitigated-alerts/` (17:17–18:25 UTC, 11 commits). Operator gave targeted feedback; bot pushed fixes. Recurring failure: bot shipped prompt-spec changes without backtesting, causing silent errors caught only by operator spot-check.

## Key decisions made

- **17:18Z** — 4 fixes: prune 26 stubs, add UPSERT+stub-guard, regen INDEX, rewrite README 3→80 lines.
- **17:21Z** — Step 10 (follow-up: dead-detector + tight-threshold) + step 11 (chronic-noisy, top-3 percentile ≥3 floor) added to cron. Step 10 then narrowed 4→2 categories.
- **17:34Z** — "Cluster" → "Error pattern" throughout; priority canonicalized `P0-P4/high` → `critical/high/medium/low/unknown` (OneDetection). Files renamed via `sl mv`.
- **18:03Z** — P-row citation must pass falsifier; failure → `NEEDS_INVESTIGATION` + explicit no-match note. Daemon `has-3-cron-fixes` verified.
- **18:07Z** — Retroactive headers on all 13 archives via title-only classification (2-pass; pass-1 cross-ref false positives self-caught).
- **18:17Z** — R20 extended to 3 sources: SEVs + alerts API + local grep (mitigated-* + mega-learnings); INDEX auto-gen files excluded.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-context/mitigated-alerts/INDEX.md` | "Error pattern" column, OneDetection priority, 91% coverage |
| `mrs-ot-agent-context/mitigated-alerts/2026-05/*.md` | Stubs pruned, retroactive headers, R22 AGG backfills, 3-source R20 |
| `mrs-ot-agent-context/mitigated-alerts/README.md` | 3→80 lines; OneDetection taxonomy, drill-down workflow |
| `mrs-ot-agent-context/tools/regen-archive-indexes.sh` | Column rename; regen all 3 INDEX files |
| `mrs-ot-agent-src/cron-jobs/ot-daily-learning-mitigated-alerts.md` | Step 10+11, falsifier-respect, 3-source R20, stub-guard |

## Cluster / pattern references

- [CL-001] — FULL_SNAPSHOT archives (A1955, A4366, A898) retroactively classified
- [CL-003] — Scribe/ZippyDB (A2387, A977, A1480); P58 falsifier failed for A1480 (no active SEV at fire time)
- [CL-013] — A1480 cited in failure-patterns.md (found during R20 backtest — bot missed it initially)
- [CL-017] — Shampoo NaN archives (A1703, A25209) retroactively classified
- [CL-018] — AGG blind spots; R22 expansion backfilled A2126294138 + A2130305043

## Followup items (not yet done)

1. Items 5-7 (verdict field, bot-triage URL in archive, scuba scope) — deferred, need bigger prompt restructure
2. Item 8 (back-reference failure-patterns.md → archives) — Proposal D scope
3. P-ID collision: two fires both proposed "P59" — verify runtime grep on next cron fire
4. Write P-015 (backtest before shipping); add falsifier-respect to RULES.md for direct-chat work

## Cross-refs

- SEVs: S665163 (P58 falsifier failure — SEV started 10h after A1480 alert cleared)
- Related threads: `RtQW3qQf5tg` (R20 local-sweep clarification at 11:16 PT)
