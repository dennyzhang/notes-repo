# Devserver Setup

After a fresh devserver reinstall, run these steps to restore cron jobs.

## Cron Jobs

```bash
crontab -e
```

Add these lines:

```
0 */4 * * * /data/users/dennyzhang/notes/users/dennyzhang/scripts/disk-cleanup.sh >> ~/disk-cleanup.log 2>&1
0 */4 * * * /data/users/dennyzhang/notes/users/dennyzhang/scripts/push-notes.sh >> ~/push-notes.log 2>&1
```

| Script | Schedule | What it does |
|--------|----------|--------------|
| `disk-cleanup.sh` | Every 4 hours | Clears Claude Code worktrees, CAS cache, PAR unpack, logs, core dumps |
| `push-notes.sh` | Every 4 hours | Auto-commits and pushes pending notes repo changes to master |
