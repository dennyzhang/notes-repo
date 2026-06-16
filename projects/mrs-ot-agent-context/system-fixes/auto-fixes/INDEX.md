# Auto-Fixes — Bot-Proposed Fix Patches

> **⚠ MECHANISM MIGRATED (2026-06).** The markdown patch files in this directory
> are the **legacy** auto-fix form (last produced ~2026-05-27). The live pipeline
> is now **meta tasks → draft diffs**, not markdown:
>
> 1. Monitors (`ot-alert-monitor`, `ot-knowledge-distillation`) file
>    **`[OT auto-fix]` meta tasks** (owner=dennyzhang, tag `mrs-ot-reliability`)
>    for each detector misconfig / discipline gap found during triage.
> 2. **`ot-autofix-diff-drafter`** cron (daily ~11:13 PT, registered 2026-06-09)
>    turns each clear+verifiable task into one `--draft` diff, links it to the
>    task, and tracks land-rate in `state/ot-autofix-diff-drafter-state.json`.
> 3. Operator reviews + lands. **Effectiveness metric = drafted→landed rate**
>    (surfaced in the weekly digest), NOT file count here.
>
> This directory is kept for the historical 2026-05 patches (teaching value) but
> is **no longer written to**. To find current auto-fix work, query open
> `[OT auto-fix]` tasks and their linked diffs, not this folder.

_Legacy description (markdown era): concrete patches for specific cron prompt /
discipline gaps — each a self-contained patch with target file, before/after
snippet, why, expected impact, validation plan._

Distinguished from `../solution-design.md` (high-level strategy at the proposal
level) — auto-fixes/ contained **actionable patches** ready to apply.

## Structure

```
auto-fixes/
  YYYY-MM-DD/                  ← grouped by date the gap was identified
    <topic-slug>.md            ← one fix per file
```

Each fix file follows the schema in `FIX-TEMPLATE.md`.

## How fixes get promoted

1. Bot identifies gap during triage → drafts fix patch here
2. Operator reviews + approves
3. Patch applied to live cron prompt (via `setup-cron-jobs.sh` or direct edit)
4. Fix file moved to `landed/` or annotated with `status: landed` + diff/commit hash

## Status legend

- `🟡 drafted` — bot wrote it, awaiting operator review
- `🟢 approved` — operator signed off, ready to apply
- `✅ landed` — applied to live cron, with reference to landing commit
- `❌ rejected` — operator declined, with reason
- `⏸ on hold` — depends on something else landing first
