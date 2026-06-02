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

## Writing & Hardening Guard Hooks

Lessons from building the diff-cheatsheet + submit guards (2026-05-30, thread `Q_8ELeVd7cU`). Apply when adding ANY PreToolUse guard.

- **Enforce at the tool layer, not in prose.** A rule written into CLAUDE.md / a cheatsheet / a cron prompt gets skipped under task focus — proven repeatedly (a cron shipped D106859537 with no diff-cheatsheet review because the mandate lived only in the interactive agent's prompt). If a rule MUST hold, it needs a PreToolUse hook. When you catch a rule being skipped, the fix is a hook, not another reminder.
- **Attack your own guard before trusting it.** A guard that "works" on the happy path usually has bypasses. Two failure classes to probe every time:
  - **OR-bypass / shared escape tokens.** If gate A accepts gate B's escape token, B's token silently disables A. (The diff-cheatsheet gate originally accepted `# ot-weekly-sync-submit-ok` → every weekly submit skipped the cheatsheet. Removed: each gate owns its own token; a command must satisfy *all* applicable gates independently.)
  - **Substring matching cuts both ways.** A `case "$cmd" in *"jf submit"*)` matcher has (a) **false-positives** — read-only commands that merely *mention* the string (`sqlite3 ... LIKE '%jf submit%'`, `grep 'jf submit'`) get blocked; and (b) **false-negatives / evasions** — an exemption like `*"grep "*) : ;;` means a normal pipe `jf submit | grep ...` skips the gate entirely. Both have the same root: substring match can't tell *executes X* from *mentions X*.
- **Distinguish execute-vs-mention with a first-word check.** Skip when the command's program is a known read tool, gate everything else: `prog=${cmd%% *}; case "$prog" in sqlite3|grep|rg|cat|head|tail|echo|jq|less|printf) exit 0 ;; esac`. This allows inspection commands and still catches `cd && jf submit`, `timeout … jf submit`, and `jf submit | grep`. Do NOT skip code-exec first-words (`python`, `bash`, `awk`, `sed`) — they can run the gated action.
- **Self-attested tokens are gameable; pair them with a detective control.** A token like `# diff-cheatsheet-ok` asserts "I ran the review" but a synchronous hook cannot verify a *subjective* review actually happened — the agent can append the token without doing the work. Hooks reliably enforce only *objective* checks. For the subjective part, add a post-hoc audit (a cron that pulls recently-created diffs and re-checks them) — trust-but-verify, not trust.
- **Guards are reinstall-critical: make them idempotent + test them.** Generate live `settings.json` from a single installer (`team_bot/scripts/apply-space-hooks.sh`, idempotent via a `_detect` substring) so a reinstall reproduces the exact guard. After any change, run a simulation matrix (`echo '{"tool_input":{"command":"…"}}' | bash -c "$hookcmd"`, assert exit codes) covering each bypass class above, PLUS edge inputs (`{}`, permissions-only-no-hooks, partial install) before declaring done.
- **The installer must be `.sh`, not `.py` — so it can live in notes and ride the weekly notes→fbcode sync to trunk.** `.py` is deny_files-blocked on notes-master, so a `.py` installer strands off the durability pipeline and needs a manual fbcode land (it sat un-landed for hours). Rewrote it to bash+`jq` (2026-05-30, `Q_8ELeVd7cU`); it now lives in `team_bot/scripts/`. **General rule: any notes-resident helper script is `.sh` (do JSON via `jq`).** When porting `.py`→`.sh`: (a) a missing tool (`jq`) must fail VISIBLY (exit non-zero so bootstrap's `|| WARNING` fires) — never `exit 0`, which silently skips hook install; (b) confirm the sync `mkdir -p`s new subdirs before relying on a new folder mirroring; (c) re-run the full sim + edge matrix from the new path.
- **Strip free-text flag arguments before matching.** `$cmd` includes all flag values (e.g. `--text '...'`, `--message '...'`). A substring match on `$cmd` can false-positive when the *message body* contains a trigger word. Before any `*"jf submit"*` check, strip the text tail: `cmd_nc="${cmd%%--text *}"; cmd_nc="${cmd_nc%%--text=*}"; cmd_nc="${cmd_nc%%--message *}"` then match `$cmd_nc`. Tokens (`# diff-cheatsheet-ok`) also go on `$cmd_nc` — they're appended to the command, not inside `--text`. (2026-05-30 21:18, thread `Q_8ELeVd7cU`.)

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
