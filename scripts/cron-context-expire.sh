#!/usr/bin/env bash
# cron-context-expire.sh — Daily TTL engine for personal context files.
#
# Rules: state/{ENERGY,MOOD,FOCUS}.md: 30d TTL | state/BLOCKERS.md: 60d TTL
#   patterns/DECISIONS.md: last 100 entries | patterns/COMMUNICATION.md: 180d TTL
#   patterns/{LEARNING,MEETINGS}.md: warn >90d stale | goals/*: warn >90d stale
#   identity/*: never expire
#
# Schedule: Daily 3 AM
# Crontab entry:
#   0 3 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 120 context-expire ~/work/claude/scripts/cron-context-expire.sh >> ~/logs/context-expire.log 2>&1

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CTX_DIR="$HOME/work/claude/context/personal-context"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY_EPOCH=$(date +%s)
source "$SCRIPT_DIR/cron-alert.sh"
echo "$LOG_PREFIX === Context Expiration Engine ==="
archived=0; warnings=0

# Archive entries older than TTL. Entry format: YYYY-MM-DD #tag text
# Preserves headers/comments. Moves expired entries to _archive/<filename>.
archive_old_entries() {
    local file="$1" ttl_days="$2"
    [ -f "$file" ] || return 0
    local dir; dir="$(dirname "$file")"
    local bname; bname="$(basename "$file")"
    local archive_dir="${dir}/_archive" archive_file="${dir}/_archive/${bname}"
    local tmp_keep; tmp_keep=$(mktemp)
    local tmp_archive; tmp_archive=$(mktemp)
    local count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]] ]]; then
            local entry_epoch; entry_epoch=$(date -d "${BASH_REMATCH[1]}" +%s 2>/dev/null || echo "0")
            if [ $(( (TODAY_EPOCH - entry_epoch) / 86400 )) -gt "$ttl_days" ]; then
                echo "$line" >> "$tmp_archive"; count=$((count + 1)); continue
            fi
        fi
        echo "$line" >> "$tmp_keep"
    done < "$file"
    if [ "$count" -gt 0 ]; then
        mkdir -p "$archive_dir"
        [ -f "$archive_file" ] && cat "$tmp_archive" >> "$archive_file" || cp "$tmp_archive" "$archive_file"
        cp "$tmp_keep" "$file"
        echo "$LOG_PREFIX   Archived $count entries from $bname (TTL: ${ttl_days}d)"
        archived=$((archived + count))
    fi
    rm -f "$tmp_keep" "$tmp_archive"
}

# Keep only the last N dated entries. Overflow goes to _archive/.
trim_to_count() {
    local file="$1" max="$2"
    [ -f "$file" ] || return 0
    local dir; dir="$(dirname "$file")"
    local bname; bname="$(basename "$file")"
    local archive_file="${dir}/_archive/${bname}"
    local tmp_h; tmp_h=$(mktemp)
    local tmp_e; tmp_e=$(mktemp)
    local in_entries=false
    while IFS= read -r line; do
        [[ "$line" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]] ]] && in_entries=true
        $in_entries && echo "$line" >> "$tmp_e" || echo "$line" >> "$tmp_h"
    done < "$file"
    local total; total=$(wc -l < "$tmp_e" 2>/dev/null || echo "0")
    if [ "$total" -gt "$max" ]; then
        local excess=$((total - max))
        mkdir -p "${dir}/_archive"
        head -n "$excess" "$tmp_e" >> "$archive_file"
        { cat "$tmp_h"; tail -n "$max" "$tmp_e"; } > "$file"
        echo "$LOG_PREFIX   Trimmed $excess oldest entries from $bname (cap: $max)"
        archived=$((archived + excess))
    fi
    rm -f "$tmp_h" "$tmp_e"
}

# Check file staleness (mtime). Warn if older than threshold.
check_stale() {
    local file="$1" label="$2" threshold_days="$3"
    [ -f "$file" ] || return 0
    local age=$(( (TODAY_EPOCH - $(stat -c %Y "$file" 2>/dev/null || echo "$TODAY_EPOCH")) / 86400 ))
    if [ "$age" -gt "$threshold_days" ]; then
        echo "$LOG_PREFIX   WARNING: $label not updated in ${age} days"
        warnings=$((warnings + 1))
    fi
}

# ─── 1. State files: TTL-based expiration ─────────────────────────────────────
echo "$LOG_PREFIX [1/4] State files — TTL expiration"
for f in ENERGY.md MOOD.md FOCUS.md; do archive_old_entries "$CTX_DIR/state/$f" 30; done
archive_old_entries "$CTX_DIR/state/BLOCKERS.md" 60

# ─── 2. Pattern files: rolling window + TTL ──────────────────────────────────
echo "$LOG_PREFIX [2/4] Pattern files — rolling window + TTL"
trim_to_count "$CTX_DIR/patterns/DECISIONS.md" 100
archive_old_entries "$CTX_DIR/patterns/COMMUNICATION.md" 180
check_stale "$CTX_DIR/patterns/LEARNING.md" "patterns/LEARNING.md" 90
check_stale "$CTX_DIR/patterns/MEETINGS.md" "patterns/MEETINGS.md" 90

# ─── 3. Goals: staleness warning ──────────────────────────────────────────────
echo "$LOG_PREFIX [3/4] Goals — staleness check (90-day warning)"
for f in "$CTX_DIR/goals"/*.md; do [ -f "$f" ] && check_stale "$f" "goals/$(basename "$f")" 90; done

# ─── 4. Identity: never expire ────────────────────────────────────────────────
echo "$LOG_PREFIX [4/4] Identity — never expire (skipped)"

# ─── Report ──────────────────────────────────────────────────────────────────
echo "$LOG_PREFIX Archived: $archived entries | Warnings: $warnings stale files"
if [ "$warnings" -gt 0 ]; then
    cron_alert "context-expire" "$warnings context files need review (>90 days stale)"
else
    cron_alert_clear "context-expire"
fi
write_heartbeat "context-expire"
echo "$LOG_PREFIX === Context Expiration Done ==="

# ─── Memory file pruning ─────────────────────────────────────────────────────
# Prune memory files that are redundant (already in CLAUDE.md or cheatsheets)
# or stale (project/reference type older than TTL).
MEMORY_DIR="$HOME/work/claude/memory"
if [ -d "$MEMORY_DIR" ]; then
    pruned=0
    for f in "$MEMORY_DIR"/*.md; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "MEMORY.md" ] && continue  # skip index
        
        # Check type and age
        mem_type=$(grep "^type:" "$f" 2>/dev/null | head -1 | awk '{print $2}' || true)
        file_age_days=$(( ($(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0)) / 86400 ))
        
        # TTL by type
        case "$mem_type" in
            project)  [ "$file_age_days" -gt 90 ] && rm "$f" && pruned=$((pruned+1)) && echo "Pruned (project >90d): $(basename "$f")" ;;
            reference) [ "$file_age_days" -gt 180 ] && rm "$f" && pruned=$((pruned+1)) && echo "Pruned (reference >180d): $(basename "$f")" ;;
        esac
    done
    [ "$pruned" -gt 0 ] && echo "$(date '+%Y-%m-%d %H:%M') Pruned $pruned stale memory files"
fi

# ─── Memory redundancy check ─────────────────────────────────────────────────
# Feedback memories that are ALSO in CLAUDE.md as hard rules are redundant.
# The CLAUDE.md rule is loaded every session; the memory is dead weight.
CLAUDE_MD="$HOME/work/claude/CLAUDE.md"
if [ -d "$MEMORY_DIR" ] && [ -f "$CLAUDE_MD" ]; then
    redundant=0
    for f in "$MEMORY_DIR"/feedback_*.md; do
        [ -f "$f" ] || continue
        # Extract the key phrase from the memory name
        key=$(grep "^name:" "$f" 2>/dev/null | head -1 | sed 's/^name: //' || true)
        [ -z "$key" ] && continue
        # Check if this concept exists in CLAUDE.md (fuzzy match on key words)
        key_words=$(echo "$key" | tr '-' ' ' | tr '_' ' ')
        match_count=0
        for word in $key_words; do
            [ ${#word} -lt 4 ] && continue  # skip short words
            grep -qi "$word" "$CLAUDE_MD" 2>/dev/null && match_count=$((match_count+1))
        done
        total_words=$(echo "$key_words" | wc -w)
        # If >60% of key words found in CLAUDE.md, the memory is redundant
        if [ "$total_words" -gt 0 ] && [ "$match_count" -gt 0 ]; then
            pct=$((match_count * 100 / total_words))
            if [ "$pct" -ge 60 ]; then
                echo "Redundant memory (${pct}% overlap with CLAUDE.md): $(basename "$f")"
                redundant=$((redundant+1))
                # Don't auto-delete — just report. User decides.
            fi
        fi
    done
    [ "$redundant" -gt 0 ] && echo "$(date '+%Y-%m-%d %H:%M') $redundant redundant memories found — consider removing"
fi
