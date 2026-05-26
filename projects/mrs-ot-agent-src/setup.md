# OT Agent Setup

Run these after a devserver reinstall to restore the OT agent environment.

## Claude Code Skills

```bash
claude-templates skill visualize install
```

## Claude Code Plugins

These are typically pre-installed via the system claude-templates package. Verify with:

```bash
claude-templates list --compact
```

Required plugins (install if missing):

```bash
claude-templates plugin source-control-at-meta install
claude-templates plugin infra install
```

## MyClaw ot-bot Instance

1. Create the instance:
   ```bash
   myclaw setup --instance ot-bot
   ```

2. Import from backup (if available):
   ```bash
   sudo MYCLAW_HOME=/home/dennyzhang/.myclaw-ot-bot myclaw import ~/ot-team-backup.tar.gz
   ```

3. Set the 1:1 space ID in `~/.myclaw-ot-bot/current` and `~/.myclaw-ot-bot/config.json` to the correct GChat space.

4. Set up cron jobs:
   ```bash
   bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/setup-cron-jobs.sh
   ```

## Notes Repo

```bash
sl clone fb:notes ~/notes
```

The notes repo is the canonical source for OT agent prompts, patterns, and cron job definitions. See `CLAUDE.md` in `users/dennyzhang/` for directory structure.
