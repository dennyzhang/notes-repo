#!/usr/bin/env bash
# cron-gchat-group-digest.sh — Periodic group chat summarization
#
# Reads messages from configured GChat spaces (including large/discoverable ones
# where bot tokens lack permission) using user-auth API calls, summarizes via
# Claude, and pushes the digest to the "GChat Group Digest" tab in the Daily
# Routine Google Doc.
#
# Survives server reinstall: all output goes to Google Docs; local files are
# ephemeral caches only. Config is in GCHAT-SPACES.yaml + DAILY-DOCS.json.
#
# Schedule: 2-3x/day (e.g., 12:00, 18:00, 21:00 weekdays)
# Timeout: 600s via cron_run

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/gdocs_lib.sh"

JOB_NAME="${CRON_JOB_NAME:-gchat-group-digest}"
LOCK_FILE="/tmp/cron-${JOB_NAME}.lock"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# ─── Lock ──────────────────────────────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
    old_pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        log "Already running (pid $old_pid). Exiting."
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
cleanup() { rm -f "$LOCK_FILE" "$TMPDIR_DIGEST"/*.json "$TMPDIR_DIGEST"/*.html 2>/dev/null; rmdir "$TMPDIR_DIGEST" 2>/dev/null; }
trap cleanup EXIT

# ─── Env ───────────────────────────────────────────────────────────────────
unset CLAUDECODE 2>/dev/null || true
cron_self_heal "$JOB_NAME"

if ! ensure_gmux_healthy; then
    log "WARNING: google-mux unhealthy — will attempt anyway"
fi

TMPDIR_DIGEST=$(mktemp -d /tmp/gchat-digest-XXXXXX)
SPACES_YAML="$REPO_DIR/config/GCHAT-SPACES.yaml"
DOC_ID="$(get_doc_id gchat_group_digest)"
TAB_ID="$(get_doc_tab gchat_group_digest digest)"

# ─── Read spaces from YAML config ─────────────────────────────────────────
# Parse space IDs and names from GCHAT-SPACES.yaml
read_spaces() {
    python3 -c "
import re, sys
content = open('$SPACES_YAML').read()
# Simple YAML parser — no PyYAML needed. Parses id/name pairs under priority sections.
current_pri = ''
for line in content.splitlines():
    m = re.match(r'^(high_signal|medium_signal):', line)
    if m:
        current_pri = m.group(1).replace('_signal','')
        continue
    m = re.match(r'^\s+- id:\s*\"?([^\"]+?)\"?\s*$', line)
    if m and current_pri:
        sid = m.group(1)
        continue
    m = re.match(r'^\s+name:\s*\"?(.+?)\"?\s*$', line)
    if m and current_pri:
        name = m.group(1)
        print(f'{sid}|{name}|{current_pri}')
"
}

# ─── Fetch messages from each space ────────────────────────────────────────
# Try gchat read first (fast, works for most spaces).
# Fall back to google-mux api call with user-auth for large/discoverable spaces.
fetch_messages() {
    local space_id="$1"
    local space_name="$2"
    local outfile="$TMPDIR_DIGEST/${space_id}.json"

    # Try standard gchat read first
    local standard_result
    standard_result=$(gchat read "$space_id" -c 30 --since 12h --json 2>/dev/null) || standard_result=""

    # Check if we got actual messages
    local msg_count=0
    if [ -n "$standard_result" ]; then
        msg_count=$(echo "$standard_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null) || msg_count=0
    fi

    if [ "$msg_count" -gt 0 ]; then
        echo "$standard_result" > "$outfile"
        log "  [$space_name] $msg_count messages via gchat read"
    else
        # Fall back to user-auth API (for large/discoverable spaces)
        local api_result
        api_result=$(echo "" | google-mux api call GET \
            "https://chat.googleapis.com/v1/spaces/${space_id}/messages?pageSize=50&orderBy=createTime%20desc" \
            --token-class GoogleChatAuthTokenAsUser --json 2>/dev/null) || api_result=""

        if [ -n "$api_result" ]; then
            msg_count=$(echo "$api_result" | python3 -c "
import sys, json
d = json.load(sys.stdin)
msgs = d.get('data', d).get('messages', []) if isinstance(d, dict) else []
print(len(msgs))
" 2>/dev/null) || msg_count=0
            echo "$api_result" > "$outfile"
            log "  [$space_name] $msg_count messages via user-auth API"
        else
            log "  [$space_name] no messages (empty or error)"
        fi
    fi
}

# ─── Main ──────────────────────────────────────────────────────────────────
log "=== GChat Group Digest ==="

# 1. Fetch messages from all spaces
SPACE_LIST=$(read_spaces)
FETCHED=0

while IFS='|' read -r sid name pri; do
    fetch_messages "$sid" "$name" </dev/null
    FETCHED=$((FETCHED + 1))
done <<< "$SPACE_LIST"

log "Fetched from $FETCHED spaces"

# 2. Check if we have any messages to summarize
TOTAL_FILES=$(find "$TMPDIR_DIGEST" -name "*.json" -size +2c | wc -l)
if [ "$TOTAL_FILES" -eq 0 ]; then
    log "No messages to summarize. Done."
    write_heartbeat "$JOB_NAME"
    exit 0
fi

# 3. Build prompt file with all messages (too large for shell args)
PROMPT_FILE="$TMPDIR_DIGEST/prompt.txt"
cat > "$PROMPT_FILE" << 'PROMPTEOF'
You are summarizing Google Chat group messages for a PE (Production Engineer) TL at Meta, focused on MRS ML / Online Training reliability.

Below are messages from multiple GChat spaces, fetched within the last ~12 hours. For each space that has activity, produce a concise summary:

1. **Key decisions or conclusions** — what was agreed on
2. **Action items** — who committed to do what
3. **Important updates** — SEVs, launches, oncall handoffs, config changes
4. **Notable discussions** — threads worth following up on

Skip spaces with no meaningful activity. Be concise — bullet points, not paragraphs. Group by space name.

Output format: HTML suitable for inserting into a Google Doc. Use <h2> for each space name, <ul>/<li> for bullets. Start with an <h1> containing today's date and time.

STRICT OUTPUT RULES:
- Output ONLY the HTML, starting directly with <h1> and ending directly with the final closing tag.
- NO preamble text like "Here's the HTML digest" or "Using AI Gateway".
- NO markdown code fences (no ```html, no ```).
- NO closing commentary, notes to the operator, or questions back to the user.
- If a space has no meaningful activity, simply omit its <h2> section — do not write "Skipped X because..." inside the doc.

Messages:
PROMPTEOF

while IFS='|' read -r sid name pri; do
    local_file="$TMPDIR_DIGEST/${sid}.json"
    if [ -f "$local_file" ] && [ -s "$local_file" ]; then
        echo "" >> "$PROMPT_FILE"
        echo "=== SPACE: ${name} (${pri} priority) ===" >> "$PROMPT_FILE"
        # Trim each space's JSON to keep prompt manageable (~50 most recent msgs)
        python3 -c "
import json, sys
data = json.load(open('$local_file'))
# Normalize: could be list (gchat read) or dict with data.messages (API)
if isinstance(data, dict):
    msgs = data.get('data', data).get('messages', [])
else:
    msgs = data
# Keep last 30 messages, extract text + sender + time only
trimmed = []
for m in msgs[:30]:
    trimmed.append({
        'sender': m.get('sender', {}).get('name', 'unknown'),
        'text': (m.get('text') or m.get('argumentText') or '')[:500],
        'time': m.get('createTime', '')
    })
json.dump(trimmed, sys.stdout, indent=1)
" >> "$PROMPT_FILE" 2>/dev/null
    fi
done <<< "$SPACE_LIST"

PROMPT_SIZE=$(wc -c < "$PROMPT_FILE")
log "Prompt size: ${PROMPT_SIZE} bytes"

# 4. Summarize via Claude (read prompt from file to avoid arg-list-too-long)
SUMMARY_FILE="$TMPDIR_DIGEST/summary.html"
log "Summarizing via Claude..."

# Use python subprocess directly to avoid shell arg length limits
python3 -c "
import subprocess, signal, os, sys

prompt_file = sys.argv[1]
output_file = sys.argv[2]
with open(prompt_file) as f:
    prompt = f.read()

proc = subprocess.Popen(
    ['claude', '-p', prompt,
     '--allowedTools', '',
     '--model', 'claude-sonnet-4-6',
     '--max-turns', '1',
     '--output-format', 'text'],
    stdout=open(output_file, 'w'),
    stderr=subprocess.STDOUT,
    start_new_session=True
)
try:
    proc.wait(timeout=300)
except subprocess.TimeoutExpired:
    os.killpg(proc.pid, signal.SIGKILL)
    proc.wait()
    sys.exit(124)
sys.exit(proc.returncode)
" "$PROMPT_FILE" "$SUMMARY_FILE"

if [ ! -s "$SUMMARY_FILE" ]; then
    log "ERROR: Claude produced empty output"
    cron_alert "$JOB_NAME" "Claude summarization returned empty"
    exit 1
fi

# 4b. Sanitize LLM meta-commentary — strip leakage that users flagged 2026-04-17
SANITIZED_FILE="$TMPDIR_DIGEST/summary-sanitized.html"
python3 - "$SUMMARY_FILE" "$SANITIZED_FILE" <<'PYEOF'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
raw = open(src).read()
# Strip known LLM preamble/postamble lines
META_LINE_PATTERNS = [
    r'^\s*Using AI Gateway\s*$',
    r"^\s*Here.?s (the|a|your) .*(digest|summary|HTML).*$",
    r'^\s*```(html|HTML)?\s*$',
    r'^\s*Note,?\s+boss[\s,:—-].*',
    r'^\s*Note:\s.*',
    r'^\s*If additional .*',
    r'^\s*Let me know .*',
    r'^\s*Here\'s what I (found|produced|have):?\s*$',
]
lines = raw.splitlines()
kept = [l for l in lines if not any(re.match(p, l) for p in META_LINE_PATTERNS)]
cleaned = '\n'.join(kept)
# Trim everything before the first <h1> (LLM preamble) if an <h1> exists
m = re.search(r'<h1\b', cleaned)
if m:
    cleaned = cleaned[m.start():]
# Trim everything after the final closing tag on a line (LLM trailing commentary)
m = re.search(r'(</(ul|ol|table|p|h1|h2|h3|div)>)\s*$', cleaned.strip(), re.MULTILINE)
# Strip trailing plain-text paragraphs that appear AFTER all HTML tags
cleaned = re.sub(r'(</(?:ul|ol|table|div|section)>)\s*[^<]+$', r'\1', cleaned, flags=re.DOTALL)
open(dst, 'w').write(cleaned.strip() + '\n')
PYEOF

# Empty-content guard: if sanitized output has no <h2> section, there's no signal worth publishing
if ! grep -q '<h2' "$SANITIZED_FILE" 2>/dev/null; then
    # Preserve artifacts for post-mortem (cleanup trap won't wipe these)
    cp "$SUMMARY_FILE" /tmp/gchat-digest-last-summary.html 2>/dev/null || true
    cp "$SANITIZED_FILE" /tmp/gchat-digest-last-sanitized.html 2>/dev/null || true
    log "SKIP: sanitized digest has no <h2> sections. Raw+sanitized preserved at /tmp/gchat-digest-last-{summary,sanitized}.html"
    write_heartbeat "$JOB_NAME"
    exit 0
fi

# Step 0: Idempotency — strip duplicate preamble leaked by LLM
if grep -q 'cron-gchat-group-digest\.sh' "$SANITIZED_FILE" 2>/dev/null; then
    log "WARN: sanitized output contains preamble string — stripping for idempotency"
    grep -v 'cron-gchat-group-digest\.sh' "$SANITIZED_FILE" > "${SANITIZED_FILE}.dedup"
    mv "${SANITIZED_FILE}.dedup" "$SANITIZED_FILE"
fi

# 5. Add provenance header and push to Google Doc
FINAL_HTML="$TMPDIR_DIGEST/final.html"
PROVENANCE=$(gdoc_provenance "cron-gchat-group-digest.sh" "2-3x daily")
{
    echo "$PROVENANCE"
    echo "<hr/>"
    cat "$SANITIZED_FILE"
    echo "<hr/>"
} > "$FINAL_HTML"

# Pre-push HTML lint: script name must appear at most once (our provenance only)
PREAMBLE_COUNT=$(grep -c 'cron-gchat-group-digest\.sh' "$FINAL_HTML" 2>/dev/null || echo 0)
if [ "$PREAMBLE_COUNT" -gt 1 ]; then
    log "ABORT: pre-push lint failed — preamble appears $PREAMBLE_COUNT times (expected ≤1)"
    cron_alert "$JOB_NAME" "Duplicate preamble detected ($PREAMBLE_COUNT occurrences) — aborting push (RULE 52)"
    exit 1
fi

# Tier 3: capture pre-push revision for rollback-safe alerts.
gdocs_capture_prepush_revision "$DOC_ID" "gchat_group_digest" || true

# 5b. Dedup + prepend via shared helper (replaces inline dedup + separate insert).
# Surfaces errors instead of the prior `2>/dev/null` silent delete.
# Manual 3-attempt retry matches prior `gdocs_retry 3 5 gdocs content insert-html`
# semantics — kill gmux daemon between attempts to clear wedged auth/DCAT state.
log "Pushing digest to Google Doc (dedup + prepend)..."
push_ok=false
for attempt in 1 2 3; do
    if gdocs_prepend_today_section "$DOC_ID" "$TAB_ID" "$FINAL_HTML" \
            --format html --max-size-bytes 15000 --label "gchat-group-digest-a${attempt}"; then
        push_ok=true
        break
    fi
    if [ "$attempt" -lt 3 ]; then
        log "WARNING: prepend attempt $attempt/3 failed, restarting gmux and retrying in 5s"
        pkill -9 -f "google-mux daemon" 2>/dev/null || true
        sleep 5
    fi
done
if $push_ok; then
    log "Digest pushed successfully"
    tab_freshness_mark "$JOB_NAME"
    write_heartbeat "$JOB_NAME"
else
    log "ERROR: Failed to push digest to Google Doc (all 3 attempts)"
    cron_alert "$JOB_NAME" "Failed to push digest to gdoc after 3 retries"
    exit 1
fi

log "=== Done ==="

# Tier 1+3: propagate accumulated gdocs errors.
gdocs_exit_with_status "$(basename "$0" .sh)"
