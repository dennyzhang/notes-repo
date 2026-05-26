# System Architecture Map

How all pieces of the Claude harness connect. Load this when you need to understand the full system.

## Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    CLAUDE.md (Rules)                     │
│  Core rules, safeguards, execution discipline            │
└──────────────────────┬──────────────────────────────────┘
                       │ loads
┌──────────────────────▼──────────────────────────────────┐
│              Cheatsheets (Knowledge)                     │
│  22 files in 6 folders: diff/, gdocs/, oncall/,          │
│  career/, research/, system/                             │
│  Lazy-loaded via CHEATSHEET-INDEX.md                     │
└──────────────────────┬──────────────────────────────────┘
                       │ enforced by
┌──────────────────────▼──────────────────────────────────┐
│              Hooks (Enforcement)                         │
│  PreToolUse:  enforce-prerequisites.sh, bash-guard.sh    │
│  PostToolUse: track-preflight.sh, gdocs-post-verify.sh   │
│               check-filename-convention.sh               │
│               backup-critical-files.sh                   │
│               auto-prescreener.sh, auto-retry-transient  │
│  Other:       audit-logger.sh, notify-idle.sh            │
│               user-prompt-handler.sh                     │
└──────────────────────┬──────────────────────────────────┘
                       │ runs on
┌──────────────────────▼──────────────────────────────────┐
│              Cron Scripts (Automation)                    │
│  15 scripts in scripts/cron-*.sh                         │
│  Shared helpers: cron-alert.sh, file-lock.sh,            │
│                  enforcement-log.sh                      │
│  Registered in: setup-claude.sh crontab block            │
└──────────────────────┬──────────────────────────────────┘
                       │ manages
┌──────────────────────▼──────────────────────────────────┐
│              State Files                                 │
│  Persistent: FOLLOWUPS.md, STATE.md, HANDOFF.md,         │
│              IMPACT.md, ALERTS.md, project TASKS.md      │
│  Session:    /tmp/claude-preflight-${SID}/               │
│              /tmp/claude-prereq-${SID}/                   │
│  Cron:       ~/work/claude/state/heartbeats/, ~/logs/*.log │
│  Metrics:    ~/logs/enforcement-metrics.csv              │
└──────────────────────┬──────────────────────────────────┘
                       │ feeds
┌──────────────────────▼──────────────────────────────────┐
│              Commands (User Interface)                    │
│  17 commands in .claude/commands/my-*.md                  │
│  Key: /my-start, /my-save, /my-finish, /my-think         │
│  Session lifecycle: start → work → save → clear           │
└─────────────────────────────────────────────────────────┘
```

## Enforcement Flow

```
User/AI attempts action
    │
    ▼
PreToolUse hooks fire (synchronous, blocking)
    ├── enforce-prerequisites.sh
    │     ├── HARD BLOCK? (gdocs replace, get --text, etc.) → exit 1
    │     ├── CONDITIONAL BLOCK? (gdocs apply + comments) → exit 1
    │     └── PREREQUISITE CHECK? (cheatsheet read?) → exit 1
    ├── bash-guard.sh
    │     ├── background check (buck2) → exit 2
    │     ├── SSH cd check → exit 2
    │     └── preflight submit check (lint, pyre, self-review, stack) → exit 2
    │
    ▼ (if all pass)
Action executes
    │
    ▼
PostToolUse hooks fire (async, non-blocking)
    ├── track-preflight.sh → sets/clears sentinels, warns
    ├── gdocs-post-verify.sh → checks heading/comment/style
    ├── auto-prescreener.sh → attaches privacy context
    ├── auto-retry-transient.sh → retries DNS/timeout
    └── (all hooks call enforcement-log.sh for metrics)
    └── enforcement-log.sh → records metrics
```

## State Scoping

```
Session-scoped (isolated per Claude window):
  /tmp/claude-preflight-${SID_SHORT}/    ← lint, pyre, self-review sentinels
  /tmp/claude-prereq-${SID_SHORT}/       ← cheatsheet-read sentinels
  /tmp/.claude-turn-counter-${SID_SHORT} ← session turn count

Cron-scoped (shared fallback for autonomous sessions):
  /tmp/claude-preflight-cron/            ← cron preflight sentinels
  /tmp/claude-prereq-cron/              ← cron cheatsheet sentinels

Global (intentionally shared):
  ~/work/claude/state/heartbeats/*       ← cron health signals (git-ignored)
  /tmp/claude-file-locks/                ← atomic file locks
  ~/logs/enforcement-metrics.csv         ← enforcement audit trail
```

## Key Files Quick Reference

| Purpose | File |
|---------|------|
| Master rules | `CLAUDE.md` |
| Cheatsheet routing | `cheatsheets/CHEATSHEET-INDEX.md` |
| Hook config | `.claude/settings.json` |
| Session state | `context/cache/state/STATE.md` |
| Session handoff | `HANDOFF.md` |
| Follow-ups | `FOLLOWUPS.md` |
| Alerts | `ALERTS.md` |
| Impact log | `context/IMPACT.md` |
| Project registry | `projects/_registry.json` |
| Cron registration | `scripts/setup-claude.sh` |
| Enforcement log | `~/logs/enforcement-metrics.csv` |
| Workflow design rules | `cheatsheets/system/workflow-design.md` |
