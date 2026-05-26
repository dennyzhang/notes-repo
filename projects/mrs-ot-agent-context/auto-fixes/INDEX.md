# Auto-Fixes — Bot-Proposed Fix Patches

_Concrete patches for specific cron prompt / discipline gaps. Each fix is a self-contained patch with: target file, before/after snippet, why, expected impact, validation plan._

Distinguished from `../solution-design.md` (which is high-level strategy at the proposal level) — auto-fixes/ contains **actionable patches** ready to apply.

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
