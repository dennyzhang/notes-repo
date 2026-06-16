# scripts/lib/ — Shared cron library

Shared primitives that `scripts/cron-*.sh` callers import to kill the "fix one, fix all" anti-pattern. One canonical implementation per behavior; a fix lands in one place, every caller inherits it.

Two layers:
- **Bash layer** (`gdocs_lib.sh`) — in-place enhancement for existing cron scripts. Sourceable, zero refactor cost.
- **Python layer** (`gdocs_helper.py`) — typed data structures + tested JSON builders. For new scripts or when a cron is rewritten in Python.

## Files

### `gdocs_lib.sh` — Google Docs push + format primitives (bash)

Sourced after `cron-alert.sh`. Provides:

| Helper | Purpose |
|---|---|
| `gdocs_replace_safe` | Wrapper around `gdocs-safe-replace.sh` — comment-safe push |
| `gdocs_get_structure` | Raw `gdocs content get-structure` with safe fallback |
| `gdocs_format_tab_body_font` | 11pt on tables + NORMAL_TEXT (body-font rule) |
| `gdocs_shrink_empty_lines` | 1pt font + 1pt line spacing on empty separators |
| `gdocs_apply_font_family` | Arial across the full tab |
| `gdocs_apply_header_row_bg` | `#C9DAF8` on the first row of every table |
| `gdocs_set_col_widths` | Per-table column widths (CSV of PT values) |
| `gdocs_verify_header_block` | Check Purpose/Pipeline/Source paragraph under H1 |
| `gdocs_cleanup_empty_lines` | Wrapper around `gdocs-cleanup-empty-lines.sh` |
| `gdocs_post_push` | Runs the full cheatsheet post-push checklist in one call |
| `gdocs_track_error` | Increments `GDOCS_LIB_ERRORS` and logs to stderr |
| `gdocs_exit_with_status` | Non-zero exit + `cron_alert` if any error during run |
| `_gdocs_batch` | Internal: batch-update with DRY_RUN support + error tracking |

### Error tracking

Every mutating helper increments `GDOCS_LIB_ERRORS` on failure and logs `[ERROR] ... at $0:$LINENO` to stderr. Call `gdocs_exit_with_status "$(basename "$0" .sh)"` at the end of a script to propagate a non-zero exit and fire `cron_alert`.

Why this matters: the AI Health Dashboard greps cron logs for `[ERROR]` tags. With `|| true` swallowers (the previous pattern), broken pushes stayed silent for hours until Denny looked at the doc. With the lib, failures reach `ALERTS.md` within minutes.

### Dry-run mode

Set `DRY_RUN=1` to redirect all mutating gdocs calls to `/tmp/gdocs-dryrun-$$/batch-*.json` instead of pushing. Structure inspection still hits the live API so generated requests reflect real document state.

```bash
DRY_RUN=1 bash scripts/cron-area-monitor.sh
# → /tmp/gdocs-dryrun-<pid>/batch-001.json, batch-002.json, ...
```

Pre-commit hook (`.git/hooks/pre-commit`) runs bash syntax + shellcheck on edited scripts. A follow-up will wire `DRY_RUN=1` into the hook so structural bugs are caught before commit.

## Usage pattern

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/cron-alert.sh"
source "$(dirname "$0")/lib/gdocs_lib.sh"

DOC_ID="$(get_doc_id routine)"
TAB_ID="$(get_doc_tab routine primary)"

# ... generate content, push ...
gdocs_replace_safe "$DOC_ID" --tab-id "$TAB_ID" --from "$OUT_HTML"

# Run full post-push checklist (body font + shrink + font family + header bg + verify header)
gdocs_post_push "$DOC_ID" "$TAB_ID" "Routine"

# Apply tab-specific column widths
gdocs_set_col_widths "$DOC_ID" "$TAB_ID" "Routine" "100,268,100"

# At end of script: propagate any errors to cron-alert + exit non-zero
gdocs_exit_with_status "$(basename "$0" .sh)"
```

### `gdocs_helper.py` — Typed Python primitives

CLI + importable module. Reads `gdocs content get-structure` output from stdin, emits batch-update JSON or validation results. Replaces brittle inline Python-in-bash heredocs that currently do the same work.

**CLI:**
| Command | Purpose |
|---|---|
| `col-widths --tab-id X --widths 180,280,176` | Emit batch-update JSON to set column widths on every table |
| `body-font --tab-id X --size 11` | Emit batch-update JSON for 11pt body font on tables + paragraphs |
| `shrink-empty --tab-id X` | Emit batch-update JSON to collapse empty separator paragraphs |
| `header-bg --tab-id X --color '#C9DAF8'` | Emit batch-update JSON for header-row background on every table |
| `validate --rule h1-today --rule min-tables=3` | Validate invariants; exit 1 on fail |

**Python API:**
```python
from gdocs_helper import parse_structure, BatchUpdateBuilder, tables
entries = parse_structure(structure_text)
builder = BatchUpdateBuilder(tab_id=tab_id)
for tbl in tables(entries):
    builder.set_col_widths(tbl.start, [180, 280, 176])
print(builder.to_json())
```

**Bash integration:**
```bash
structure=$(gdocs content get-structure "$DOC_ID" --tab-id "$TAB_ID")
json=$(echo "$structure" | python3 scripts/lib/gdocs_helper.py col-widths \
    --tab-id "$TAB_ID" --widths "180,280,176")
echo "$json" | gdocs batch-update "$DOC_ID" --data -
```

### `test_gdocs_lib.sh` — Bash tests (13 tests, unittest-style)
### `test_gdocs_helper.py` — Python tests (30 tests, stdlib unittest)

### `cron-helpers.sh` — Cron utility helpers

Sourced by cron scripts after `cron-alert.sh` + `gdocs_lib.sh`. Currently provides `restore_table_format` (snapshot-based table column-width preservation across pushes — Google Docs resets widths to equal-width on row insertion). Source path:

```bash
source "$SCRIPT_DIR/lib/cron-helpers.sh"   # SCRIPT_DIR points at scripts/
```

### `precommit-cron-checks.sh` — Pre-commit quality gate

Validates staged files against: bash syntax, shellcheck errors, silent mutating-command swallowers, Python syntax. Runs the test harnesses when lib files or their tests are staged. Invoked by `.git/hooks/pre-commit` (thin 5-line shim). Bypass with `git commit --no-verify` (not recommended).

## Canonical source

Most bash functions were extracted verbatim from `cron-area-monitor.sh` (the most battle-tested formatting code) and parameterized. If a behavior needs to change, change it here — not in the caller.

## Related

- `scripts/cron-alert.sh` — PATH, FBID identity, heartbeats, tab freshness, doc-ID helpers, cron_alert
- `scripts/gdocs-safe-replace.sh` — comment-count guard (hard block on replace if comments exist)
- `scripts/gdocs-cleanup-empty-lines.sh` — shared empty-line cleanup (pre-existing)
- `cheatsheets/gdocs/rules.md` — the behavior these helpers enforce

## Migration status (as of 2026-04-18)

**Source `gdocs_lib.sh` + propagate errors at script end:**
- ✅ cron-area-monitor.sh (full Tier 3: pre-push revision capture + post-push validation)
- ✅ cron-ai-health.sh
- ✅ cron-alert-sync.sh
- ✅ cron-ot-support-triage.sh
- ✅ cron-nightly-routine-preprocessing.sh
- ✅ cron-gchat-group-digest.sh
- ⬜ cron-gchat-copilot.sh (large — migrate in its own session)
- ⬜ cron-signal-to-action.sh
- ⬜ cron-ai-audit.sh
- ⬜ cron-audit-agent.sh
- ⬜ cron-people-gdoc-sync.sh
- ⬜ cron-project-gdoc-sync.sh
- ⬜ cron-workflow-self-eval.sh

**Python helper adoption:** New scripts written in Python should import `gdocs_helper` directly. Existing bash scripts can call the CLI subcommands (`python3 scripts/lib/gdocs_helper.py <cmd>`) where structure parsing or JSON building is complex enough to justify it.

## Tiered progress against the bug-prevention program

| Tier | Status | Deliverable |
|---|---|---|
| 1 | ✅ Done | Shared lib + error tracking + no-silent-swallower sweep (6 scripts, 24 call sites) + pre-commit gate |
| 2 | ✅ Done | `DRY_RUN=1` shim for `gdocs` + `timeout gdocs`; captures mutating calls to `/tmp/gdocs-dryrun-*/` |
| 3 | ✅ Partial | Pre-push revision capture + post-push validation + rollback-ready alerts. Wired fully in `cron-area-monitor.sh`; other 5 scripts have error propagation but need per-doc validators |
| 4 | ✅ Done | 43 automated tests (13 bash + 30 python), all wired into pre-commit |
| 5 | ✅ Groundwork | `gdocs_helper.py` exists with typed API + CLI + tests. Full cron rewrites remain per-script multi-session work |
