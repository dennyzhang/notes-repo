# Thread Summary: Publishing Stability Detector — STUS ITEM_EMB_DELTA vs FULL_SNAPSHOT Misdiagnosis

_Source: spaces/AAQAVOjYc80 thread `iCit8F3gmTA` · 9 messages · 2026-05-29T05:03–05:16 UTC_
_Summarized: 2026-05-29 13:46 PT · last-msg-time: 2026-05-29T05:16:41Z_

## What was discussed

Bot incorrectly triaged model 2132070936 (i2i STUS) Publishing Stability alert as "model doesn't produce FULL_SNAPSHOT by design." Denny corrected: the detector fires on FULL_SNAPSHOT absence, but FULL_SNAPSHOT was actually being produced — visible in UMM with the right filter. Separately, bot failed to check alert history and operator comments before triaging. Two new triage rules (R23, R24) were codified.

## Key decisions made

- R23 (UMM query hardening): use `--limit=1000` minimum + aggregate by snapshot_type; "never produces" claim requires count=0 in ≥1000-row window (2026-05-29T05:07Z)
- R24 (prior alert history first): run `oncall.feed list --title-contains=<model_id>` + read operator task descriptions BEFORE any classification (2026-05-29T05:09Z)
- Model 2132070936 verdict updated: STUS+INPLACE_SNAPSHOT confirmed; historical FULL_SNAPSHOT through 5/26 → config-vs-regression question to be confirmed by owner T2702384980132191 (2026-05-29T05:09Z)

## Files / artifacts touched

| path | what changed |
|---|---|
| notes auto-learnings | R23-HARDENING + R24 PRIOR-ALERT-HISTORY codified |
| sqlite (triage rules table) | R23 + R24 inserted |

## Cluster / pattern references

_(failure-patterns.md not found — omitting cluster refs)_

## Followup items (not yet done)

_(none — owner T2702384980132191 needs to confirm FULL_SNAPSHOT regression vs design change; not bot's action item)_

## Cross-refs

- SEVs discussed: S668828 (upstream context, TGIF validation)
- Posts: T2702384980132191 (owner task, model 2132070936 STUS+INPLACE_SNAPSHOT)
