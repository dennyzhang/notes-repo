#!/usr/bin/env bash
# routine-workflow.sh — Portable daily routine generator.
#
# Orchestrates: data pre-fetch → Claude synthesis → validation → Google Doc push.
# Designed to run as a nightly cron job (2 AM recommended).
#
# Prerequisites:
#   - Claude Code CLI (claude -p)
#   - google-mux (or equivalent Google API CLI)
#   - jq
#   - Configured routine-config.json
#
# Usage:
#   ./routine-workflow.sh                    # Normal run
#   ./routine-workflow.sh --dry-run          # Generate but don't push to Google Doc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${SCRIPT_DIR}/routine-config.json"
TODAY=$(date +%Y-%m-%d)
DOW=$(date +%A)
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [ ! -f "$CONFIG" ]; then
    echo "$LOG_PREFIX [ERROR] Config not found: $CONFIG"
    echo "Copy routine-config.json.example and fill in your values."
    exit 1
fi

DOC_ID=$(jq -r '.doc_id' "$CONFIG")
MODEL=$(jq -r '.model // "sonnet"' "$CONFIG")
MAX_TURNS=$(jq -r '.max_turns // 50' "$CONFIG")
TIMEOUT=$(jq -r '.timeout_seconds // 1800' "$CONFIG")

WORK_DIR=$(mktemp -d /tmp/routine-workflow-XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "$LOG_PREFIX === Daily Routine Workflow ==="
echo "$LOG_PREFIX Config: doc=$DOC_ID, model=$MODEL, date=$TODAY ($DOW)"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Data Pre-fetch
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [1/4] Pre-fetching data..."

# Calendar
CAL_FILE="$WORK_DIR/calendar.txt"
if command -v gcal &>/dev/null; then
    gcal events list --date "$TODAY" > "$CAL_FILE" 2>/dev/null || echo "(no calendar data)" > "$CAL_FILE"
else
    echo "(calendar CLI not available)" > "$CAL_FILE"
fi
echo "$LOG_PREFIX   Calendar: $(wc -l < "$CAL_FILE") lines"

# GChat messages from configured spaces
GCHAT_FILE="$WORK_DIR/gchat.txt"
: > "$GCHAT_FILE"
for space_key in $(jq -r '.gchat_spaces | keys[]' "$CONFIG" 2>/dev/null); do
    space_id=$(jq -r ".gchat_spaces.\"$space_key\"" "$CONFIG")
    {
        echo "## $space_key: $space_id"
        gchat read "$space_id" 2>/dev/null || echo "(read failed)"
        echo ""
    } >> "$GCHAT_FILE"
done
echo "$LOG_PREFIX   GChat: $(wc -l < "$GCHAT_FILE") lines"

# Diffs (authored + reviewing)
DIFFS_FILE="$WORK_DIR/diffs.txt"
if command -v meta &>/dev/null; then
    {
        echo "## Authored Diffs"
        meta phabricator.diff list --author-is-me --limit 10 2>/dev/null || echo "(fetch failed)"
        echo ""
        echo "## Review Queue"
        meta phabricator.diff list --reviewer-is-me --limit 10 --status=needs-review 2>/dev/null || echo "(fetch failed)"
    } > "$DIFFS_FILE"
else
    echo "(meta CLI not available)" > "$DIFFS_FILE"
fi
echo "$LOG_PREFIX   Diffs: $(wc -l < "$DIFFS_FILE") lines"

# Follow-ups
FOLLOWUPS_FILE="$WORK_DIR/followups.txt"
followups_path=$(jq -r '.followups_file // "FOLLOWUPS.md"' "$CONFIG")
if [ -f "$followups_path" ]; then
    head -60 "$followups_path" > "$FOLLOWUPS_FILE"
else
    echo "(no followups file)" > "$FOLLOWUPS_FILE"
fi

# Identity + Career Goals
IDENTITY_FILE="$WORK_DIR/identity.txt"
identity_path=$(jq -r '.identity_file // "context/myself/IDENTITY.md"' "$CONFIG")
goals_path=$(jq -r '.career_goals_file // "context/myself/CAREER-GOALS.md"' "$CONFIG")
{
    [ -f "$identity_path" ] && cat "$identity_path" || echo "(no identity file)"
    echo ""
    [ -f "$goals_path" ] && cat "$goals_path" || echo "(no career goals file)"
} > "$IDENTITY_FILE"

# People profiles for today's meeting attendees
PEOPLE_FILE="$WORK_DIR/people.txt"
people_dir=$(jq -r '.people_dir // "context/people"' "$CONFIG")
: > "$PEOPLE_FILE"
if [ -d "$people_dir" ]; then
    for pfile in "$people_dir"/*.md; do
        [ -f "$pfile" ] || continue
        echo "## $(basename "$pfile" .md)"
        head -20 "$pfile"
        echo ""
    done > "$PEOPLE_FILE"
fi
echo "$LOG_PREFIX   People profiles: $(wc -l < "$PEOPLE_FILE") lines"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Claude Synthesis
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [2/4] Running Claude synthesis..."

# Combine all pre-fetched data into one context file
CONTEXT_FILE="$WORK_DIR/all-context.txt"
{
    echo "=== IDENTITY + CAREER GOALS ==="; cat "$IDENTITY_FILE"; echo ""
    echo "=== CALENDAR ($TODAY) ==="; cat "$CAL_FILE"; echo ""
    echo "=== GCHAT MESSAGES ==="; cat "$GCHAT_FILE"; echo ""
    echo "=== DIFFS ==="; cat "$DIFFS_FILE"; echo ""
    echo "=== FOLLOW-UPS ==="; cat "$FOLLOWUPS_FILE"; echo ""
    echo "=== PEOPLE PROFILES ==="; cat "$PEOPLE_FILE"; echo ""
} > "$CONTEXT_FILE"

context_bytes=$(wc -c < "$CONTEXT_FILE")
echo "$LOG_PREFIX   Context assembled: $context_bytes bytes"

OUTPUT_FILE="$WORK_DIR/routine-output.md"
PROMPT="You are writing today's daily work routine for $TODAY ($DOW).

Read the file $CONTEXT_FILE. It contains pre-fetched data from calendar, GChat, diffs, follow-ups, career goals, and people profiles.

Write a structured daily plan following the template in routine-template.md. Include:
1. Action Rows (3-5 items, priority-ordered: career-critical > blocking diffs > ops)
2. Coaching Signals (IC score, ship rate, scope, comms ratio)
3. Diff Review Queue (top 5 with review angles)
4. Meeting Prep (per-person context for each meeting)

Rules:
- Use actual data from the context — do not invent items
- Career-critical items always rank above operational items
- Tag overdue items with 'DEFERRED N DAYS'
- If it's a weekend, deprioritize ops, emphasize deep work
- Output only the routine content — no preamble or commentary"

claude_exit=0
timeout "$TIMEOUT" claude -p "$PROMPT" \
    --allowedTools Read \
    --model "$MODEL" \
    --max-turns "$MAX_TURNS" \
    --output-format text \
    > "$OUTPUT_FILE" 2>/dev/null \
    || claude_exit=$?

if [ "$claude_exit" -ne 0 ]; then
    echo "$LOG_PREFIX [ERROR] Claude synthesis failed (exit=$claude_exit)"
    exit 1
fi

output_bytes=$(wc -c < "$OUTPUT_FILE")
echo "$LOG_PREFIX   Output: $output_bytes bytes"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Validation
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [3/4] Validating output..."

min_actions=$(jq -r '.scoring.min_actions // 3' "$CONFIG")
score=0
output_text=$(cat "$OUTPUT_FILE")

# Check date
echo "$output_text" | grep -q "$TODAY" && score=$((score + 15)) && echo "$LOG_PREFIX   +15 correct date"
# Check action count
action_count=$(echo "$output_text" | grep -ciE 'RIGHT NOW|DEEP WORK|DECISION|OPS|COMMS' || true)
[ "$action_count" -ge "$min_actions" ] && score=$((score + 10)) && echo "$LOG_PREFIX   +10 has $action_count action(s)"
# Check coaching
echo "$output_text" | grep -qi 'IC.*SCORE\|ship rate\|scope' && score=$((score + 10)) && echo "$LOG_PREFIX   +10 has coaching signals"
# Check diff queue
diff_count=$(echo "$output_text" | grep -c '^- D[0-9]' || true)
[ "$diff_count" -gt 0 ] && score=$((score + 10)) && echo "$LOG_PREFIX   +10 has $diff_count diff(s)"

echo "$LOG_PREFIX   Score: $score/45"

if [ "$score" -lt 20 ]; then
    echo "$LOG_PREFIX [ERROR] Score too low ($score) — aborting"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Publish
# ═══════════════════════════════════════════════════════════════════════════════

if [ "$DRY_RUN" = true ]; then
    echo "$LOG_PREFIX [DRY RUN] Would push to Google Doc $DOC_ID"
    echo "$LOG_PREFIX Output saved to: $OUTPUT_FILE"
    cat "$OUTPUT_FILE"
    exit 0
fi

echo "$LOG_PREFIX [4/4] Publishing to Google Doc..."

if command -v gdocs &>/dev/null && [ "$DOC_ID" != "YOUR_GOOGLE_DOC_ID_HERE" ]; then
    # Push content to Google Doc (prepend today's section)
    push_exit=0
    gdocs content insert-text "$DOC_ID" @"$OUTPUT_FILE" --index 1 2>/dev/null || push_exit=$?
    if [ "$push_exit" -eq 0 ]; then
        echo "$LOG_PREFIX   Google Doc updated successfully"
    else
        echo "$LOG_PREFIX   [WARN] Google Doc push failed (exit=$push_exit)"
    fi
else
    echo "$LOG_PREFIX   [SKIP] Google Doc push (no doc ID configured or gdocs not available)"
fi

# Save local cache
CACHE_DIR="${CACHE_DIR:-context/cache}"
mkdir -p "$CACHE_DIR"
cp "$OUTPUT_FILE" "$CACHE_DIR/ROUTINE.md"
echo "$LOG_PREFIX   Local cache updated: $CACHE_DIR/ROUTINE.md"

echo "$LOG_PREFIX === Daily Routine Workflow Done (score=$score) ==="
