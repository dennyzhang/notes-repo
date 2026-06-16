# AI Failure Modes Cheatsheet

Recurring AI mistakes in this workspace. **Inclusion bar: ≥3 distinct dated AUTO-LEARNINGS entries reviewed and confirmed by Denny** (not by the audit script's keyword regex — that just narrows candidates).

This file is NOT auto-injected. Load it manually before non-trivial work, or rely on the PreToolUse enforcement hooks (`config/hooks/bash-guard.sh`) which catch the structurally-enforceable rules at action time.

## The rules

### 1. Find root cause — never symptom-fix
Confirmed-recurring theme. Representative entries: producer/parser marker mismatch (2026-04-17), `set -euo pipefail` + unprotected gdocs call = silent script death (2026-04-10), root-cause reviewer comments on your own diffs (2026-03-22), investigate root cause after first failure never retry blindly (undated).

- Read the FULL error before proposing anything
- 3 failed fix attempts → STOP, question the architecture (10x-engineer:systematic-debugging Phase 4.5)
- `set -euo pipefail` + unprotected commands = silent script death — wrap with `timeout` / `|| true`
- Use SEV tools for SEV investigation, not SSH/WebFetch
- The agent that did the work should NOT be the one that judges it (sunk-cost bias)
- Producer/parser drift is a silent-failure class — when output is empty, suspect the parser before the data

### 2. Use the right tool — don't reach for Bash first
This rule is currently enforced by `bash-guard.sh` for `find` and `--no-verify` (the two patterns Denny has caught me reaching for). The audit script has not surfaced ≥3 confirmed AUTO-LEARNINGS entries for tool substitution as a class — the rule lives here because the enforcement hooks exist, not because of historical recurrence count.

- File search → `Glob`, NOT `find` (BLOCKED by hook; override with `CLAUDE_OVERRIDE=1` for genuine `-delete`/`-exec`)
- Content search → `Grep` / `search_files` MCP, NOT `grep`/`rg` (already blocked by PreToolUse on `Grep|Glob` in fbsource)
- Read file → `Read`, NOT `cat`
- Skill → `Skill` tool, NEVER `Read` on a SKILL.md file
- Edit file → `Edit`, NOT `sed`
- `--no-verify` → BLOCKED by hook (CLAUDE.md hard rule)

## Below the bar — covered elsewhere

| Theme | Where it lives |
|---|---|
| Sync pairs (single-site changes) | `cheatsheets/system/sync-rules.md` |
| Prove "done" / never claim it | SOUL.md, scattered in workflow guides |
| No fabrication of IDs/paths/names | `memory/feedback_never_guess_unixname.md`, SOUL.md |
| Async ownership (4 guarantees) | `cheatsheets/agents/workflow-design.md` rule 5 |
| No bypass shortcuts (`--no-verify`, etc.) | CLAUDE.md hard rules + `bash-guard.sh` (BLOCKED) |
| No broadcast in boss's voice | SOUL.md "Hard NOs" |

If a "covered elsewhere" theme is reviewed and confirmed at ≥3 dates, promote it to a numbered rule above.

## How to extend this cheatsheet

The audit script is a CANDIDATE GENERATOR, not a verifier. Its keyword regex has a high false-positive rate (V1 versions tagged "Read" inside "Reply" as a tool-substitution match).

```bash
# 1. List themes with candidate counts (entries that *might* match, not verified):
python3 scripts/audit-failure-modes.py

# 2. Drill into a theme to read full text:
python3 scripts/audit-failure-modes.py --theme root-cause

# 3. Generate a review checklist for human Y/N classification:
python3 scripts/audit-failure-modes.py --review root-cause > /tmp/review.md
# Then Denny opens /tmp/review.md, marks [Y]/[N]/[?], counts confirmed entries.
```

Promotion process:
1. Run `--review` for a candidate theme
2. Mark each entry [Y]/[N]/[?]
3. If ≥3 [Y] entries have distinct dates → add a numbered rule above with representative entries cited inline
4. If structurally enforceable, add a PreToolUse block to `bash-guard.sh` and cite "BLOCKED by hook" in the rule body
5. If keyword regex misses obvious matches, edit `THEMES` in `audit-failure-modes.py` and re-run

## Self-audit before any non-trivial action

- [ ] Have I PROVEN this works (output, not belief)?
- [ ] Did I find the ROOT cause or patch a symptom?
- [ ] Right TOOL for the job (Glob/Grep/Read/Skill/Edit)?

_Last updated: 2026-05-12. Maintainer: dennyzhang._
