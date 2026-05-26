# CLAUDE.md

## What This Is

Personal notes directory for **dennyzhang** in the Meta notes repo. Serves three purposes:

1. **Project files** — where fbcode landing would be too slow (plans, analysis, patches, agent context)
2. **Public sharing materials** — talks, presentations, and teaching content for the team
3. **Cheatsheets** — personal preferences and how-tos for general tasks

## Directory Structure

```
users/dennyzhang/
  scripts/            # Devserver setup scripts (survive reinstalls)
    disk-cleanup.sh   # Cron: */30 * * * * — clears worktrees, caches, logs
  projects/           # Project-specific notes and artifacts
    mrs-ot/           # MRS Online Training reliability work
  mrs-ot-agent/       # OT Master Agent — canonical source (migrated from fbcode 2026-05-15)
    SKILL.md          # Agent skill definition
    known_patterns.md # Learned OT failure patterns
    human-input/      # Human-authored reference docs: triage discipline, decision matrix, ownership, failure-mode catalog (was: references/, renamed 2026-05-23)
    team_bot/         # MyClaw team bot config, cron job prompts, sync scripts
  sharings-public/    # Knowledge sharing sessions (talks, presentations)
    TRACKER.md        # Schedule and status of all sharings
    PIPELINE.md       # Backlog of future sharing ideas
    HUMAN-INPUTS.md   # Major decisions and corrections (auto-tracked)
    2026-02-ot-deep-dive/       # Delivered: OT Architecture Deep Dive
    2026-04-claude-autolearn/   # Preparing: Claude Autolearn talk
    2026-04-ot-master-agent-eval/  # OT Master Agent eval kickoff
    area-monitor-portable-*/    # Portable monitoring tooling
    routine-workflow-portable-*/# Portable workflow tooling
```

## Work Domain

PE (Production Engineering) on MRS Online Training infrastructure at Meta. Key areas:

- **Online Training reliability** — delta publishing (sparse, dense, item embedding), model freshness SLOs, ATS latency
- **OT oncall triage** — SEV analysis, failure classification (8-type taxonomy), triage decision trees
- **OT Master Agent** — automated SEV triage agent, evaluated via replay-eval on historical SEVs (T259215482)
- **Knowledge sharing** — monthly sessions teaching OT architecture, debugging, and AI workflows to the PE team

## Key Systems

MVAI, MAST, DPP, UMM, Manifold, TGIF, Hedwig, SilverTorch, IPNext, ZCH — see `sharings-public/2026-02-ot-deep-dive/` for deep architectural context.

## Cheatsheets

`cheatsheets/` contains task-specific guides that MUST be loaded before starting work. See `cheatsheets/CHEATSHEET-INDEX.md` for routing. Key diff-related cheatsheets:

- `cheatsheets/diff/common.md` — always load for any diff operation
- `cheatsheets/diff/common.md` § "Diff Can't Land" — load when diagnosing landing failures (rebase first, then CI, then review status)
- `cheatsheets/diff/fbcode.md` — additional rules for fbcode diffs

## Conventions

- Sharings follow `sharings-public/YYYY-MM-<topic>/` naming
- `TRACKER.md` is the source of truth for sharing schedule
- `PIPELINE.md` holds future ideas; pull from here when scheduling
- `HUMAN-INPUTS.md` tracks major corrections and directional decisions
- This is a notes repo: push with `sl push --to master`, no `jf submit`
