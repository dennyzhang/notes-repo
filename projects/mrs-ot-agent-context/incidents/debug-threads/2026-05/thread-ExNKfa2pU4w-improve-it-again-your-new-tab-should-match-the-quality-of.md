# Thread Summary: Oncall Shift Summary 5/18 Tab — Quality Fix Session

_Source: spaces/AAQAVOjYc80 thread `ExNKfa2pU4w` · 23 messages · 2026-05-19T01:42–02:48Z_
_Summarized: 2026-05-19 21:41 PT · last-msg-time: 2026-05-19T02:48:47Z_

## What was discussed

Extended debug session to bring the 5/18 oncall shift summary gdoc tab up to 5/12 quality. Four major failure modes discovered and fixed: (1) `meta google.docs get --tab-id` silently ignores `--tab-id` and returns the whole doc, causing false "no difference" comparisons. (2) Markdown table body dropped by gdoc's `replace --markdown` parser when separator row was malformed — Section 3b appeared as header-only. (3) Inline `<a href>` tags in bullets/paragraphs pass through as raw HTML soup; only table cells convert to native hyperlinks with `replace --markdown`. (4) cron rendered to the skill-template schema, not 5/12's hand-curated schema — column names differed, OT-IC-vs-Bot signal table missing entirely. All four were fixed iteratively. Denny also caught that the gdoc cheatsheet's post-push formatting checklist (column widths, header bg color, table font size) was not being run, resulting in sparse-looking tables.

## Key decisions made

- [01:45:40Z] `meta google.docs get --tab-id` is broken — always returns full doc regardless of tab. Verification must use `meta google.docs structure` or slice full dump by tab-title markers. Documented as L11.
- [02:38:01Z] Cron prompt schema overwritten to match 5/12 reference layout exactly: 6 tables with 5/12's column names/order. Prompt schema changes committed and synced to fbcode + daemon DB. Path: `cron-jobs/ot-shift-summary.md`.
- [02:22:37Z] DONE criteria for gdoc shift summary codified: (1) visual-state check (0 raw `<a href>` soup), (2) ≤10 TODO (oncall) cells, (3) schema parity with 5/12, (4) live SEV freshness, (5) no placeholder strings in data cells.
- [02:38:01Z] Anchor syntax rule: use `<url|label>` markdown form (works in bullets/paragraphs/headers), NOT `<a href>` (only works in table cells with `replace --markdown`). Added to gdoc cheatsheet + cron prompt.
- [03:07:10Z] Post-push formatting checklist (column widths + header bg `#C9DAF8` + table font 11pt) is mandatory after ANY `replace --markdown` push, not optional. Cheatsheet amended.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../cheatsheets/gdocs/rules.md` | Added Visual-State Verification section; updated post-push formatting checklist |
| `~/notes/.../cron-jobs/ot-shift-summary.md` | Schema overhaul (6 tables matching 5/12); anchor syntax `<a href>` → `<url|label>`; mandatory enrichment rules |
| `~/fbsource/fbcode/pe_mrs_ml/...` | Synced; arc formatted; daemon DB updated |
| `~/notes/.../learnings.md` | L11 (tab-id CLI bug), L12 (enrichment depth), L13 (two-strike protocol), L14 (anchor syntax) |

## Cluster / pattern references

_(no cluster IDs applicable — this is a bot-tooling/cron quality thread, not a model failure triage)_

## Followup items (not yet done)

1. Rewrite remaining `<a href>` examples in non-table contexts in `ot-shift-summary.md` prompt (L14 noted as TODO before Tue 08:30 PT cron; Denny did not ask to verify completion)

## Cross-refs

- Related threads: `-QYYCRmS75s` (5/18 tab update continuation), `FeqK7S5gmug` (running in parallel)
