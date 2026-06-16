#!/usr/bin/env bash
# cron-disk-cleanup.sh — Disk cleanup + MyClaw auto-healing (every 15 min).
#
# 1. Purge stale MyClaw/Claude .tmp* session dirs from /tmp
# 2. Auto-restart dead MyClaw instances
#
# Crontab:
#   */15 * * * * source ~/work/claude/scripts/cron-alert.sh && \
#     cron_run 300 disk-cleanup ~/work/claude/scripts/cron-disk-cleanup.sh \
#     >> ~/logs/disk-cleanup.log 2>&1

set -e
source "$(dirname "$0")/cron-alert.sh"

MAX_AGE_MINUTES=10

before_usage=$(df / --output=pcent | tail -1 | tr -d ' %')
cron_log "Disk usage before cleanup: ${before_usage}%"

cleaned=0

# 0a. ALWAYS FIRST: delete oversized history.jsonl files inside abandoned sandbox
#     HOMEs (/tmp/.tmp*/.claude/history.jsonl). A buggy Claude session can write a
#     50-60GB history.jsonl into its temp HOME. These are the real space hogs, and —
#     critically — they make `rm -rf` of the enclosing dir SLOW (CoW reflink extent
#     unlinking). VERIFIED 2026-06-13: with big files present, the step-1 dir sweep
#     timed out at 300s (exit=124) on EVERY run for 12 days (heartbeat stuck at
#     Jun 1), so the backlog grew to 2298 dirs and filled the disk to 100%. The
#     moment these files were purged, the same sweep finished in seconds. So this
#     runs UNCONDITIONALLY (not gated on disk%) — a fast `-delete` of the few huge
#     files is what keeps the whole cron under its 300s budget. Deleting the file
#     leaves an empty dir that step 1 removes cheaply.
big_count=$(find /tmp -maxdepth 3 -path '/tmp/.tmp*/.claude/history.jsonl' \
    -type f -size +500M 2>/dev/null | wc -l)
if [ "$big_count" -gt 0 ]; then
    cron_log "Purging $big_count oversized sandbox history.jsonl files (>500MB) FIRST"
    find /tmp -maxdepth 3 -path '/tmp/.tmp*/.claude/history.jsonl' \
        -type f -size +500M -delete 2>/dev/null || true
    cleaned=$((cleaned + big_count))
fi

# 0b. EMERGENCY: when disk is still critical (>88%), drop the age gate and remove
#     ALL .tmp* dirs (skeletons are empty/small now that 0a freed the big files).
if [ "${before_usage:-0}" -gt 88 ]; then
    emer_count=$(find /tmp -maxdepth 1 -name '.tmp*' -type d 2>/dev/null | wc -l)
    if [ "$emer_count" -gt 0 ]; then
        cron_log "EMERGENCY (disk ${before_usage}%): removing $emer_count .tmp* dirs (age gate dropped)"
        find /tmp -maxdepth 1 -name '.tmp*' -type d \
            -exec rm -rf {} + 2>/dev/null || true
        cleaned=$((cleaned + emer_count))
    fi
fi

# 1. Stale .tmp* session dirs (MyClaw/Claude Code)
tmp_count=$(find /tmp -maxdepth 1 -name '.tmp*' \
    -type d -mmin +"$MAX_AGE_MINUTES" 2>/dev/null | wc -l)
if [ "$tmp_count" -gt 0 ]; then
    cron_log "Cleaning $tmp_count stale .tmp* dirs (>${MAX_AGE_MINUTES}min old)"
    find /tmp -maxdepth 1 -name '.tmp*' \
        -type d -mmin +"$MAX_AGE_MINUTES" \
        -exec rm -rf {} + 2>/dev/null || true
    cleaned=$((cleaned + tmp_count))
fi

# 2. PAR unpack caches (>2h old)
par_count=$(find /tmp -maxdepth 1 -name 'par_unpack.*' \
    -type d -mmin +120 2>/dev/null | wc -l)
if [ "$par_count" -gt 0 ]; then
    cron_log "Cleaning $par_count stale PAR unpack dirs"
    find /tmp -maxdepth 1 -name 'par_unpack.*' \
        -type d -mmin +120 \
        -exec rm -rf {} + 2>/dev/null || true
    cleaned=$((cleaned + par_count))
fi

# 3. Confucius CLI cache (>500MB)
if [ -d /tmp/confucius_cli_cache ] && \
   [ "$(du -sm /tmp/confucius_cli_cache 2>/dev/null | cut -f1 || echo 0)" -gt 500 ]; then
    cron_log "Cleaning confucius CLI cache (>500MB)"
    rm -rf /tmp/confucius_cli_cache 2>/dev/null || true
    cleaned=$((cleaned + 1))
fi

# 4. Old claude session dirs (>24h)
claude_count=$(find /tmp -maxdepth 2 -name 'claude-*' \
    -type d -mmin +1440 2>/dev/null | wc -l)
if [ "$claude_count" -gt 0 ]; then
    cron_log "Cleaning $claude_count old claude session dirs"
    find /tmp -maxdepth 2 -name 'claude-*' \
        -type d -mmin +1440 \
        -exec rm -rf {} + 2>/dev/null || true
    cleaned=$((cleaned + claude_count))
fi

after_usage=$(df / --output=pcent | tail -1 | tr -d ' %')
cron_log "Disk usage after: ${after_usage}% (cleaned $cleaned items)"

if [ "$after_usage" -gt 85 ]; then
    cron_alert "disk-cleanup" \
        "Disk still at ${after_usage}% after cleanup. Manual intervention needed."
fi

# 5. MyClaw auto-healing — restart dead instances
MYCLAW_FAIL_DIR="$CLAUDE_STATE_DIR/myclaw-fails"
mkdir -p "$MYCLAW_FAIL_DIR" 2>/dev/null
for instance_dir in "$HOME"/.myclaw-*/; do
    [ -d "$instance_dir" ] || continue
    instance=$(basename "$instance_dir" | sed 's/^\.myclaw-//')
    status_out=$(MYCLAW_HOME="$instance_dir" myclaw status 2>&1) || true
    if echo "$status_out" | grep -q "Not running"; then
        fail_file="$MYCLAW_FAIL_DIR/$instance"
        fails=$(cat "$fail_file" 2>/dev/null || echo 0)
        cron_log "MyClaw '$instance' is DOWN (fail count: $fails) — restarting"
        if MYCLAW_HOME="$instance_dir" myclaw start 2>&1; then
            sleep 5
            verify=$(MYCLAW_HOME="$instance_dir" myclaw status 2>&1) || true
            if echo "$verify" | grep -q "Running"; then
                cron_log "MyClaw '$instance' restarted successfully"
                echo 0 > "$fail_file"
            else
                fails=$((fails + 1))
                echo "$fails" > "$fail_file"
                cron_log "MyClaw '$instance' restart FAILED (attempt $fails)"
            fi
        else
            fails=$((fails + 1))
            echo "$fails" > "$fail_file"
            cron_log "MyClaw '$instance' start command failed (attempt $fails)"
        fi
        if [ "$fails" -ge 3 ]; then
            cron_alert "disk-cleanup" \
                "MyClaw '$instance' DOWN — $fails consecutive restart attempts failed"
        fi
    else
        echo 0 > "$MYCLAW_FAIL_DIR/$instance" 2>/dev/null
    fi
done

write_heartbeat "disk-cleanup"
