#!/usr/bin/env bash
# cron-alert.sh — Shared helper for crontab scripts to write failures to ALERTS.md.
# Source this file, then call: cron_alert "script-name" "what failed"
#
# Usage in crontab scripts:
#   source "$(dirname "$0")/cron-alert.sh"
#   cron_alert "gdoc-sync" "3 files failed to push: STRATEGY.md, CLAUDE.md, IC7-PLAN.md"

# Ensure cron PATH includes directories where claude, jf, and other tools live.
# Cron uses a minimal PATH (/usr/bin:/bin) so tools at /usr/local/bin, ~/.local/bin are missing.
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# FBID identity for clicat create (cert renewal). Without these, clicat fails with
# "Could not authenticate using FBID identity type" in cron env.
export THRIFT_TLS_CL_CERT_PATH="${THRIFT_TLS_CL_CERT_PATH:-/var/facebook/credentials/$USER/x509/$USER.pem}"
export THRIFT_TLS_CL_KEY_PATH="${THRIFT_TLS_CL_KEY_PATH:-/var/facebook/credentials/$USER/x509/$USER.pem}"

ALERTS_FILE="${ALERTS_FILE:-$HOME/work/claude/ALERTS.md}"
ERROR_PATTERN_DB="${ERROR_PATTERN_DB:-$HOME/work/claude/context/cache/ERROR-PATTERNS.json}"

# ─── Operational State Directory ────────────────────────────────────────────
# All operational state (heartbeats, metrics, runtime) lives in ~/work/claude/state/.
# NOT in /tmp/ (lost on reboot). Git-ignored via /state/ in .gitignore so the
# folder is visible to the user but never committed. Legacy ~/.claude/state is
# maintained as a symlink to ~/work/claude/state for backward compat.
CLAUDE_STATE_DIR="${CLAUDE_STATE_DIR:-$HOME/work/claude/state}"
HEARTBEAT_DIR="${HEARTBEAT_DIR:-$CLAUDE_STATE_DIR/heartbeats}"
mkdir -p "$HEARTBEAT_DIR" 2>/dev/null

# ─── Tab Freshness Sentinels ──────────────────────────────────────────────
# Each cron writes a sentinel after successfully updating a gdoc tab.
# The keepalive staleness checker reads these to detect stale tabs.
TAB_FRESHNESS_DIR="${TAB_FRESHNESS_DIR:-$CLAUDE_STATE_DIR/tab-freshness}"
mkdir -p "$TAB_FRESHNESS_DIR" 2>/dev/null

# Call after successfully pushing to a gdoc tab:
#   tab_freshness_mark "routine-daily-digest"
tab_freshness_mark() {
    local key="$1"
    echo "$(date +%s)" > "$TAB_FRESHNESS_DIR/$key"
}

# Helper: write heartbeat sentinel (replaces manual echo to /tmp/)
write_heartbeat() {
    local name="$1"
    echo "$(date +%s)" > "$HEARTBEAT_DIR/cron-heartbeat-${name}"
}

# ─── Daily Docs Config ────────────────────────────────────────────────────
# Centralized doc IDs and GChat space IDs. Scripts should use these helpers
# instead of hardcoding IDs that break on devserver migration.
DAILY_DOCS_CONFIG="${DAILY_DOCS_CONFIG:-$HOME/work/claude/config/DAILY-DOCS.json}"

# get_doc_id <key> — returns the Google Doc ID for a named doc (e.g., "routine", "ai_feedback_log")
# Fails loudly to stderr if config missing or key not found (so callers see the error in logs)
get_doc_id() {
    local result
    if [ ! -f "$DAILY_DOCS_CONFIG" ]; then
        echo "[get_doc_id] ERROR: Config missing: $DAILY_DOCS_CONFIG" >&2
        return 1
    fi
    result=$(python3 -c "import json; d=json.load(open('$DAILY_DOCS_CONFIG')); print(d['docs']['$1']['id'])" 2>/dev/null) || {
        echo "[get_doc_id] ERROR: Key '$1' not found in $DAILY_DOCS_CONFIG" >&2
        return 1
    }
    echo "$result"
}

# get_doc_tab <doc_key> <tab_key> — returns a tab ID (e.g., get_doc_tab "ai_feedback_log" "alerts")
get_doc_tab() {
    local result
    result=$(python3 -c "import json; d=json.load(open('$DAILY_DOCS_CONFIG')); print(d['docs']['$1']['tabs']['$2'])" 2>/dev/null) || {
        echo "[get_doc_tab] ERROR: Tab '$2' under doc '$1' not found" >&2
        return 1
    }
    echo "$result"
}

# get_doc_setting <doc_key> <setting_key> [default] — returns a scalar setting (e.g., archive_days)
#   Example: get_doc_setting ai_playbook archive_days 7
get_doc_setting() {
    local result
    local default_val="${3:-}"
    result=$(python3 -c "
import json, sys
d = json.load(open('$DAILY_DOCS_CONFIG'))
val = d.get('docs', {}).get('$1', {}).get('$2')
if val is None:
    sys.exit(1)
print(val)
" 2>/dev/null) || {
        if [ -n "$default_val" ]; then
            echo "$default_val"
            return 0
        fi
        echo "[get_doc_setting] ERROR: Setting '$2' under doc '$1' not found and no default provided" >&2
        return 1
    }
    echo "$result"
}

# get_gchat_space <key> — returns a GChat space ID (e.g., "briefing", "ot_quick_wins")
get_gchat_space() {
    local result
    result=$(python3 -c "import json; d=json.load(open('$DAILY_DOCS_CONFIG')); print(d['gchat_spaces']['$1'])" 2>/dev/null) || {
        echo "[get_gchat_space] ERROR: Space '$1' not found" >&2
        return 1
    }
    echo "$result"
}

# ─── Pipeline Checkpoints ──────────────────────────────────────────────────
# Detects when code blocks are silently skipped (e.g., missing fi, bad nesting).
# Each critical phase calls pipeline_checkpoint "phase-name".
# Before writing heartbeat, call pipeline_verify to confirm all expected phases ran.
_PIPELINE_EXPECTED=()
_PIPELINE_REACHED=()

pipeline_expect() {
    _PIPELINE_EXPECTED=("$@")
    _PIPELINE_REACHED=()
}

pipeline_checkpoint() {
    _PIPELINE_REACHED+=("$1")
}

pipeline_verify() {
    local job_name="$1"
    local missing=()
    for phase in "${_PIPELINE_EXPECTED[@]}"; do
        local found=false
        for reached in "${_PIPELINE_REACHED[@]}"; do
            [ "$reached" = "$phase" ] && found=true && break
        done
        $found || missing+=("$phase")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        local msg="Pipeline phases skipped: ${missing[*]} (reached: ${_PIPELINE_REACHED[*]:-none})"
        echo "$(date '+%Y-%m-%d %H:%M')   [PIPELINE FAULT] $msg"
        cron_alert "$job_name" "Silent skip detected — $msg"
        return 1
    fi
    return 0
}

# ─── Self-Healing ──────────────────────────────────────────────────────────
# Call cron_self_heal at the start of any cron script to auto-fix common issues.
# Fixes: stale lock files, missing dirs, hung google-mux, dead processes.

cron_self_heal() {
    local job_name="${1:-unknown}"
    local fixes=0

    # 1. Ensure file-lock dir exists (survives /tmp cleanup)
    mkdir -p /tmp/claude-file-locks 2>/dev/null && fixes=$((fixes + 0)) || true

    # 2. Clean stale lock files (older than 5 min, owner dead)
    if [ -d /tmp/claude-file-locks ]; then
        for lock in /tmp/claude-file-locks/*.lock; do
            [ -d "$lock" ] || continue
            local owner_pid=""
            [ -f "$lock/pid" ] && owner_pid=$(cat "$lock/pid" 2>/dev/null)
            if [ -n "$owner_pid" ] && ! kill -0 "$owner_pid" 2>/dev/null; then
                rm -rf "$lock" 2>/dev/null
                fixes=$((fixes + 1))
            elif [ -z "$owner_pid" ]; then
                local age=$(( $(date +%s) - $(stat -c %Y "$lock" 2>/dev/null || echo "$(date +%s)") ))
                if [ "$age" -gt 300 ]; then
                    rm -rf "$lock" 2>/dev/null
                    fixes=$((fixes + 1))
                fi
            fi
        done
    fi

    # 3. Clean stale job-level lock files (from crashed runs)
    local own_lockfile="/tmp/cron-${job_name}.lock"
    if [ -f "$own_lockfile" ]; then
        local lock_pid
        lock_pid=$(cat "$own_lockfile" 2>/dev/null)
        if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -f "$own_lockfile"
            fixes=$((fixes + 1))
        fi
    fi

    # 4. Check google-mux health (non-blocking)
    if ! timeout 5 google-mux health 2>/dev/null | grep -q "ok\|running\|healthy" 2>/dev/null; then
        # Don't restart — just note it. Keepalive cron handles restarts.
        echo "$(date '+%Y-%m-%d %H:%M') [$job_name] [self-heal] google-mux unresponsive (keepalive will handle)" >&2
    fi

    [ "$fixes" -gt 0 ] && echo "$(date '+%Y-%m-%d %H:%M') [$job_name] [self-heal] Fixed $fixes issue(s)" >&2
    return 0
}

# ─── Daily Cron Health Metrics ────────────────────────────────────────────
# Records per-job success/failure to a daily metrics file.
# Format: YYYY-MM-DD | job-name | result | duration_s | fix_applied
# Call: cron_record_metric "job-name" "success|failure" duration_secs ["fix_applied"]
# Metrics file: ~/work/claude/state/CRON-HEALTH-METRICS.md

CRON_METRICS_FILE="${CLAUDE_STATE_DIR}/CRON-HEALTH-METRICS.md"

cron_record_metric() {
    local job_name="$1" result="$2" duration="${3:-0}" fix_applied="${4:-none}"
    local today
    today=$(date '+%Y-%m-%d')
    local timestamp
    timestamp=$(date '+%H:%M')

    # Guard against double-recording
    export _CRON_METRIC_RECORDED="$job_name"

    # Initialize metrics file with header if missing
    if [ ! -f "$CRON_METRICS_FILE" ]; then
        cat > "$CRON_METRICS_FILE" << 'METRICSEOF'
# Cron Health Metrics

Daily per-job success/failure tracking. Auto-generated by cron_record_metric().
Measure: per-job daily success rate trending toward 100%.

| Date | Time | Job | Result | Duration | Fix Applied |
|------|------|-----|--------|----------|-------------|
METRICSEOF
    fi

    # Append the metric row
    echo "| $today | $timestamp | $job_name | $result | ${duration}s | $fix_applied |" >> "$CRON_METRICS_FILE"

    # Also update cron_track_result for streak tracking
    local exit_code=0
    [ "$result" = "failure" ] && exit_code=1
    cron_track_result "$job_name" "$exit_code"
}

# Helper: compute daily success rate for a job (last N days)
cron_success_rate() {
    local job_name="$1" days="${2:-7}"
    [ ! -f "$CRON_METRICS_FILE" ] && echo "no data" && return
    local cutoff
    cutoff=$(date -d "-${days} days" '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d')
    python3 -c "
import sys
job, cutoff = sys.argv[1], sys.argv[2]
total = success = 0
for line in open(sys.argv[3]):
    if '|' not in line or 'Date' in line or '---' in line: continue
    parts = [p.strip() for p in line.split('|')]
    if len(parts) < 6: continue
    date, j, result = parts[1], parts[3], parts[4]
    if j != job or date < cutoff: continue
    total += 1
    if result == 'success': success += 1
if total == 0: print('no data')
else: print(f'{success}/{total} ({100*success//total}%)')
" "$job_name" "$cutoff" "$CRON_METRICS_FILE" 2>/dev/null || echo "error"
}

# ─── Auto-Correct Known Failures ─────────────────────────────────────────
# Called after a job failure. Attempts to match the error against known
# patterns and apply a fix. Returns 0 if a fix was applied (caller should retry).
#
# Usage:
#   if ! run_job; then
#       if cron_auto_correct "job-name" "$stderr_output"; then
#           run_job  # retry after fix
#       fi
#   fi

cron_auto_correct() {
    local job_name="$1" stderr="${2:-}"
    local fix_applied=""

    # Pattern 1: file-lock dir missing (common after /tmp cleanup)
    if echo "$stderr" | grep -qiE "mkdir.*claude-file-locks|file.lock.*no such"; then
        mkdir -p /tmp/claude-file-locks 2>/dev/null
        rm -rf /tmp/claude-file-locks/*.lock 2>/dev/null
        fix_applied="mkdir-file-locks"
    fi

    # Pattern 2: google-mux hung or unresponsive
    if echo "$stderr" | grep -qiE "google-mux.*timeout|gmux.*hang|pipe_read|anon_pipe"; then
        pkill -f "google-mux" 2>/dev/null
        sleep 2
        nohup google-mux daemon start >/dev/null 2>&1 &
        sleep 3
        fix_applied="restart-gmux"
    fi

    # Pattern 3: cert expired
    if echo "$stderr" | grep -qiE "Could not authenticate|FBID identity|certificate.*expir|x509.*error|Kerberos"; then
        clicat create 2>/dev/null
        sleep 2
        fix_applied="clicat-create"
    fi

    # Pattern 4: stale lock file blocking job
    if echo "$stderr" | grep -qiE "Lock file exists|Another instance running|lock.*stale"; then
        rm -f "/tmp/cron-${job_name}.lock" 2>/dev/null
        rm -rf /tmp/claude-file-locks/*.lock 2>/dev/null
        fix_applied="clean-stale-locks"
    fi

    # Pattern 5: /tmp work dir missing or full
    if echo "$stderr" | grep -qiE "No space left|cannot create temp|mktemp.*failed"; then
        find /tmp -maxdepth 1 -name "gdoc-comments-*" -mmin +120 -exec rm -rf {} \; 2>/dev/null || true
        find /tmp -maxdepth 1 -name "ot-support-triage-*" -mmin +120 -exec rm -rf {} \; 2>/dev/null || true
        find /tmp -maxdepth 1 -name "cron-*" -mmin +120 -type d -exec rm -rf {} \; 2>/dev/null || true
        fix_applied="clean-tmp"
    fi

    if [ -n "$fix_applied" ]; then
        echo "$(date '+%Y-%m-%d %H:%M') [$job_name] [auto-correct] Applied fix: $fix_applied" >&2
        error_pattern_log "$job_name" 1 "$fix_applied" "$fix_applied" "pending" "$stderr" 2>/dev/null || true
        return 0  # fix applied — caller should retry
    fi
    return 1  # no matching pattern
}

# ─── Consecutive Failure Detection ────────────────────────────────────────
# Tracks consecutive failures. After N failures, raises a high-priority alert.
# Call: cron_track_result "job-name" $exit_code

cron_track_result() {
    local job_name="$1" exit_code="$2"
    local streak_file="$CLAUDE_STATE_DIR/cron-fail-streak-${job_name}"
    local alert_threshold=3  # alert after 3 consecutive failures

    # Auto-record metric (if not already recorded by the caller)
    # Uses _CRON_METRIC_RECORDED guard to avoid double-recording
    if [ "${_CRON_METRIC_RECORDED:-}" != "$job_name" ]; then
        local result="success"
        [ "$exit_code" -ne 0 ] && result="failure"
        cron_record_metric "$job_name" "$result" "${JOB_DURATION:-0}" 2>/dev/null || true
    fi

    if [ "$exit_code" -eq 0 ]; then
        # Success — reset streak
        rm -f "$streak_file"
    else
        # Failure — increment streak
        local current=0
        [ -f "$streak_file" ] && current=$(cat "$streak_file" 2>/dev/null | head -1)
        current=$((current + 1))
        echo "$current" > "$streak_file"
        if [ "$current" -eq "$alert_threshold" ]; then
            cron_alert "$job_name" "CONSECUTIVE FAILURE #${current}: job has failed $current times in a row. Investigate immediately."
        fi
    fi
}

# ─── Error Pattern Database ─────────────────────────────────────────────────
# Logs every failure with diagnosis, fix attempted, and whether retry succeeded.
# Enables: (1) auto-learning new error patterns, (2) tracking fix effectiveness,
# (3) surfacing recurring unfixed errors for follow-up.

error_pattern_log() {
    local job_name="$1" exit_code="$2" diagnosis="$3" fix_applied="$4" retry_result="$5"
    local stderr_sample="${6:-}"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Initialize DB if missing
    if [ ! -f "$ERROR_PATTERN_DB" ]; then
        echo '{"patterns":[],"fix_stats":{}}' > "$ERROR_PATTERN_DB"
    fi

    # Categorize the error
    local category="unknown"
    case "$diagnosis" in
        *Timeout*)     category="timeout" ;;
        *Auth*)        category="auth" ;;
        *network*)     category="network" ;;
        *google-mux*)  category="gmux" ;;
        *File*)        category="vfs" ;;
        *cert*|*x509*) category="cert" ;;
        *command*not*found*|*exit=127*) category="missing_cmd" ;;
    esac

    # Extract error signature (first meaningful line from stderr)
    local signature=""
    if [ -n "$stderr_sample" ]; then
        signature=$(echo "$stderr_sample" | { grep -i -E 'error|fail|unable|cannot|denied|refused|timeout' || true; } | head -1 | cut -c1-120)
    fi

    # Append entry using python for safe JSON manipulation (pass data via temp file to avoid shell injection)
    local tmp_entry
    tmp_entry=$(mktemp)
    python3 -c "
import json, sys
json.dump({
    'db_path': sys.argv[1],
    'timestamp': sys.argv[2],
    'job_name': sys.argv[3],
    'exit_code': int(sys.argv[4]),
    'category': sys.argv[5],
    'diagnosis': sys.argv[6],
    'fix_applied': sys.argv[7],
    'retry_result': sys.argv[8],
    'signature': sys.argv[9]
}, open(sys.argv[10], 'w'))
" "$ERROR_PATTERN_DB" "$timestamp" "$job_name" "$exit_code" "$category" \
  "$diagnosis" "$fix_applied" "$retry_result" "$signature" "$tmp_entry" 2>/dev/null

    if [ -f "$tmp_entry" ] && [ -s "$tmp_entry" ]; then
        python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
db_path = data['db_path']
try:
    with open(db_path) as f:
        db = json.load(f)
except:
    db = {'patterns': [], 'fix_stats': {}}
entry = {
    'timestamp': data['timestamp'],
    'job': data['job_name'],
    'exit_code': data['exit_code'],
    'category': data['category'],
    'diagnosis': data['diagnosis'],
    'fix_applied': data['fix_applied'],
    'retry_succeeded': data['retry_result'] == 'success',
    'signature': data['signature']
}
db['patterns'].append(entry)
cat = data['category']
if cat not in db.get('fix_stats', {}):
    db['fix_stats'][cat] = {'attempts': 0, 'successes': 0}
db['fix_stats'][cat]['attempts'] += 1
if entry['retry_succeeded']:
    db['fix_stats'][cat]['successes'] += 1
db['patterns'] = db['patterns'][-200:]
with open(db_path, 'w') as f:
    json.dump(db, f, indent=2)
" "$tmp_entry" 2>/dev/null || true
    fi
    rm -f "$tmp_entry"
}

cron_alert() {
    local script_name="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M')"

    # Only write if ALERTS.md exists and is writable
    if [[ ! -f "$ALERTS_FILE" ]]; then
        echo "[cron-alert] ALERTS.md not found at $ALERTS_FILE — skipping alert"
        return 0
    fi

    # Lock ALERTS.md to prevent concurrent cron jobs from corrupting it
    # (read→transform→write is not atomic without locking)
    source "${BASH_SOURCE[0]%/*}/file-lock.sh" 2>/dev/null || true
    file_lock "ALERTS.md" 2>/dev/null || true

    # Check if an identical alert already exists (avoid duplicates from repeated cron runs)
    if grep -qF "[cron:${script_name}]" "$ALERTS_FILE" 2>/dev/null; then
        # Update the existing alert timestamp (don't add a duplicate, but keep it fresh)
        local tmp_alerts
        tmp_alerts=$(mktemp)
        awk -v tag="[cron:${script_name}]" -v newline="- **${timestamp}** [cron:${script_name}] ${message}" '
            index($0, tag) > 0 { print newline; next }
            { print }
        ' "$ALERTS_FILE" > "$tmp_alerts" && mv "$tmp_alerts" "$ALERTS_FILE"
        file_unlock "ALERTS.md" 2>/dev/null || true
        return 0
    fi

    # Insert alert after "## Active Alerts" line using temp file (safe for any characters in message)
    local alert_line="- **${timestamp}** [cron:${script_name}] ${message}"
    local tmp_alerts
    tmp_alerts=$(mktemp)
    awk -v line="$alert_line" '
        /^\(none\)$/ { next }
        { print }
        /^## Active Alerts/ { print line }
    ' "$ALERTS_FILE" > "$tmp_alerts" && mv "$tmp_alerts" "$ALERTS_FILE"

    file_unlock "ALERTS.md" 2>/dev/null || true
    echo "[cron-alert] Alert written to ALERTS.md: ${message}"
}

# Load cheatsheet content for injection into Claude -p prompts.
# Cron-spawned Claude sessions don't load CLAUDE.md or cheatsheets automatically.
# Supports both old names (gdocs, diff-common) and new folder paths (gdocs/rules, diff/common).
# Usage: GDOCS_CHEATSHEET=$(load_cheatsheet gdocs)
#        DIFF_CHEATSHEET=$(load_cheatsheet diff-common)
load_cheatsheet() {
    local name="$1"
    local repo_dir="${REPO_DIR:-$HOME/work/claude}"

    # Map old names to new folder paths
    local file=""
    case "$name" in
        gdocs)           file="${repo_dir}/cheatsheets/gdocs/rules.md" ;;
        diff-common)     file="${repo_dir}/cheatsheets/diff/common.md" ;;
        diff-review)     file="${repo_dir}/cheatsheets/diff/review.md" ;;
        sev)             file="${repo_dir}/cheatsheets/oncall/sev.md" ;;
        oncall)          file="${repo_dir}/cheatsheets/oncall/assessment.md" ;;
        mast-debugging)  file="${repo_dir}/cheatsheets/oncall/mast-debugging.md" ;;
        psc)             file="${repo_dir}/cheatsheets/career/psc.md" ;;
        deep-research)   file="${repo_dir}/cheatsheets/research/deep-research.md" ;;
        workflow-design) file="${repo_dir}/cheatsheets/agents/workflow-design.md" ;;
        *)               file="${repo_dir}/cheatsheets/cheatsheet-${name}.md" ;;  # fallback for unknown names
    esac

    if [ -f "$file" ]; then
        printf '## %s Cheatsheet (read before operations)\n\n%s\n\n---\n\n' "$name" "$(cat "$file")"
        # Create prerequisite sentinels for ALL possible session scopes.
        # Cron-spawned Claude sessions don't have CLAUDE_CODE_CURRENT_SESSION_ID,
        # so enforce-prerequisites.sh falls back to $$. Since the cron script's PID
        # differs from the spawned Claude session's PID, we create sentinels for
        # the cron PID AND write a global fallback that enforce-prerequisites.sh
        # checks when its session-scoped sentinel is missing.
        # ONLY create sentinel for the cheatsheet actually loaded (not all)
        local sentinel_dir="/tmp/claude-prereq-$$"
        mkdir -p "$sentinel_dir"
        mkdir -p "/tmp/claude-prereq-cron"
        case "$name" in
            gdocs)
                date +%s > "$sentinel_dir/gdocs" 2>/dev/null || true
                date +%s > "/tmp/claude-prereq-cron/gdocs" 2>/dev/null || true
                ;;
            diff-common)
                date +%s > "$sentinel_dir/diff" 2>/dev/null || true
                date +%s > "/tmp/claude-prereq-cron/diff" 2>/dev/null || true
                ;;
            diff-review)
                date +%s > "$sentinel_dir/diff-review" 2>/dev/null || true
                date +%s > "/tmp/claude-prereq-cron/diff-review" 2>/dev/null || true
                ;;
        esac
    fi
}

# Create preflight sentinels for cron-spawned Claude sessions that may submit diffs.
# Cron sessions can't do interactive self-review, so the cron script acts as the reviewer.
# Writes to a cron-scoped directory that bash-guard.sh checks as fallback.
# Usage: create_preflight_sentinels
create_preflight_sentinels() {
    # Write to cron fallback directory (bash-guard.sh checks session-scoped first, then cron)
    local marker_dir="/tmp/claude-preflight-cron"
    mkdir -p "$marker_dir"
    echo "VERIFIED:self-review:$(date +%s):cron" > "$marker_dir/self-review-ok"
    echo "VERIFIED:lint:$(date +%s):cron" > "$marker_dir/lint-ok"
}
# Usage: gdocs_retry <max_retries> <delay_secs> gdocs <args...>
# Retries on auth/token/DCAT errors. Refreshes DCAT token between attempts.
gdocs_retry() {
    local max_retries="${1:-3}"
    local delay="${2:-10}"
    shift 2

    local attempt=0
    local exit_code=0
    local output=""

    while [ "$attempt" -lt "$max_retries" ]; do
        attempt=$((attempt + 1))
        output=$(timeout 30 "$@" < /dev/null 2>&1) && { echo "$output"; return 0; }
        exit_code=$?

        # Check if it's an auth-related failure worth retrying
        if echo "$output" | grep -q -i -E 'DCAT|auth|token|credential|certificate|SSL|handshake|503|502|500|unavailable|timeout|untrusted'; then
            echo "[gdocs_retry] Attempt $attempt/$max_retries failed (auth/transient). Retrying in ${delay}s..." >&2
            # Restart daemon to clear wedged state (dcat may not exist)
            pkill -9 -f "google-mux daemon" 2>/dev/null || true
            sleep "$delay"
        else
            # Non-auth failure — don't retry
            echo "$output" >&2
            return $exit_code
        fi
    done

    echo "[gdocs_retry] All $max_retries attempts failed" >&2
    echo "$output" >&2
    return $exit_code
}

# Shared google-mux health gate. Call at the top of any gdocs-dependent job.
# Returns 0 (healthy) or 1 (broken — caller should exit/alert).
# Fixes: kill duplicate daemons, verify socket responds within 5s.
ensure_gmux_healthy() {
    if ! command -v google-mux &>/dev/null; then
        return 1
    fi

    # Kill duplicate daemons (common cause of hangs)
    local daemon_count
    daemon_count=$(pgrep -c 'google-mux' 2>/dev/null) || daemon_count=0
    if [ "${daemon_count:-0}" -gt 1 ]; then
        pkill -9 'google-mux' 2>/dev/null || true
        rm -f /tmp/gmux-"$USER"*.sock
        sleep 2
        echo "[gmux] Killed $daemon_count duplicate daemons + removed stale sockets"
    fi

    # Verify daemon responds — use gdocs probe
    local gmux_ok=false
    local probe_out
    if probe_out=$(timeout 10 gdocs tabs list "$(get_doc_id routine)" --untrusted-authors-mode 2>&1) && echo "$probe_out" | grep -q "TAB ID"; then
        gmux_ok=true
    else
        # Full cleanup: kill ALL google-mux, remove ALL stale sockets, retry
        pkill -9 'google-mux' 2>/dev/null || true
        rm -f /tmp/gmux-"$USER"*.sock
        sleep 3
        if probe_out=$(timeout 10 gdocs tabs list "$(get_doc_id routine)" --untrusted-authors-mode 2>&1) && echo "$probe_out" | grep -q "TAB ID"; then
            gmux_ok=true
            echo "[gmux] Daemon restarted and responsive"
        fi
    fi

    if $gmux_ok; then
        return 0
    else
        echo "[gmux] NOT responsive after restart — gdocs calls will fail"
        return 1
    fi
}

# Provenance header for auto-generated Google Docs.
# Inserts after the <h1> title so readers know where the content came from.
#
# Usage: gdoc_provenance "cron-nightly-routine-preprocessing.sh" "daily 2am"
# Returns: HTML string to insert after <h1>
gdoc_provenance() {
    local script_name="$1"
    local frequency="${2:-}"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M %Z')"
    local freq_str=""
    [ -n "$frequency" ] && freq_str=" ($frequency)"
    echo "<p><i>Generated by: ${script_name}${freq_str} | Source: ~/work/claude/scripts/${script_name} | Last updated: ${ts}</i></p>"
}

# Process-group-aware timeout for `claude -p` subprocesses.
# Fixes: `timeout N claude -p` leaves the native claude binary running indefinitely.
# Root cause: timeout only SIGKILLs the direct child; grandchild native binary survives.
# Fix: start_new_session=True creates a process group, os.killpg kills the whole tree.
#
# Usage: run_claude_with_timeout <seconds> <log_file> claude -p "prompt" [args...]
run_claude_with_timeout() {
    local timeout_secs="$1"
    shift
    local log_file="$1"
    shift
    # Trap SIGPIPE for the duration of this function. When the timeout kills
    # the Claude process group, orphaned children writing to closed pipes
    # generate SIGPIPE. Under set -eo pipefail, this kills the entire script
    # (exit 141 = 128+13). Trapping here protects ALL callers at once.
    local _prev_sigpipe
    _prev_sigpipe=$(trap -p SIGPIPE)
    trap '' SIGPIPE
    # Remaining args: the full claude command
    python3 -c "
import subprocess, signal, os, sys
timeout_s = int(sys.argv[1])
log_path = sys.argv[2]
cmd = sys.argv[3:]
proc = subprocess.Popen(
    cmd,
    stdout=open(log_path, 'w', encoding='utf-8'),
    stderr=subprocess.STDOUT,
    start_new_session=True
)
try:
    proc.wait(timeout=timeout_s)
except subprocess.TimeoutExpired:
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()
    sys.exit(124)
sys.exit(proc.returncode)
" "$timeout_secs" "$log_file" "$@"
    local _rc=$?
    # Restore previous SIGPIPE handler
    if [ -n "$_prev_sigpipe" ]; then
        eval "$_prev_sigpipe"
    else
        trap - SIGPIPE
    fi
    return $_rc
}

# Preflight: fix known failure causes BEFORE running the script.
# Fast (~2s total). Repairs what it can, skips what it can't.
cron_preflight() {
    # 1. google-mux daemon — if dead, gdocs/gchat calls all fail.
    #    Can't create auth from cron, but can restart a stuck daemon.
    if command -v google-mux &>/dev/null; then
        local gmux_pids
        # Use pgrep -c (no -f) to match on process name only — avoids self-matching
        gmux_pids=$(pgrep -c 'google-mux' 2>/dev/null) || gmux_pids=0
        if [ "$gmux_pids" -gt 1 ]; then
            # Multiple daemons = socket contention = hangs. Kill all, let next call auto-start.
            echo "[preflight] $gmux_pids google-mux daemons running — killing duplicates"
            pkill -9 'google-mux' 2>/dev/null || true
            sleep 1
        fi
    fi

    # 2. Stale lock files from prior crashed runs (>2h old)
    for lockfile in /tmp/cron-lock-*; do
        [ -f "$lockfile" ] || continue
        local lock_age=$(( $(date +%s) - $(stat -c %Y "$lockfile" 2>/dev/null || echo "0") ))
        if [ "$lock_age" -gt 7200 ]; then
            local lock_pid
            lock_pid=$(cat "$lockfile" 2>/dev/null || echo "")
            if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
                echo "[preflight] Killing stale lock holder pid=$lock_pid (age=${lock_age}s) for $lockfile"
                kill "$lock_pid" 2>/dev/null || true
                sleep 1
                kill -9 "$lock_pid" 2>/dev/null || true
            fi
            rm -f "$lockfile"
            echo "[preflight] Removed stale lock $lockfile"
        fi
    done
}

# Diagnose failure from exit code + stderr, apply targeted fix.
# Returns 0 if a fix was applied (worth retrying), 1 if not.
cron_diagnose_and_fix() {
    local exit_code="$1"
    local stderr_file="$2"
    local stderr_sample
    stderr_sample=$(tail -20 "$stderr_file" 2>/dev/null || echo "")

    # Timeout — likely hung on network or daemon. Kill zombie children, restart daemon.
    if [ "$exit_code" -eq 124 ]; then
        echo "[diagnose] Timeout — killing zombie children, restarting daemon"
        pkill -9 -f "google-mux daemon" 2>/dev/null || true
        sleep 1
        return 0
    fi

    # Auth/DCAT/token failure — daemon might be wedged
    if echo "$stderr_sample" | grep -q -i -E 'DCAT|auth|token|credential|untrusted|Access denied'; then
        echo "[diagnose] Auth failure detected — restarting google-mux daemon"
        pkill -9 -f "google-mux daemon" 2>/dev/null || true
        sleep 1
        return 0
    fi

    # Network transient — DNS, connection refused, 502/503
    if echo "$stderr_sample" | grep -q -i -E 'DNS|resolve|refused|502|503|unavailable|reset by peer'; then
        echo "[diagnose] Transient network error — retrying after 5s"
        sleep 5
        return 0
    fi

    # google-mux not responsive — daemon might be wedged or restarting
    if echo "$stderr_sample" | grep -q -i -E 'google-mux not responsive|gmux.*not.*responsive|socket.*not found'; then
        echo "[diagnose] google-mux not responsive — full cleanup + restart"
        pkill -9 'google-mux' 2>/dev/null || true
        rm -f /tmp/gmux-"$USER"*.sock
        sleep 3
        return 0
    fi

    # Generic exit=1 with gdocs/google-mux in the call stack — likely stale socket
    # This catches the case where gdocs replace hangs for 18 min then fails silently
    if [ "$exit_code" -eq 1 ]; then
        echo "[diagnose] Generic exit=1 — restarting google-mux as precaution"
        pkill -9 'google-mux' 2>/dev/null || true
        rm -f /tmp/gmux-"$USER"*.sock
        sleep 3
        return 0
    fi

    # x509 cert missing — copy confucius cert as workaround
    # Only match ECONNRESET if the cert file is actually missing (not generic network resets)
    local cert_missing=false
    local agent_x509="/var/facebook/credentials/$USER/agent_x509"
    [ ! -f "$agent_x509/claude_code_${USER}.pem" ] && cert_missing=true

    if echo "$stderr_sample" | grep -q -i -E 'x509|certificate not found|Unable to read file.*\.pem'; then
        cert_missing=true  # explicit cert error
    fi

    if $cert_missing && echo "$stderr_sample" | grep -q -i -E 'x509|certificate not found|Unable to read file.*\.pem|ECONNRESET'; then
        echo "[diagnose] Cert issue — applying confucius cert workaround"
        if [ -f "$agent_x509/confucius.pem" ]; then
            cp "$agent_x509/confucius.pem" "$agent_x509/claude_code_${USER}.pem" 2>/dev/null || true
        fi
        export THRIFT_TLS_CL_CERT_PATH="$agent_x509/confucius.pem"
        export THRIFT_TLS_CL_KEY_PATH="$agent_x509/confucius.pem"
        return 0
    fi

    # File not found / VFS eviction — touch parent dir to trigger EdenFS prefetch
    if echo "$stderr_sample" | grep -q -i -E 'No such file|not found|ENOENT'; then
        echo "[diagnose] File missing (possible VFS eviction) — triggering prefetch"
        ls "$HOME/work/claude/scripts/" &>/dev/null || true
        ls "$HOME/work/claude/config/" &>/dev/null || true
        return 0
    fi

    # Exit 137 (SIGKILL/OOM) or 143 (SIGTERM) — kill zombie children, restart gmux
    if [ "$exit_code" = "137" ] || [ "$exit_code" = "143" ]; then
        echo "[diagnose] Signal kill (exit=$exit_code) — killing zombie children, restarting daemon"
        pkill -9 -f "google-mux daemon" 2>/dev/null || true
        rm -f /tmp/gmux-${USER}*.sock 2>/dev/null || true
        sleep 2
        # Kill zombie claude processes from THIS cron job only (not concurrent sessions).
        # PPID=$$ targets direct children; orphaned grandchildren are handled by timeout --foreground.
        pkill -9 -P $$ -f "claude.*-p" 2>/dev/null || true
        return 0
    fi

    # Unknown failure — no targeted fix available
    echo "[diagnose] Unknown failure (exit=$exit_code), no targeted fix"
    return 1
}

# ─── Standardized run logging ─────────────────────────────────────────────
# Every cron invocation writes BEGIN/END banners to its log file so we can
# trace boundaries, durations, and exit codes after the fact. Scripts can
# also call cron_log "msg" inside themselves for timestamped phase markers.
cron_log() {
    local msg="$1"
    local job="${CRON_JOB_NAME:-${0##*/}}"
    printf '%s [%s] [pid=%d] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$job" "$$" "$msg"
}

cron_log_begin() {
    local job="$1" pid="$2" attempt="${3:-1}"
    printf '\n====== BEGIN %s attempt=%d %s pid=%d ======\n' \
        "$job" "$attempt" "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$pid"
}

cron_log_end() {
    local job="$1" exit_code="$2" duration="$3" attempt="${4:-1}"
    printf '====== END   %s attempt=%d %s exit=%d duration=%ds ======\n\n' \
        "$job" "$attempt" "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$exit_code" "$duration"
}

# Timeout + diagnose + retry wrapper for cron jobs.
# Usage (in crontab): source cron-alert.sh && cron_run <timeout_secs> <name> <script>
#
# Flow:
#   1. Preflight — fix known causes before running (daemon, stale locks)
#   2. Attempt 1 — run with timeout, capture stderr (BEGIN/END banners)
#   3. On failure: diagnose stderr, apply targeted fix, retry (BEGIN/END banners)
#   4. On final failure: alert to ALERTS.md
#   5. On success (including retry): clear prior alerts
cron_run() {
    local timeout_secs="$1"
    local script_name="$2"
    local script_path="$3"
    shift 3
    local script_args="$*"  # Pass remaining args to the script
    local stderr_file
    stderr_file=$(mktemp)
    local runtime_log="${RUNTIME_LOG:-$HOME/logs/cron-runtime.csv}"
    # shellcheck disable=SC2064
    trap "rm -f '$stderr_file'" RETURN

    # Preflight — fix known issues before we start
    cron_preflight

    local start_ts
    start_ts=$(date +%s)

    # Attempt 1
    # --foreground: timeout creates a process group, kills the ENTIRE group on expiry.
    # Without this, child processes (Claude sessions) survive as orphans after timeout.
    # Export CRON_JOB_NAME so scripts invoked under an alias (e.g. gdoc-comments-critical
    # using cron-gdoc-comments.sh) write their heartbeats + alerts under the alias.
    export CRON_JOB_NAME="$script_name"
    cron_log_begin "$script_name" "$$" 1
    timeout --foreground --kill-after=10 "$timeout_secs" bash "$script_path" $script_args 2>"$stderr_file"
    local exit1=$?

    # Runtime tracking — append one line per run for timeout calibration
    local duration=$(( $(date +%s) - start_ts ))
    cron_log_end "$script_name" "$exit1" "$duration" 1
    local output_size=0
    [ -f "$stderr_file" ] && output_size=$(wc -c < "$stderr_file" 2>/dev/null || echo 0)
    if [ ! -f "$runtime_log" ]; then
        echo "date,job,exit_code,duration_secs,attempt" > "$runtime_log"
    fi
    echo "$(date '+%Y-%m-%d %H:%M'),$script_name,$exit1,$duration,1" >> "$runtime_log"

    if [ "$exit1" -eq 0 ]; then
        write_heartbeat "$script_name"   # centralized: every job gets a heartbeat on success
        cron_alert_clear "$script_name"
        return 0
    fi

    local reason="exit=$exit1"
    [ "$exit1" -eq 124 ] && reason="TIMEOUT(${timeout_secs}s)"
    echo "$(date '+%Y-%m-%d %H:%M') [cron_run] $script_name: FAIL ($reason) — diagnosing..."

    # Dump stderr to stdout (log file) so failures are diagnosable
    if [ -s "$stderr_file" ]; then
        echo "$(date '+%Y-%m-%d %H:%M') [cron_run] $script_name: stderr (last 10 lines):"
        tail -10 "$stderr_file" 2>/dev/null | sed 's/^/  /'
    fi

    # Diagnose and fix — if no fix available, don't waste time retrying
    # Run in current shell (not subshell) so env var exports (cert fix) propagate to retry
    local diagnose_output_file
    diagnose_output_file=$(mktemp)
    local diagnose_exit=0
    cron_diagnose_and_fix "$exit1" "$stderr_file" > "$diagnose_output_file" 2>&1 || diagnose_exit=$?
    local diagnose_output
    diagnose_output=$(cat "$diagnose_output_file")
    rm -f "$diagnose_output_file"
    echo "$diagnose_output"

    if [ "$diagnose_exit" -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M') [cron_run] $script_name: no fix available, skipping retry"
        local stderr_sample
        stderr_sample=$(tail -5 "$stderr_file" 2>/dev/null || echo "")
        error_pattern_log "$script_name" "$exit1" "$diagnose_output" "none" "failed" "$stderr_sample"
        cron_alert "$script_name" "$reason (no retryable cause found)"
        return $exit1
    fi

    # Attempt 2 — retry after targeted fix
    echo "$(date '+%Y-%m-%d %H:%M') [cron_run] $script_name: retrying after fix..."
    local start_ts2
    start_ts2=$(date +%s)
    cron_log_begin "$script_name" "$$" 2
    timeout --foreground --kill-after=10 "$timeout_secs" bash "$script_path" $script_args 2>"$stderr_file"
    local exit2=$?
    local duration2=$(( $(date +%s) - start_ts2 ))
    cron_log_end "$script_name" "$exit2" "$duration2" 2
    echo "$(date '+%Y-%m-%d %H:%M'),$script_name,$exit2,$duration2,2" >> "$runtime_log"

    if [ "$exit2" -eq 0 ]; then
        write_heartbeat "$script_name"   # centralized: every job gets a heartbeat on success
        cron_alert_clear "$script_name"
        echo "$(date '+%Y-%m-%d %H:%M') [cron_run] $script_name: retry PASSED"
        error_pattern_log "$script_name" "$exit1" "$diagnose_output" "applied" "success" ""
        return 0
    fi

    local reason2="exit=$exit2"
    [ "$exit2" -eq 124 ] && reason2="TIMEOUT(${timeout_secs}s)"
    echo "$(date '+%Y-%m-%d %H:%M') [cron_run] $script_name: retry FAIL ($reason2)"
    local stderr_sample2
    stderr_sample2=$(tail -5 "$stderr_file" 2>/dev/null || echo "")
    error_pattern_log "$script_name" "$exit1" "$diagnose_output" "applied" "failed" "$stderr_sample2"
    cron_alert "$script_name" "2 attempts failed: attempt1=$reason attempt2=$reason2"
    return $exit2
}

# Clear a previously raised cron alert (call on success after a prior failure)
cron_alert_clear() {
    local script_name="$1"

    if [[ ! -f "$ALERTS_FILE" ]]; then
        return 0
    fi

    if grep -qF "[cron:${script_name}]" "$ALERTS_FILE" 2>/dev/null; then
        # Lock ALERTS.md to prevent concurrent modification
        source "${BASH_SOURCE[0]%/*}/file-lock.sh" 2>/dev/null || true
        file_lock "ALERTS.md" 2>/dev/null || true
        sed -i "/\[cron:${script_name}\]/d" "$ALERTS_FILE"
        # Restore (none) if no active alerts remain
        if ! grep -q "^- \*\*" "$ALERTS_FILE" 2>/dev/null; then
            sed -i "/## Active Alerts/a\\
(none)" "$ALERTS_FILE"
        fi
        file_unlock "ALERTS.md" 2>/dev/null || true
        echo "[cron-alert] Cleared alert for ${script_name}"
    fi
}
