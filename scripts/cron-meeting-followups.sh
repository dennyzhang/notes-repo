#!/usr/bin/env bash
# cron-meeting-followups.sh — Extract action items from AI meeting notes → Meta tasks.
#
# After today's recurring meetings end, the AI-generated notes contain a "Next steps"
# (Zoom AI) or "Action items" (Gemini) section. This cron reads them, identifies items
# Denny owns or co-owns, and files Meta tasks tagged `denny-ai-generated, meeting-followup`.
#
# Schedule: daily 18:00 PT M-F (primary) + Sat 09:00 PT (catch-up for Fri-evening + weekend).
#
# Inputs:
#   - config/MEETING-AI-NOTES.json — recurring meetings to monitor
#   - gcal list (today's events) — to find live meeting → notes-doc links
#
# Outputs:
#   - Meta tasks (tagged denny-ai-generated, meeting-followup)
#   - FOLLOWUPS.md rows (appended)
#   - Comment on source AI notes doc ([Claude] Filed: T<n>)
#   - context/cache/state/MEETING-FOLLOWUPS-STATE.json (dedup)
#   - ~/logs/cron-meeting-followups.log (operational)
#
# Failure modes handled:
#   - AI notes not generated yet (placeholder text) → status=not_ready, retry hourly until 23:00
#   - Meeting in config but no event today → skip silently (recurring may be off this week)
#   - Meeting today but no AI notes attached → status=empty, alert at end-of-day
#   - Meta task create fails → cron_alert with payload preserved

set -uo pipefail

REPO_DIR="$HOME/work/claude"
SCRIPT_DIR="$REPO_DIR/scripts"
LIB_DIR="$SCRIPT_DIR/lib"
CONFIG_FILE="$REPO_DIR/config/MEETING-AI-NOTES.json"
STATE_FILE="$REPO_DIR/context/cache/state/MEETING-FOLLOWUPS-STATE.json"
LOCK_FILE="/tmp/meeting-followups-state.lock"
FOLLOWUPS_FILE="$REPO_DIR/FOLLOWUPS.md"
FOLLOWUPS_LOCK="/tmp/followups-md.lock"
TODAY="${TODAY:-$(date +%Y-%m-%d)}"
DUE_DATE="${DUE_DATE:-$(date -d "$TODAY +7 days" +%Y-%m-%d)}"
# SCAN_DAYS=1 (default, primary) processes today only.
# SCAN_DAYS=3 (Saturday catch-up) re-scans today + 2 prior days for not_ready/missed meetings.
SCAN_DAYS="${SCAN_DAYS:-1}"
NOW_HHMM=$(date +%H:%M)
TMPDIR=$(mktemp -d /tmp/meeting-followups.XXXXXX)
LOG_PREFIX="[meeting-followups]"
OWNER_FULLNAME="${OWNER_FULLNAME:-Denny Zhang}"
OWNER_UNIXNAME="${OWNER_UNIXNAME:-dennyzhang}"
DOC_FETCH_TIMEOUT="${DOC_FETCH_TIMEOUT:-15}"

source "$SCRIPT_DIR/cron-alert.sh"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

log() { echo "$LOG_PREFIX [$(date +%H:%M:%S)] $*"; }

# Atomic state-file update: read state, apply Python edit, write to .tmp, mv into place.
# Wrapped in flock so primary + Saturday catch-up don't race.
state_update() {
    local py_code="$1"
    (
        flock 9
        python3 -c "
import json, os, sys
path = '$STATE_FILE'
state = json.load(open(path))
$py_code
tmp = path + '.tmp.' + str(os.getpid())
with open(tmp, 'w') as f:
    json.dump(state, f, indent=2)
os.rename(tmp, path)
"
    ) 9>"$LOCK_FILE"
}

# Saturday catch-up uses SCAN_DAYS>1 to re-process recent days that were `not_ready`.
# State key includes the date so already-filed days are skipped via the dedup check.
get_scan_dates() {
    local days="$1"
    local i
    for ((i=0; i<days; i++)); do
        date -d "$TODAY -$i days" +%Y-%m-%d
    done
}

# Pre-flight checks
[ -f "$CONFIG_FILE" ] || { log "FATAL: config missing: $CONFIG_FILE"; cron_alert "meeting-followups" "config missing"; exit 1; }
# Validate config schema — fail fast on malformed JSON or missing opt_out key.
# Print a clean one-liner instead of the full Python traceback.
cfg_err=$(python3 -c "
import json, sys
try:
    cfg = json.load(open('$CONFIG_FILE'))
    assert 'opt_out' in cfg, 'opt_out key missing'
    assert isinstance(cfg['opt_out'], list), 'opt_out must be a list'
    for o in cfg['opt_out']:
        assert isinstance(o, dict) and 'title_match' in o, 'opt_out entry missing title_match'
except (json.JSONDecodeError, AssertionError) as e:
    print(str(e))
    sys.exit(1)
" 2>&1)
if [ -n "$cfg_err" ]; then
    log "FATAL: config schema invalid: $cfg_err"
    cron_alert "meeting-followups" "config schema invalid: $cfg_err"
    exit 1
fi
mkdir -p "$(dirname "$STATE_FILE")"
[ -f "$STATE_FILE" ] || echo '{}' > "$STATE_FILE"

# --- Outer loop: scan today + (catch-up only) prior days ---
SCAN_DATES=$(get_scan_dates "$SCAN_DAYS")
log "Scanning dates: $(echo $SCAN_DATES | tr '\n' ' ')"

for SCAN_DATE in $SCAN_DATES; do
log "=== Processing date: $SCAN_DATE ==="

# --- Step 1: Calendar events for SCAN_DATE ---
log "Fetching calendar for $SCAN_DATE..."
GCAL_RAW="$TMPDIR/gcal-$SCAN_DATE.txt"
GCAL_ERR="$TMPDIR/gcal-$SCAN_DATE.err"
if ! "$HOME/.claude/skills/calendar/scripts/get-meetings.py" "$SCAN_DATE" --notes --links \
    --tz America/Los_Angeles > "$GCAL_RAW" 2> "$GCAL_ERR"; then
    log "WARN: gcal call failed for $SCAN_DATE: $(head -3 "$GCAL_ERR")"
    cron_alert "meeting-followups" "gcal failed for $SCAN_DATE"
    continue
fi

if [ ! -s "$GCAL_RAW" ]; then
    log "No calendar events for $SCAN_DATE. Skipping."
    continue
fi

# --- Step 2: Auto-discover events with attached docs (opt-out semantics) ---
# Process EVERY calendar event with at least one Google Doc attachment, except
# titles in config.opt_out. Provider (zoom-ai vs gemini) is sniffed from doc
# content during Step 3 — config doesn't need to know meeting → provider mapping.
log "Discovering events with attached docs..."
MATCHES_JSON="$TMPDIR/matches.json"
python3 - "$GCAL_RAW" "$CONFIG_FILE" "$MATCHES_JSON" << 'PYEOF'
import json, re, sys

gcal_path, config_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(gcal_path) as f:
    gcal = f.read()
with open(config_path) as f:
    cfg = json.load(f)

opt_out = [o["title_match"].lower() for o in cfg.get("opt_out", [])]

matches = []
opted_out = []
event_blocks = re.split(r"\n(?=- \*\*\w{3} )", gcal)
for block in event_blocks:
    title_match = re.search(r"\*\*[^*]+\*\*\s+P[DS]T:\s+(.+?)$", block, re.MULTILINE)
    if not title_match:
        continue
    title = title_match.group(1).strip()
    doc_ids = re.findall(r"docs\.google\.com/document/d/([\w-]+)", block)
    if not doc_ids:
        continue  # no attached docs — not a candidate

    # Opt-out check (case-insensitive substring)
    title_lc = title.lower()
    if any(p in title_lc for p in opt_out):
        opted_out.append(title)
        continue

    matches.append({
        "title": title,
        "doc_ids": doc_ids,
        "provider": "auto",  # sniff at fetch time
    })

with open(out_path, "w") as f:
    json.dump(matches, f, indent=2)
print(f"Discovered {len(matches)} candidate event(s) with attached docs")
if opted_out:
    print(f"Opted out: {len(opted_out)} ({', '.join(opted_out[:3])}{'...' if len(opted_out) > 3 else ''})")
PYEOF

MATCH_COUNT=$(python3 -c "import json;print(len(json.load(open('$MATCHES_JSON'))))" 2>/dev/null || echo 0)
log "Matched $MATCH_COUNT meeting(s)"

if [ "$MATCH_COUNT" -eq 0 ]; then
    log "No recurring meetings on $SCAN_DATE."
    continue
fi

# --- Step 3: For each match, fetch notes + parse + file ---
TOTAL_FILED="${TOTAL_FILED:-0}"
TOTAL_NOT_READY="${TOTAL_NOT_READY:-0}"
TOTAL_EMPTY="${TOTAL_EMPTY:-0}"

while IFS= read -r match_row; do
    title=$(echo "$match_row" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['title'])")
    doc_ids=$(echo "$match_row" | python3 -c "import sys,json;d=json.load(sys.stdin);print('\n'.join(d['doc_ids']))")

    log "Processing: $title — date $SCAN_DATE"

    # State key uses the event title (case-insensitive normalized) since we no longer
    # have a config-mapped canonical title in auto-discover mode.
    state_key=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '_')
    already_filed=$(python3 -c "
import json
state = json.load(open('$STATE_FILE'))
key = '$state_key|$SCAN_DATE'
filed = state.get(key, {}).get('filed_task_ids', [])
print(len(filed))
" 2>/dev/null || echo 0)
    if [ "$already_filed" -gt 0 ]; then
        log "  Already filed $already_filed task(s) for this meeting on $SCAN_DATE — skipping"
        continue
    fi

    # Try each candidate doc until we find one that (a) sniffs as AI notes and
    # (b) has today's section. Provider is sniffed per-doc, not per-meeting.
    # Initial status `no_ai_notes` distinguishes "no AI doc among attachments"
    # from "AI doc exists but content not_ready" — the alert path cares about
    # the latter (Zoom may have failed) but not the former (meeting just doesn't have AI notes).
    notes_doc_id=""
    parse_status="no_ai_notes"
    for did in $doc_ids; do
        log "  Trying notes doc: $did (timeout ${DOC_FETCH_TIMEOUT}s)"
        notes_file="$TMPDIR/notes-$did.md"
        # </dev/null on inner commands prevents them from consuming bytes from the
        # outer `while read` loop's process substitution.
        if ! timeout "$DOC_FETCH_TIMEOUT" meta google.docs get --id="$did" --untrusted-authors-mode \
                </dev/null > "$notes_file" 2>"$TMPDIR/fetch-err-$did"; then
            err=$(head -c 200 "$TMPDIR/fetch-err-$did")
            log "    fetch failed/timeout: $err"
            continue
        fi
        # Provider sniff: skip non-AI-notes docs (transcripts, agendas, regular gdocs).
        provider=$(python3 "$HOME/work/claude/private_scripts/lib/meeting_notes_parsers.py" sniff --html-file "$notes_file" </dev/null 2>/dev/null)
        if [ -z "$provider" ] || [ "$provider" = "none" ]; then
            log "    not an AI notes doc — skip"
            continue
        fi
        log "    provider sniffed: $provider"
        # We found an AI notes doc; from here on, status reflects parse outcome
        # (not_ready / empty / ready), not "no_ai_notes".
        if [ "$parse_status" = "no_ai_notes" ]; then
            parse_status="not_ready"
        fi
        # Run parser
        parse_out="$TMPDIR/parse-$did.json"
        python3 "$HOME/work/claude/private_scripts/lib/meeting_notes_parsers.py" parse \
            --provider "$provider" \
            --html-file "$notes_file" \
            --today "$SCAN_DATE" \
            --owner-fullname "$OWNER_FULLNAME" \
            --owner-unixname "$OWNER_UNIXNAME" </dev/null > "$parse_out" 2>/dev/null || true
        status=$(python3 -c "import json;print(json.load(open('$parse_out'))['status'])" 2>/dev/null || echo error)
        log "    parser status: $status"
        if [ "$status" = "ready" ]; then
            notes_doc_id="$did"
            parse_status="ready"
            cp "$parse_out" "$TMPDIR/parse-final.json"
            break
        elif [ "$status" = "empty" ]; then
            parse_status="empty"
        fi
    done

    if [ "$parse_status" = "no_ai_notes" ]; then
        log "  No AI notes attachment — skipping (Saturday catch-up will retry if it generates late)"
        continue
    fi
    if [ "$parse_status" = "not_ready" ]; then
        log "  Not ready: AI notes attached but content not generated yet"
        TOTAL_NOT_READY=$((TOTAL_NOT_READY + 1))
        continue
    fi
    if [ "$parse_status" = "empty" ]; then
        log "  Empty: today's section has no action items"
        TOTAL_EMPTY=$((TOTAL_EMPTY + 1))
        continue
    fi

    # Filter to Denny's items
    DENNY_ITEMS="$TMPDIR/denny-items-$notes_doc_id.json"
    python3 -c "
import json
data = json.load(open('$TMPDIR/parse-final.json'))
denny_items = [it for it in data['items'] if it['denny_role'] in ('owner', 'co-owner')]
json.dump(denny_items, open('$DENNY_ITEMS', 'w'), indent=2)
print(f'  {len(denny_items)} Denny-owned items (out of {len(data[\"items\"])})')
" | sed "s/^/$LOG_PREFIX /"

    denny_count=$(python3 -c "import json;print(len(json.load(open('$DENNY_ITEMS'))))" 2>/dev/null || echo 0)
    if [ "$denny_count" -eq 0 ]; then
        log "  No Denny-owned items — skip task creation"
        if [ "${DRY_RUN:-0}" != "1" ]; then
            state_update "
state['$state_key|$SCAN_DATE'] = {'filed_task_ids': [], 'doc_id': '$notes_doc_id', 'status': 'no-denny-items'}
"
        fi
        continue
    fi

    # File tasks for each Denny item
    FILED_IDS=()
    while IFS= read -r item_json; do
        body=$(echo "$item_json" | python3 -c "import sys,json;print(json.load(sys.stdin)['body'])")
        role=$(echo "$item_json" | python3 -c "import sys,json;print(json.load(sys.stdin)['denny_role'])")
        owners=$(echo "$item_json" | python3 -c "import sys,json;print(', '.join(json.load(sys.stdin)['owners']))")

        # Truncate title to 100 chars
        task_title="[oncall-meeting] ${body:0:100}"
        # Dedup against existing tasks (last 7d). Constrain to title field by extracting
        # the title column only — `meta tasks.task list` output is column-oriented.
        body_prefix="${body:0:50}"
        existing=$(meta tasks.task list --owner=dennyzhang --tags=meeting-followup --limit=20 </dev/null 2>/dev/null \
            | awk -F'  +' '{print $2}' | grep -iF "$body_prefix" | head -1 || true)
        if [ -n "$existing" ]; then
            log "    Dedup hit — task already exists for: $body_prefix..."
            continue
        fi

        task_desc="From meeting: $title ($SCAN_DATE)
Source: AI notes doc https://docs.google.com/document/d/$notes_doc_id/edit
Role: $role | Co-owners: $owners

$body"

        if [ "${DRY_RUN:-0}" = "1" ]; then
            log "    [DRY_RUN] would file: $task_title"
            FILED_IDS+=("DRY-T?")
            continue
        fi
        if T_OUTPUT=$(meta tasks.task create \
            --title="$task_title" \
            --owner=dennyzhang \
            --priority=MID \
            --add-tag=denny-ai-generated,meeting-followup \
            --description="$task_desc" </dev/null 2>&1); then
            T_NUMBER=$(echo "$T_OUTPUT" | grep -oP 'T\d{8,}' | head -1)
            if [ -n "$T_NUMBER" ]; then
                log "    Filed: $T_NUMBER ($body_prefix...)"
                FILED_IDS+=("$T_NUMBER")
                # Append to FOLLOWUPS.md under flock to avoid concurrent-cron corruption
                (
                    flock 9
                    printf '| %s | %s | [oncall-meeting] %s — %s | pending |\n' \
                        "$SCAN_DATE" "$DUE_DATE" "${body:0:80}" "$T_NUMBER" >> "$FOLLOWUPS_FILE"
                ) 9>"$FOLLOWUPS_LOCK"
            fi
        else
            log "    FAILED to create task for: $body_prefix..."
            log "    Output: $T_OUTPUT"
            cron_alert "meeting-followups" "Task creation failed: $body_prefix"
        fi
    done < <(python3 -c "
import json
items = json.load(open('$DENNY_ITEMS'))
for it in items:
    print(json.dumps(it))
")

    TOTAL_FILED=$((TOTAL_FILED + ${#FILED_IDS[@]}))

    # Update state atomically (skip in dry-run so smoke tests don't pollute future real runs)
    if [ ${#FILED_IDS[@]} -gt 0 ] && [ "${DRY_RUN:-0}" != "1" ]; then
        # Quote each task id individually so Python can ingest as a list literal.
        ids_py=$(printf '"%s",' "${FILED_IDS[@]}")
        state_update "
state['$state_key|$SCAN_DATE'] = {
    'filed_task_ids': [${ids_py%,}],
    'doc_id': '$notes_doc_id',
    'status': 'filed',
    'filed_at': '$SCAN_DATE $NOW_HHMM PT'
}
"
        # Post comment on source doc (best-effort; non-fatal). Wrap in timeout so
        # a hanging API call can't blow the cron budget.
        # comment.add does NOT accept --untrusted-authors-mode (CLI quirk; works without it).
        comment_text="[Claude] Filed: ${FILED_IDS[*]} @ $SCAN_DATE $NOW_HHMM PT — see Routine Doc for next-day rollup"
        anchor_text="$(date -d "$SCAN_DATE" '+%b %-d, %Y')"
        if timeout 15 meta google.docs.comment add --id="$notes_doc_id" \
                --content="$comment_text" \
                --quoted-text="$anchor_text" </dev/null 2>/dev/null; then
            log "  Posted [Claude] comment on source doc"
        else
            log "  Comment post failed/timeout (permission?) — non-fatal"
        fi
    elif [ "${DRY_RUN:-0}" = "1" ]; then
        log "  [DRY_RUN] skipping state update + comment post"
    fi
done < <(python3 -c "
import json
matches = json.load(open('$MATCHES_JSON'))
for m in matches:
    print(json.dumps(m))
")

done  # end SCAN_DATE loop

# Note: removed the `HHMM_NOW >= 2300` not_ready alert — cron only runs at 18:00 PT,
# so the check was dead code. Saturday catch-up (SCAN_DAYS=3) is the safety net for
# meetings whose AI notes generated late — it re-processes Thu/Fri/Sat and picks
# them up. If a current-day not_ready repeats across Sat catch-up too, that's the
# signal to alert; track via state-file age in a future cron-cron-health pass.

log "Summary: filed=${TOTAL_FILED:-0}, not_ready=${TOTAL_NOT_READY:-0}, empty=${TOTAL_EMPTY:-0} (scanned $SCAN_DAYS day(s))"
write_heartbeat "meeting-followups"
log "Done."
