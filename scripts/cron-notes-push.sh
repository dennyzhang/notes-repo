#!/usr/bin/env bash
# cron-notes-push.sh — Daily push of ~/notes (the Mononoke notes repo) to master.
#
# Why: the notes repo is the canonical home for AI agent context, plans, and personal
# documentation. Local edits accumulate throughout the day; a nightly push keeps master
# fresh and ensures cross-host visibility (work, life, work-fun, ot-team instances all
# read from notes-on-master, not from this devvm's local working copy).
#
# Repo conventions (per ~/notes/CLAUDE.md):
#   - Push directly: `sl push --to master`. NO `jf submit` (no Phabricator workflow).
#   - Files must live under users/<unixname>/ or shared/<project>/.
#   - Commit hook enforces ownership on push.
#
# Crontab entry (in setup-claude.sh): runs daily at 00:00 PT.
#   0 0 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 600 \
#       notes-push ~/work/claude/scripts/cron-notes-push.sh \
#       >> ~/logs/notes-push.log 2>&1
#
# Idempotent: no-op if nothing to commit; safe to manually re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTES_DIR="$HOME/notes"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
HOSTNAME_SHORT="$(hostname -s)"
TODAY_STAMP="$(date '+%Y-%m-%d_%H%M')"

source "$SCRIPT_DIR/cron-alert.sh"

if [ ! -d "$NOTES_DIR" ]; then
    cron_alert "notes-push" "Notes repo missing at $NOTES_DIR — clone it first or update NOTES_DIR"
    exit 1
fi

cd "$NOTES_DIR"

# Pre-check: are we actually in the notes repo (Mononoke, not git/local)?
if ! sl --reason "verify notes is sl repo - sl help root" root >/dev/null 2>&1; then
    cron_alert "notes-push" "Notes repo at $NOTES_DIR is not a sapling repo"
    exit 1
fi

# Corruption guard: a null-commit parent means the Eden checkout is broken
# (interrupted update). `commit -A` here would try to add the ENTIRE repo
# (~875k files — the 2026-06-13 incident). Refuse and point at the recovery.
parent=$(sl --reason "check wc parent - sl help log" log -r . -T '{node|short}\n' 2>/dev/null | head -1)
if [ -z "$parent" ] || [ "$parent" = "000000000000" ]; then
    cron_alert "notes-push" "Working copy parent is null/empty ('$parent') — broken checkout. Recover with: cd ~/notes && sl goto remote/master --clean"
    exit 1
fi

# Step 1: stage all changes (-A handles untracked + tracked).
status_out=$(sl --reason "list uncommitted notes changes - sl help status" status 2>&1 || true)
if [ -z "$status_out" ]; then
    echo "$LOG_PREFIX [notes-push] No local changes — nothing to commit."
else
    # Sanity cap: hundreds of dirty files is corruption, not real edits — never
    # auto-commit that. Caught the null-parent case above would miss; this is defense in depth.
    dirty_count=$(printf '%s\n' "$status_out" | grep -c . || true)
    if [ "$dirty_count" -gt 300 ]; then
        cron_alert "notes-push" "Abnormal dirty count ($dirty_count > 300) — likely corruption, refusing to commit. Inspect: cd ~/notes && sl status | head"
        exit 1
    fi
    # deny_files landmine: editor backups / temp files are rejected at push time
    # and would block the whole commit (per notes-repo-operations.md cheatsheet).
    deny_hits=$(printf '%s\n' "$status_out" | grep -iE '\.(bak|tmp|temp|swp|swo|orig|rej|pyc|pyo)$' || true)
    if [ -n "$deny_hits" ]; then
        cron_alert "notes-push" "Refusing to commit deny_files-blocked files: $(echo "$deny_hits" | tr '\n' ' ')"
        exit 1
    fi
    echo "$LOG_PREFIX [notes-push] Committing local changes:"
    echo "$status_out" | sed 's/^/    /'
    if ! sl --reason "commit nightly notes sync - sl help commit" commit -A -m "auto: notes sync ${TODAY_STAMP} [${HOSTNAME_SHORT}]" 2>&1; then
        cron_alert "notes-push" "sl commit failed in $NOTES_DIR (see ~/logs/notes-push.log)"
        exit 1
    fi
fi

# Step 2: pull rebase (avoid push conflicts when other hosts pushed since last run).
if ! sl --reason "pull rebase before push - sl help pull" pull --rebase 2>&1 | tail -5; then
    cron_alert "notes-push" "sl pull --rebase failed in $NOTES_DIR — manual conflict resolution needed"
    exit 1
fi

# Step 3: push to master (notes repo convention; no Phabricator).
push_out=$(sl --reason "nightly push notes to master - sl help push" push --to master 2>&1 || true)
if echo "$push_out" | grep -qiE "error|failed|abort"; then
    cron_alert "notes-push" "sl push --to master failed: $(echo "$push_out" | tail -3 | tr '\n' ' | ')"
    exit 1
fi
echo "$LOG_PREFIX [notes-push] $push_out" | tail -5

# Heartbeat — canonical helper (per workflow-design.md rule 2)
write_heartbeat "notes-push"
echo "$LOG_PREFIX [notes-push] done"
