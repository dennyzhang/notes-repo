#!/usr/bin/env bash
# cron-knowledge-distiller.sh — Weekly LLM-powered knowledge base compression.
#
# Complements cron-context-gc.sh (mechanical cleanup) with intelligent operations:
#   - Token budget tracking per category
#   - LLM-powered distillation of bloated files
#   - Cross-file redundancy detection
#   - Staleness reporting for non-archived cache files
#
# Philosophy (Karpathy's LLM Knowledge Base): Quality > quantity.
# A well-distilled 50K-token library beats a sprawling 360K-token dump.
#
# Schedule: Weekly Sunday 9 PM (after GC at 7 PM)
# Crontab entry:
#   0 21 * * 0 source ~/work/claude/scripts/cron-alert.sh && cron_run 600 knowledge-distiller ~/work/claude/scripts/cron-knowledge-distiller.sh >> ~/logs/knowledge-distiller.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
CTX_DIR="$REPO_DIR/context"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
REPORT="$CTX_DIR/cache/DISTILL-REPORT.md"
MAX_DISTILL=3  # max files to LLM-distill per run (API cost control)

# Clear Claude Code session markers so nested claude -p works
unset CLAUDECODE CLAUDE_CODE_CURRENT_SESSION_ID 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"

echo "$LOG_PREFIX === Knowledge Distiller ==="

# ─── Phase 1: Token Audit ─────────────────────────────────────────────────────
# Count tokens (bytes/4 approximation) per category
echo "$LOG_PREFIX [1/4] Token audit"

trap 'echo "$LOG_PREFIX [FATAL] Failed at line $LINENO (exit=$?)" >&2' ERR

count_tokens() {
    local dir="$1" pattern="${2:-*.md}"
    if [ ! -d "$dir" ]; then echo "0"; return 0; fi
    { find "$dir" -maxdepth 1 -name "$pattern" -exec cat {} + 2>/dev/null || true; } | wc -c | awk '{printf "%.0f", $1/4}'
}

count_tokens_recursive() {
    local dir="$1"
    if [ ! -d "$dir" ]; then echo "0"; return 0; fi
    { find "$dir" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.json" -o -name "*.txt" \) -exec cat {} + 2>/dev/null || true; } | wc -c | awk '{printf "%.0f", $1/4}'
}

# Category budgets (tokens)
declare -A BUDGETS=(
    [root]=20000
    [myself]=30000
    [cache]=60000
    [people]=40000
    [personal]=15000
    [psc]=20000
)

# Per-file limits (tokens)
declare -A FILE_LIMITS=(
    [root]=3000
    [myself]=5000
    [cache]=8000
    [people]=2000
    [personal]=3000
    [psc]=5000
)

# Measure actual usage
root_tokens=$(count_tokens "$CTX_DIR")
myself_tokens=$(count_tokens_recursive "$CTX_DIR/myself")
cache_tokens=$(count_tokens_recursive "$CTX_DIR/cache")
people_tokens=$(count_tokens_recursive "$CTX_DIR/people")
personal_tokens=$(count_tokens_recursive "$CTX_DIR/personal-context")
psc_tokens=$(count_tokens_recursive "$CTX_DIR/psc")
total_tokens=$((root_tokens + myself_tokens + cache_tokens + people_tokens + personal_tokens + psc_tokens))

echo "$LOG_PREFIX   root: ${root_tokens}/${BUDGETS[root]} | myself: ${myself_tokens}/${BUDGETS[myself]}"
echo "$LOG_PREFIX   cache: ${cache_tokens}/${BUDGETS[cache]} | people: ${people_tokens}/${BUDGETS[people]}"
echo "$LOG_PREFIX   personal: ${personal_tokens}/${BUDGETS[personal]} | psc: ${psc_tokens}/${BUDGETS[psc]}"
echo "$LOG_PREFIX   TOTAL: ${total_tokens} tokens"

# ─── Phase 2: Bloat Detection ─────────────────────────────────────────────────
echo "$LOG_PREFIX [2/4] Bloat detection"

# Find files exceeding per-file token limits
bloated_files=()
bloated_sizes=()
bloated_limits=()

scan_for_bloat() {
    local dir="$1" category="$2" max_depth="${3:-1}"
    if [ ! -d "$dir" ]; then return 0; fi
    local limit=${FILE_LIMITS[$category]}
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local size
        size=$(wc -c < "$file" 2>/dev/null | awk '{printf "%.0f", $1/4}') || continue
        if [ "$size" -gt "$limit" ]; then
            bloated_files+=("$file")
            bloated_sizes+=("$size")
            bloated_limits+=("$limit")
            echo "$LOG_PREFIX   BLOAT: $(basename "$file") = ${size} tokens (limit: ${limit})"
        fi
    done < <(find "$dir" -maxdepth "$max_depth" -name "*.md" -not -path "*/archive/*" -not -path "*/_archive/*" 2>/dev/null || true)
}

scan_for_bloat "$CTX_DIR" "root" 1
scan_for_bloat "$CTX_DIR/myself" "myself" 1
scan_for_bloat "$CTX_DIR/cache" "cache" 1
scan_for_bloat "$CTX_DIR/cache/journals" "cache" 1
scan_for_bloat "$CTX_DIR/cache/comms" "cache" 1
scan_for_bloat "$CTX_DIR/cache/portable-context" "cache" 1
scan_for_bloat "$CTX_DIR/people" "people" 1
scan_for_bloat "$CTX_DIR/personal-context" "personal" 2
scan_for_bloat "$CTX_DIR/psc" "psc" 1

echo "$LOG_PREFIX   Found ${#bloated_files[@]} bloated files"

# ─── Phase 3: Staleness Scan ──────────────────────────────────────────────────
echo "$LOG_PREFIX [3/4] Staleness scan (cache files >14 days)"

stale_count=0
while IFS= read -r file; do
    [ -z "$file" ] && continue
    basename=$(basename "$file")
    [[ "$basename" == DISTILL-REPORT.md ]] && continue
    age=$(( ($(date +%s) - $(stat -c %Y "$file" 2>/dev/null || echo "$(date +%s)")) / 86400 ))
    if [ "$age" -gt 14 ]; then
        echo "$LOG_PREFIX   STALE: $basename (${age} days old)"
        stale_count=$((stale_count + 1))
    fi
done < <(find "$CTX_DIR/cache" -maxdepth 1 -name "*.md" -not -name "DISTILL-REPORT.md" 2>/dev/null)
echo "$LOG_PREFIX   Found $stale_count stale cache files"

# ─── Phase 4: LLM Distillation ────────────────────────────────────────────────
echo "$LOG_PREFIX [4/4] LLM distillation (top $MAX_DISTILL bloated files)"

distilled=0

if [ ${#bloated_files[@]} -eq 0 ]; then
    echo "$LOG_PREFIX   No files need distillation"
else
    # Sort by size descending, pick top N
    # Create paired array for sorting
    pairs=""
    for i in "${!bloated_files[@]}"; do
        pairs+="${bloated_sizes[$i]} ${bloated_files[$i]}\n"
    done
    sorted=$(echo -e "$pairs" | sort -rn | head -"$MAX_DISTILL")

    while IFS=' ' read -r size file; do
        [ -z "$file" ] && continue
        basename=$(basename "$file")
        category_limit=5000  # default
        case "$file" in
            */cache/*) category_limit=${FILE_LIMITS[cache]} ;;
            */myself/*) category_limit=${FILE_LIMITS[myself]} ;;
            */people/*) category_limit=${FILE_LIMITS[people]} ;;
            */personal-context/*) category_limit=${FILE_LIMITS[personal]} ;;
            */psc/*) category_limit=${FILE_LIMITS[psc]} ;;
            *) category_limit=${FILE_LIMITS[root]} ;;
        esac

        echo "$LOG_PREFIX   Distilling: $basename (${size} tokens → target ${category_limit})"

        # Backup before distilling
        backup_dir="$REPO_DIR/backup/distill-$(date '+%Y-%m-%d')"
        mkdir -p "$backup_dir"
        cp "$file" "$backup_dir/$basename"

        # LLM distillation via claude -p — Sonnet (synthesis task class, per cost-and-latency.md §22)
        target_words=$((category_limit * 3 / 4))  # tokens → words (rough)
        distilled_content=$(claude --model claude-sonnet-4-6 -p "You are a knowledge base curator. Your job is to COMPRESS this document while preserving all actionable information.

RULES:
- Target: ${target_words} words maximum
- Keep: decisions, patterns, action items, relationships, dates, metrics
- Remove: redundant entries, verbose explanations, historical noise, expired items
- Remove: anything older than 30 days that has no ongoing relevance
- Preserve: the document's original structure (headings, lists)
- Preserve: any entry marked as important or recurring
- Output: the compressed document only, no commentary

DOCUMENT ($(basename "$file")):
$(cat "$file")" --max-turns 1 2>/dev/null || echo "")

        if [ -n "$distilled_content" ] && [ ${#distilled_content} -gt 100 ]; then
            # Verify distilled version is actually smaller
            old_size=$(wc -c < "$file")
            new_size=$(echo "$distilled_content" | wc -c)
            if [ "$new_size" -lt "$old_size" ]; then
                echo "$distilled_content" > "$file"
                new_tokens=$((new_size / 4))
                echo "$LOG_PREFIX   ✓ Distilled: ${size} → ${new_tokens} tokens ($(( (old_size - new_size) * 100 / old_size ))% reduction)"
                distilled=$((distilled + 1))
            else
                echo "$LOG_PREFIX   ✗ Distilled version not smaller — keeping original"
            fi
        else
            echo "$LOG_PREFIX   ✗ LLM distillation failed — keeping original"
        fi
    done <<< "$sorted"
fi

# ─── Report ────────────────────────────────────────────────────────────────────

# Recalculate totals after distillation using the same category-based method
if [ "$distilled" -gt 0 ]; then
    new_total=$(( $(count_tokens "$CTX_DIR") + $(count_tokens_recursive "$CTX_DIR/myself") + $(count_tokens_recursive "$CTX_DIR/cache") + $(count_tokens_recursive "$CTX_DIR/people") + $(count_tokens_recursive "$CTX_DIR/personal-context") + $(count_tokens_recursive "$CTX_DIR/psc") ))
    reduction=$((total_tokens - new_total))
else
    new_total=$total_tokens
    reduction=0
fi

cat > "$REPORT" << EOF
# Knowledge Distiller Report — $(date '+%Y-%m-%d')

## Token Budget
| Category | Tokens | Budget | Status |
|----------|--------|--------|--------|
| Root context | $root_tokens | ${BUDGETS[root]} | $([ "$root_tokens" -gt "${BUDGETS[root]}" ] && echo "OVER" || echo "OK") |
| Myself | $myself_tokens | ${BUDGETS[myself]} | $([ "$myself_tokens" -gt "${BUDGETS[myself]}" ] && echo "OVER" || echo "OK") |
| Cache | $cache_tokens | ${BUDGETS[cache]} | $([ "$cache_tokens" -gt "${BUDGETS[cache]}" ] && echo "OVER" || echo "OK") |
| People | $people_tokens | ${BUDGETS[people]} | $([ "$people_tokens" -gt "${BUDGETS[people]}" ] && echo "OVER" || echo "OK") |
| Personal | $personal_tokens | ${BUDGETS[personal]} | $([ "$personal_tokens" -gt "${BUDGETS[personal]}" ] && echo "OVER" || echo "OK") |
| PSC | $psc_tokens | ${BUDGETS[psc]} | $([ "$psc_tokens" -gt "${BUDGETS[psc]}" ] && echo "OVER" || echo "OK") |
| **Total** | **$new_total** | **185000** | $([ "$new_total" -gt 185000 ] && echo "**OVER**" || echo "**OK**") |

## Actions Taken
- Bloated files found: ${#bloated_files[@]}
- Files distilled: $distilled
- Stale cache files: $stale_count
- Tokens recovered: $reduction

## Top Bloated Files
$(for i in "${!bloated_files[@]}"; do echo "- $(basename "${bloated_files[$i]}"): ${bloated_sizes[$i]} tokens (limit: ${bloated_limits[$i]})"; done)
EOF

echo "$LOG_PREFIX === Distiller Done: ${distilled} distilled, ${reduction} tokens recovered ==="

if [ "${#bloated_files[@]}" -gt 10 ]; then
    cron_alert "knowledge-distiller" "${#bloated_files[@]} bloated files — knowledge base needs manual attention"
else
    cron_alert_clear "knowledge-distiller"
fi

write_heartbeat "knowledge-distiller"
