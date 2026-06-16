#!/usr/bin/env bash
# cron-context-gc.sh — Weekly context garbage collection.
#
# Auto-archives stale profiles, prunes old cron outputs, enforces size caps.
# Prevents context layer bloat that degrades session quality.
#
# Schedule: Weekly Sunday 7 PM via crontab
# Crontab entry:
#   0 19 * * 0 source ~/work/claude/scripts/cron-alert.sh && cron_run 300 context-gc ~/work/claude/scripts/cron-context-gc.sh >> ~/logs/context-gc.log 2>&1

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
BACKUP_DIR="$REPO_DIR/backup/gc-$(date '+%Y-%m-%d')"

source "$SCRIPT_DIR/cron-alert.sh"

echo "$LOG_PREFIX === Context Garbage Collection ==="

archived=0
pruned=0
warnings=0

# ─── 1. Archive stale people profiles (>30 days) ────────────────────────────
echo "$LOG_PREFIX [1/4] Stale people profiles (>30 days)"
PEOPLE_DIR="$REPO_DIR/context/people"
if [ -d "$PEOPLE_DIR" ]; then
    while IFS= read -r profile; do
        [ -z "$profile" ] && continue
        basename=$(basename "$profile")
        [[ "$basename" == "README.md" || "$basename" == "TEMPLATE.md" || "$basename" == "IC7-WATCHLIST.md" || "$basename" == "REGISTRY.yaml" ]] && continue
        mkdir -p "$BACKUP_DIR/people"
        cp "$profile" "$BACKUP_DIR/people/$basename"
        echo "$LOG_PREFIX   Archived: $basename (>30 days stale)"
        archived=$((archived + 1))
    done < <(find "$PEOPLE_DIR" -name "*.md" -mtime +30 2>/dev/null)
fi

# ─── 2. Prune old cron cache outputs (>7 days) ──────────────────────────────
echo "$LOG_PREFIX [2/4] Stale cron cache outputs (>7 days)"
CACHE_DIR="$REPO_DIR/context/cache"
if [ -d "$CACHE_DIR" ]; then
    # Only prune known generated outputs, not state files
    for output in DIFF-REVIEW.md SIGNAL-ACTIONS.md MEETING-PREP-TODAY.md UPSTREAM-TODAY.md CLAUDE-SKILL-SCOUT.md VOICE-IDEAS.md VOICE-INBOX-LAST.md VOICE-INBOX-SUMMARY.md; do
        file="$CACHE_DIR/$output"
        if [ -f "$file" ]; then
            file_age=$(( ($(date +%s) - $(stat -c %Y "$file" 2>/dev/null || echo "$(date +%s)")) / 86400 ))
            if [ "$file_age" -gt 7 ]; then
                mkdir -p "$BACKUP_DIR/cache"
                mv "$file" "$BACKUP_DIR/cache/$output"
                echo "$LOG_PREFIX   Pruned: $output (${file_age} days old)"
                pruned=$((pruned + 1))
            fi
        fi
    done
fi

# ─── 3. Enforce cheatsheet size caps (500 lines) ────────────────────────────
echo "$LOG_PREFIX [3/4] Cheatsheet size caps (>500 lines)"
while IFS= read -r cs; do
    [ -z "$cs" ] && continue
    lines=$(wc -l < "$cs")
    if [ "$lines" -gt 500 ]; then
        echo "$LOG_PREFIX   WARNING: $(basename $cs) is $lines lines (cap: 500)"
        warnings=$((warnings + 1))
    fi
done < <(find "$REPO_DIR/cheatsheets" -name "*.md" 2>/dev/null)

# ─── 4. Prune old log files (>30 days) ──────────────────────────────────────
echo "$LOG_PREFIX [4/4] Old log files (>30 days)"
if [ -d "$HOME/logs" ]; then
    old_logs=$(find "$HOME/logs" -name "*.log" -mtime +30 2>/dev/null | wc -l)
    if [ "$old_logs" -gt 0 ]; then
        mkdir -p "$BACKUP_DIR/logs"
        find "$HOME/logs" -name "*.log" -mtime +30 -exec mv {} "$BACKUP_DIR/logs/" \; 2>/dev/null
        echo "$LOG_PREFIX   Moved $old_logs old log files to backup"
        pruned=$((pruned + old_logs))
    fi
fi

# ─── Trim cron-runtime.csv to last 90 days ──────────────────────────────────
RUNTIME_CSV="$HOME/logs/cron-runtime.csv"
if [ -f "$RUNTIME_CSV" ]; then
    before=$(wc -l < "$RUNTIME_CSV")
    cutoff=$(date -d "-90 days" '+%Y-%m-%d' 2>/dev/null || date -v-90d '+%Y-%m-%d' 2>/dev/null || echo "")
    if [ -n "$cutoff" ]; then
        tmp=$(mktemp)
        head -1 "$RUNTIME_CSV" > "$tmp"
        tail -n +2 "$RUNTIME_CSV" | awk -F, -v cutoff="$cutoff" '$1 >= cutoff' >> "$tmp"
        mv "$tmp" "$RUNTIME_CSV"
        after=$(wc -l < "$RUNTIME_CSV")
        trimmed=$((before - after))
        if [ "$trimmed" -gt 0 ]; then
            echo "$LOG_PREFIX   Trimmed $trimmed old rows from cron-runtime.csv"
            pruned=$((pruned + trimmed))
        fi
    fi
fi

# ─── Trim autolearn-metrics.csv to last 90 days ──────────────────────────────
AUTOLEARN_CSV="$REPO_DIR/state/autolearn-metrics.csv"
if [ -f "$AUTOLEARN_CSV" ]; then
    before=$(wc -l < "$AUTOLEARN_CSV")
    cutoff=$(date -d "-90 days" '+%Y-%m-%d' 2>/dev/null || date -v-90d '+%Y-%m-%d' 2>/dev/null || echo "")
    if [ -n "$cutoff" ]; then
        tmp=$(mktemp)
        awk -F, -v cutoff="$cutoff" '$1 >= cutoff' "$AUTOLEARN_CSV" > "$tmp"
        mv "$tmp" "$AUTOLEARN_CSV"
        after=$(wc -l < "$AUTOLEARN_CSV")
        trimmed=$((before - after))
        if [ "$trimmed" -gt 0 ]; then
            echo "$LOG_PREFIX   Trimmed $trimmed old rows from autolearn-metrics.csv"
            pruned=$((pruned + trimmed))
        fi
    fi
fi

# ─── Report ──────────────────────────────────────────────────────────────────
echo "$LOG_PREFIX Archived: $archived profiles | Pruned: $pruned files/rows | Warnings: $warnings oversized cheatsheets"

if [ "$warnings" -gt 0 ]; then
    cron_alert "context-gc" "$warnings cheatsheets exceed 500-line cap — split to references/"
else
    cron_alert_clear "context-gc"
fi

write_heartbeat "context-gc"
echo "$LOG_PREFIX === Context GC Done ==="
