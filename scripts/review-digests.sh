#!/bin/bash
# review-digests.sh — Weekly digest review rollup
#
# Reads all digests from the past 7 days in context/cache/digests/, scores each on
# signal-to-noise, flags digests that correlate with file changes, extracts
# the top insights across all digests, and recommends which to prune.
#
# Usage: ./scripts/review-digests.sh [--days N] [--all]
#   --days N   Look back N days instead of the default 7
#   --all      Include all digests regardless of age
#
# Output: stdout only. No files modified.

set -euo pipefail

DIGESTS_DIR="/home/dennyzhang/work/claude/context/digests"
REPO_ROOT="/home/dennyzhang/work/claude"
LOOKBACK_DAYS=7
INCLUDE_ALL=0

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --days)
            LOOKBACK_DAYS="$2"
            shift 2
            ;;
        --all)
            INCLUDE_ALL=1
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# ─── Helpers ────────────────────────────────────────────────────────────────

# Print a horizontal rule
rule() { printf '%.0s─' $(seq 1 70); printf '\n'; }

# Extract the first non-blank, non-heading line from a section in a file.
# Args: file section_heading
first_line_of_section() {
    local file="$1"
    local heading="$2"
    awk -v h="$heading" '
        $0 ~ h { found=1; next }
        found && /^##/ { exit }
        found && /^[-*1-9]/ && length($0)>5 { print; exit }
        found && /^[A-Z]/ && length($0)>10 { print; exit }
    ' "$file" | head -1 | sed 's/^[-*0-9. ]*//; s/^\*\*//'
}

# Score a digest 0-3 based on signal content.
# +1 for each: concrete action/task, decision recorded, rule/preference change.
score_digest() {
    local file="$1"
    local score=0

    # Signal: contains a concrete task or file change
    if grep -qiE '^\s*[-*]\s*(Fixed|Created|Updated|Filed|Completed|Closed|Added|Removed|Moved)' "$file" 2>/dev/null; then
        score=$((score + 1))
    fi

    # Signal: has a Decisions section with real content (not just "None")
    if grep -qiE '^## Decisions?' "$file" 2>/dev/null; then
        local decision_content
        decision_content=$(awk '/^## Decisions?/{found=1;next} found && /^##/{exit} found{print}' "$file" | grep -v '^\s*$' | grep -v '^None' | head -3)
        if [[ -n "$decision_content" ]]; then
            score=$((score + 1))
        fi
    fi

    # Signal: has a Rules/Corrections/Patterns section with real content
    if grep -qiE '^## (Rules|Corrections|Patterns)' "$file" 2>/dev/null; then
        local rule_content
        rule_content=$(awk '/^## (Rules|Corrections|Patterns)/{found=1;next} found && /^##/{exit} found{print}' "$file" | grep -v '^\s*$' | grep -v '^None' | head -3)
        if [[ -n "$rule_content" ]]; then
            score=$((score + 1))
        fi
    fi

    # Sprint retro format: uses **Bold**: headers instead of ## headings
    if grep -qiE '^# Sprint Retro' "$file" 2>/dev/null; then
        # +1 if Delivered section has at least one bullet (concrete output)
        local delivered_bullets
        delivered_bullets=$(awk '/^\*\*Delivered\*\*/{found=1;next} found && /^\*\*[A-Z]/{exit} found && /^-/{print}' "$file" | grep -v '^\s*$' | head -3)
        if [[ -n "$delivered_bullets" ]]; then
            score=$((score + 1))
        fi
        # +1 if Learnings section has real content
        local learnings
        learnings=$(awk '/^\*\*Learnings\*\*:?/{found=1;next} found && /^\*\*[A-Z]/{exit} found && /^-/{print}' "$file" | grep -v '^\s*$' | head -2)
        if [[ -n "$learnings" ]]; then
            score=$((score + 1))
        fi
        # +1 if Gap is non-trivial (meaning something was learned about estimation)
        local gap_content
        gap_content=$(grep -E '^\*\*Gap\*\*:' "$file" | grep -iv 'none\.' | grep -iv 'scope matched' | head -1)
        if [[ -n "$gap_content" ]]; then
            score=$((score + 1))
        fi
    fi

    echo "$score"
}

# Return score label: HIGH / MED / LOW
score_label() {
    local s="$1"
    if   [[ "$s" -ge 3 ]]; then echo "HIGH"
    elif [[ "$s" -ge 2 ]]; then echo "MED"
    else echo "LOW"
    fi
}

# Produce a 1-line summary for a digest file.
summarize_digest() {
    local file="$1"
    local basename
    basename=$(basename "$file" .md)

    # Sprint retro: use the title line directly
    if grep -qiE '^# Sprint Retro' "$file" 2>/dev/null; then
        local title
        title=$(head -1 "$file" | sed 's/^# *//')
        # Append what was delivered
        local delivered
        delivered=$(awk '/^\*\*Delivered\*\*/{found=1;next} found && /^\*\*/{exit} found && /^-/{print; exit}' "$file" | sed 's/^[-* ]*//')
        if [[ -n "$delivered" ]]; then
            echo "${title}: ${delivered}"
        else
            echo "$title"
        fi
        return
    fi

    # Session digest: pull the first insight bullet
    local first_insight
    first_insight=$(first_line_of_section "$file" "^## Insights?")
    if [[ -n "$first_insight" ]]; then
        echo "${basename}: ${first_insight}"
    else
        # Fallback: first decision
        local first_decision
        first_decision=$(first_line_of_section "$file" "^## Decisions?")
        if [[ -n "$first_decision" ]]; then
            echo "${basename}: ${first_decision}"
        else
            echo "${basename}: (no insight or decision found)"
        fi
    fi
}

# Check if a digest correlates with file changes nearby in time.
# Compares the digest file's mtime against other repo files modified within
# ±2 hours of it (excluding digests/ itself).
was_digest_actionable() {
    local file="$1"
    local digest_mtime
    digest_mtime=$(stat --format='%Y' "$file" 2>/dev/null || echo 0)
    local window=7200  # 2 hours in seconds
    local low=$(( digest_mtime - window ))
    local high=$(( digest_mtime + window ))

    # Search for non-digest .md files changed in that window
    local hits=0
    while IFS= read -r -d '' candidate; do
        local ctime
        ctime=$(stat --format='%Y' "$candidate" 2>/dev/null || echo 0)
        if [[ "$ctime" -ge "$low" && "$ctime" -le "$high" ]]; then
            hits=$((hits + 1))
        fi
    done < <(find "$REPO_ROOT" -name "*.md" \
        -not -path "*/context/cache/digests/*" \
        -not -path "*/.git/*" \
        -not -path "*/backup/*" \
        -print0 2>/dev/null)

    if [[ "$hits" -gt 0 ]]; then
        echo "yes (${hits} file(s) changed nearby)"
    else
        echo "no"
    fi
}

# Extract the top insight lines (bold or leading bullet) from a file.
extract_top_insights() {
    local file="$1"
    # Session digest: pull bullets from ## Insights section
    if grep -qiE '^## Insights?' "$file" 2>/dev/null; then
        awk '/^## Insights?/{found=1;next} found && /^##/{exit} found && /^\s*[-*0-9]/{print}' "$file" \
            | grep -v '^\s*$' \
            | sed 's/^[-*0-9. ]*//' \
            | head -3
    # Sprint retro: pull bullets from **Learnings** section
    elif grep -qiE '^\*\*Learnings\*\*' "$file" 2>/dev/null; then
        awk '/^\*\*Learnings\*\*:?/{found=1;next} found && /^\*\*[A-Z]/{exit} found && /^-/{print}' "$file" \
            | grep -v '^\s*$' \
            | sed 's/^[-* ]*//' \
            | head -3
    fi
}

# ─── Collect digests in range ────────────────────────────────────────────────

NOW=$(date +%s)
CUTOFF=$(( NOW - LOOKBACK_DAYS * 86400 ))

declare -a DIGEST_FILES
while IFS= read -r -d '' f; do
    if [[ "$INCLUDE_ALL" -eq 1 ]]; then
        DIGEST_FILES+=("$f")
    else
        FMTIME=$(stat --format='%Y' "$f" 2>/dev/null || echo 0)
        if [[ "$FMTIME" -ge "$CUTOFF" ]]; then
            DIGEST_FILES+=("$f")
        fi
    fi
done < <(find "$DIGESTS_DIR" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null | sort -z)

TOTAL=${#DIGEST_FILES[@]}

# ─── Header ─────────────────────────────────────────────────────────────────

echo ""
echo "WEEKLY DIGEST REVIEW — $(date '+%Y-%m-%d')"
if [[ "$INCLUDE_ALL" -eq 1 ]]; then
    echo "Scope: ALL digests in context/cache/digests/ (${TOTAL} files)"
else
    echo "Scope: Last ${LOOKBACK_DAYS} days (${TOTAL} files)"
fi
rule

if [[ "$TOTAL" -eq 0 ]]; then
    echo "No digests found in the review window."
    echo "Run with --all to include older digests."
    echo ""
    exit 0
fi

# ─── Per-digest listing with score ──────────────────────────────────────────

echo ""
echo "DIGEST INVENTORY"
echo ""
printf "  %-30s  %-5s  %-10s  %s\n" "FILE" "SCORE" "ACTIONABLE" "SUMMARY"
printf "  %-30s  %-5s  %-10s  %s\n" "------------------------------" "-----" "----------" "-------"

LOW_SIGNAL_FILES=()
HIGH_SIGNAL_FILES=()

for f in "${DIGEST_FILES[@]}"; do
    bn=$(basename "$f" .md)
    score=$(score_digest "$f")
    label=$(score_label "$score")
    actionable=$(was_digest_actionable "$f")
    summary=$(summarize_digest "$f")
    # Truncate summary to fit terminal
    short_summary="${summary:0:60}"
    [[ "${#summary}" -gt 60 ]] && short_summary="${short_summary}…"

    printf "  %-30s  %-5s  %-10s  %s\n" "$bn" "${label}(${score})" "${actionable:0:3}" "$short_summary"

    if [[ "$score" -le 1 ]]; then
        LOW_SIGNAL_FILES+=("$f")
    fi
    if [[ "$score" -ge 3 ]]; then
        HIGH_SIGNAL_FILES+=("$f")
    fi
done

# ─── Weekly rollup: top insights ────────────────────────────────────────────

echo ""
rule
echo ""
echo "TOP INSIGHTS THIS WEEK (from high-signal digests)"
echo ""

declare -a ALL_INSIGHTS
for f in "${DIGEST_FILES[@]}"; do
    score=$(score_digest "$f")
    if [[ "$score" -ge 2 ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && ALL_INSIGHTS+=("$line")
        done < <(extract_top_insights "$f")
    fi
done

# Deduplicate and print top 5
declare -A SEEN
COUNT=0
for insight in "${ALL_INSIGHTS[@]}"; do
    # Normalise: lowercase, strip bold markers
    key=$(echo "$insight" | tr '[:upper:]' '[:lower:]' | sed 's/\*\*//g' | cut -c1-60)
    if [[ -z "${SEEN[$key]+x}" ]]; then
        SEEN[$key]=1
        COUNT=$((COUNT + 1))
        echo "  ${COUNT}. ${insight:0:120}"
        [[ "$COUNT" -ge 5 ]] && break
    fi
done

if [[ "$COUNT" -eq 0 ]]; then
    echo "  (No high-signal insights found in this period.)"
fi

# ─── Prune recommendations ──────────────────────────────────────────────────

echo ""
rule
echo ""
echo "PRUNE CANDIDATES (low signal, score 0-1)"
echo ""

LOW_COUNT=${#LOW_SIGNAL_FILES[@]}
if [[ "$LOW_COUNT" -eq 0 ]]; then
    echo "  None — all digests carry signal. No pruning needed."
else
    for f in "${LOW_SIGNAL_FILES[@]+"${LOW_SIGNAL_FILES[@]}"}"; do
        bn=$(basename "$f" .md)
        fdate=$(stat --format='%y' "$f" 2>/dev/null | cut -d' ' -f1)
        echo "  rm \"$f\""
        echo "  # ${bn} (${fdate}) — low signal: no concrete action, decision, or rule"
    done
    echo ""
    echo "  Total: ${LOW_COUNT} file(s). Review before deleting."
    echo "  If any contain a unique insight not captured elsewhere, move to backup/ instead."
fi

# ─── Anti-sprawl check ──────────────────────────────────────────────────────

echo ""
rule
echo ""
echo "ANTI-SPRAWL STATUS"
echo ""

# Count all digests (not just this week's)
ALL_DIGEST_COUNT=$(find "$DIGESTS_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
echo "  Total digests in context/cache/digests/: ${ALL_DIGEST_COUNT}"

# Flag if folder is growing fast
if [[ "$ALL_DIGEST_COUNT" -gt 20 ]]; then
    echo "  WARNING: folder has ${ALL_DIGEST_COUNT} files. Consider pruning digests older than 30 days."
    echo "  Run: find \"$DIGESTS_DIR\" -name '*.md' -mtime +30 | sort"
elif [[ "$ALL_DIGEST_COUNT" -gt 10 ]]; then
    echo "  WATCH: folder has ${ALL_DIGEST_COUNT} files. Review monthly."
else
    echo "  OK: volume is manageable."
fi

# ─── Time estimate ───────────────────────────────────────────────────────────

echo ""
rule
echo ""
HIGH_COUNT=${#HIGH_SIGNAL_FILES[@]}
echo "REVIEW ESTIMATE"
echo "  Digests this period : ${TOTAL}"
echo "  High signal         : ${HIGH_COUNT}"
echo "  Prune candidates    : ${LOW_COUNT}"
# Approx: 30s per high-signal digest + 10s per low-signal decision + fixed overhead
EST_SECS=$(( 60 + HIGH_COUNT * 30 + LOW_COUNT * 10 ))
EST_MIN=$(( EST_SECS / 60 ))
EST_SEC=$(( EST_SECS - EST_MIN * 60 ))
echo "  Estimated review time: ~${EST_MIN}m ${EST_SEC}s"
echo ""
