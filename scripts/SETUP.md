# Devserver Setup

After a fresh devserver reinstall, run these steps to restore cron jobs.

> **Why this lives here:** the notes repo survives devserver reinstalls; local dirs
> (`~/.myclaw-ot-bot/`, `~/.claude/`) are wiped. Critical scripts/hooks/configs go here.

## Layout

| Dir | Contents |
|-----|----------|
| `hooks/` | PreToolUse hooks. `gdocs-comment-guard-hook.sh` (blocks `gdocs apply`/`replace`/`deleteContentRange` on commented docs), `sl-summary-lint-hook.sh`. Wired into space `settings.json` + reinstalled by `apply-space-hooks.py`. |
| `cron/` | Crontab scripts: `disk-cleanup.sh`, `push-notes.sh` (paths below), `cheatsheet-sweep.sh`, `cheatsheet-harvest.sh`, `install-cheatsheet-flywheel.sh`. |
| `lint/` | `lint-diff-summary.sh` (diff-summary linter), `lint-cheatsheets.sh` (cheatsheet structural health-check). |
| `learnings/` | `auto-save-learnings.md`. |
| `SETUP.md` | This index. |

## Cron Jobs

```bash
crontab -e
```

Add these lines:

```
0 */4 * * * /data/users/dennyzhang/notes/users/dennyzhang/scripts/cron/disk-cleanup.sh >> ~/disk-cleanup.log 2>&1
0 */4 * * * /data/users/dennyzhang/notes/users/dennyzhang/scripts/cron/push-notes.sh >> ~/push-notes.log 2>&1
```

| Script | Schedule | What it does |
|--------|----------|--------------|
| `disk-cleanup.sh` | Every 4 hours | Clears Claude Code worktrees, CAS cache, PAR unpack, logs, core dumps |
| `push-notes.sh` | Every 4 hours | Auto-commits and pushes pending notes repo changes to master |

## Cheatsheet flywheel (one-command restore)

The cheatsheet flywheel's scripts survive reinstall (notes repo); its LOCAL
activation (crontab + the sapling pretxncommit commit-gate) does not. Restore
both with the idempotent installer instead of hand-editing crontab:

```bash
bash ~/notes/users/dennyzhang/scripts/cron/install-cheatsheet-flywheel.sh
```

| Re-wires | What |
|----------|------|
| crontab | `cheatsheet-sweep.sh` (daily 07:30) + `cheatsheet-harvest.sh` (weekly Mon 08:00) |
| `~/.config/sapling/sapling.conf` | `pretxncommit.cheatsheet-lint` commit-gate → `hooks/cheatsheet-lint-hook.sh` |

Spec: `cheatsheets/agents/cheatsheet-flywheel.md`.
