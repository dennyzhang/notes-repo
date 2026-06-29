# MyClaw Operational Cheatsheet

Known issues, diagnostics, and fixes for running MyClaw instances.

## Known Bug: Worktree Leak Fills Disk

**Symptom:** Disk usage hits 99-100% on a 2TB devserver. `df -h` shows `/` full.

**Root cause:** Claude Code's `isolation: "worktree"` agent spawns create `/tmp/.tmp*` directories (~54GB each, full repo clone). These are supposed to be cleaned up after the agent finishes, but cleanup is unreliable. A busy MyClaw instance (especially one running cron jobs with subagents) can accumulate thousands of orphaned worktrees in hours.

**Diagnosis:**
```bash
# Confirm /tmp is the culprit
du -x --max-depth=1 / 2>/dev/null | sort -rn | head -10

# Count orphaned worktrees
ls -d /tmp/.tmp* 2>/dev/null | wc -l

# Check total size
du -sh /tmp/.tmp* 2>/dev/null | sort -rh | head -10

# Peek inside one (looks like a home-dir clone with .claude, .config, etc.)
ls -la /tmp/.tmpXXXXXX/
```

**Fix (immediate):**
```bash
# Remove worktrees older than 1 hour (safe — active agents are recent)
find /tmp -maxdepth 1 -name '.tmp*' -mmin +60 -type d -exec rm -rf {} +

# Nuclear option — remove all (only if no active agent sessions)
rm -rf /tmp/.tmp*
```

**Prevention:** No upstream fix yet (as of 2026-06). Mitigations:
- Avoid `isolation: "worktree"` in agent spawns when not strictly needed
- Add a periodic cleanup cron on the devserver:
  ```bash
  # crontab -e — clean orphaned worktrees every 2 hours
  0 */2 * * * find /tmp -maxdepth 1 -name '.tmp*' -mmin +120 -type d -exec rm -rf {} + 2>/dev/null
  ```
- Monitor disk with `df -h /` in daily health checks

**Incident history:**
| Date | Count | Disk impact | Notes |
|------|-------|-------------|-------|
| 2026-06-02 | 2,355 dirs | 2.3TB (99%) | Mix of dennyzhang + root owned; accumulated over ~24h |

## Disk Usage Quick Check

When a devserver feels slow or commands fail with ENOSPC:
```bash
# Overall
df -h /

# Top-level breakdown (stays on same filesystem)
du -x --max-depth=1 / 2>/dev/null | sort -rn | head -10

# Claude-specific
du -sh ~/.claude /tmp/claude-* /tmp/.tmp* 2>/dev/null | sort -rh | head -10

# Count worktree dirs
ls -d /tmp/.tmp* 2>/dev/null | wc -l
```

## Instance Management Quick Reference

```bash
# List all instances
myclaw instances

# Stop (graceful — never kill PID directly, supervisor respawns)
myclaw stop --instance <name>

# Restart
myclaw restart --instance <name>

# Logs (follow)
myclaw logs --instance <name> -f

# Destroy (see myclaw-delete.md for full procedure)
myclaw destroy <name>
```

## CLAUDE.md Authoring — Formatting Rules That Affect Enforcement

Claude enforces rules based on formatting, not just content. Improperly formatted rules are ignored or treated as prose.

**Three rules (from Chris Davies, 2026-06-17):**

1. **Use `-` dashes, never `•` bullets.** Bullet-formatted lists are ignored. Only dash lists are parsed as directives.

2. **Bold all declaratives.** `ALWAYS`, `NEVER`, `MUST`, `HARD` — they must be `**ALWAYS**`, `**NEVER**`, `**MUST**`, `(**HARD**)`. Plain caps are treated as prose emphasis, not enforcement markers.

3. **Put a `## IMPORTANT` block at the top (before all other sections).** This is where the highest-priority, most-violated rules live. Claude reads top-to-bottom; important rules buried at line 500 lose to early context.

```markdown
## IMPORTANT

- **ALWAYS** continue work until the task is fully complete. Do **NOT** stop to ask for confirmation on reversible actions.
- **NEVER** confirmation-bait the operator. Act when confident; only stop for irreversible or external-surface mutations.
```

**Diagnostic:** If Claude is repeatedly ignoring a rule, run `/insights-to-px` against the CLAUDE.md — it can surface formatting issues. Or ask Claude to analyze the file for formatting problems.

**Blast radius:** A badly formatted CLAUDE.md causes "undefined behavior" (Chris's words) — rules that look present to human readers are invisible to the model.

## Key Paths

| Path | Purpose |
|------|---------|
| `~/.myclaw-<name>/` | Instance home dir |
| `~/.myclaw-registry.json` | Instance registry |
| `/tmp/.tmp*` | Worktree agent clones (leak-prone) |
| `/tmp/claude-<user>/` | Claude Code session temp files |
| `~/.claude/projects/` | Session transcripts + tool results |

_Last updated: 2026-06-03. Maintainer: dennyzhang._
