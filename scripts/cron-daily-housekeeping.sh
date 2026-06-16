#!/bin/bash
# cron-daily-housekeeping.sh — Daily housekeeping: validate, scan, anti-sprawl, backup, clean, sync.
#
# Merges cron-self-check.sh, cron-file-health.sh, and cron-daily-maintenance.sh into one job.
# Runs daily at 1:00 AM via crontab.
#
# Sections:
#   1. Validate — scripts exist, FOLLOWUPS health, config consistency, cache/context budgets, heartbeats, digest sprawl
#   2. Security — unicode injection scan (invisible tag chars, variation selectors, zero-width chars)
#   3. Scan — orphaned/stale/oversized .md file detection → FILE-HEALTH.md report
#   4. Anti-sprawl — PSC cap, startup files budget, ALERTS.md markers
#   5. Backup — workspace tar.gz, keep last 3, alert if >5MB
#   6. Clean — adaptive disk retention, session transcripts, /tmp artifacts, file-history, shell-snapshots
#   7. Git auto-commit — stage and commit all local changes nightly
#   8. Token audit — snapshot stats, per-script cost estimation, spike detection

set -euo pipefail
trap '' PIPE  # Ignore SIGPIPE — VFS and heredoc subshells can trigger it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cron-alert.sh"
ensure_gmux_healthy || echo "[WARN] google-mux unhealthy"

CLAUDE_DIR="$HOME/work/claude"
ALERTS_FILE="$CLAUDE_DIR/ALERTS.md"
EXCLUDE_FILE="$CLAUDE_DIR/config/EXCLUDE-PATTERNS.txt"
CONTEXT_DIR="$CLAUDE_DIR/context"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
LOCK_FILE="/tmp/cron-daily-housekeeping.lock"
issues=()

# Prevent overlapping runs — with max-age fallback for recycled PIDs
LOCK_MAX_AGE_SECONDS=3600  # 1 hour — housekeeping shouldn't take this long
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if [ "$lock_age" -gt "$LOCK_MAX_AGE_SECONDS" ]; then
            echo "$LOG_PREFIX Lock held by pid $pid for ${lock_age}s (>${LOCK_MAX_AGE_SECONDS}s) — killing stale process"
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
        else
            echo "$LOG_PREFIX Already running (pid $pid, age ${lock_age}s), skipping"
            exit 0
        fi
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; rm -rf "${TMP_DIR:-}"' EXIT

echo "$LOG_PREFIX === Daily Housekeeping ==="

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: Validate (from self-check)
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [1] Validate"

# ── 1a. Expected scripts exist ──────────────────────────────

EXPECTED_SCRIPTS=(
    "cron-alert.sh"
    "cron-daily-housekeeping.sh"
    "cron-nightly-routine-preprocessing.sh"
    "cron-keepalive.sh"
    "cron-area-monitor.sh"
    "cron-audit-agent.sh"
    "cron-weekly-report.sh"
    "cron-workflow-self-eval.sh"
    "cron-daily-progress.sh"
    "cron-meeting-prep.sh"
    "setup-claude.sh"
)

missing_scripts=()
for script in "${EXPECTED_SCRIPTS[@]}"; do
    if [ ! -f "$CLAUDE_DIR/scripts/$script" ]; then
        missing_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -gt 0 ]; then
    issues+=("Missing scripts (VFS eviction?): ${missing_scripts[*]}")
    echo "$LOG_PREFIX   [FAIL] Missing scripts: ${missing_scripts[*]}"
else
    echo "$LOG_PREFIX   [OK]   All ${#EXPECTED_SCRIPTS[@]} expected scripts present"
fi

# ── 1b. FOLLOWUPS.md overdue count + mechanical enforcement ──────────────────

FOLLOWUPS="$CLAUDE_DIR/FOLLOWUPS.md"
if [ -f "$FOLLOWUPS" ]; then
    today=$(date +%Y-%m-%d)
    overdue_count=0
    while IFS='|' read -r _ _ check_after _ _; do
        check_date=$(echo "$check_after" | tr -d ' ')
        if [[ "$check_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$check_date" < "$today" ]]; then
            overdue_count=$((overdue_count + 1))
        fi
    done < <(grep '| pending |' "$FOLLOWUPS" 2>/dev/null || true)

    stale_cutoff=$(date -d "-14 days" +%Y-%m-%d 2>/dev/null || date -v-14d +%Y-%m-%d 2>/dev/null || echo "")
    stale_followup_count=0
    if [ -n "$stale_cutoff" ]; then
        stale_followup_count=0
        while IFS='|' read -r _ _ check_after _ _; do
            check_date=$(echo "$check_after" | tr -d ' ')
            if [[ "$check_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$check_date" < "$stale_cutoff" ]]; then
                stale_followup_count=$((stale_followup_count + 1))
            fi
        done < <(grep '| pending |' "$FOLLOWUPS" 2>/dev/null || true)
    fi

    # Auto-drop stale items (overdue >14 days with status "pending" — missed check-after twice)
    if [ "$stale_followup_count" -gt 0 ] && [ -n "$stale_cutoff" ]; then
        echo "$LOG_PREFIX   [ENFORCE] Auto-dropping $stale_followup_count stale follow-ups (overdue >14 days)"
        # Move stale pending items from Active to Dropped section
        python3 -c "
import re, sys
from datetime import datetime, timedelta

cutoff = '$stale_cutoff'
lines = open('$FOLLOWUPS').readlines()
dropped = []
kept = []
in_active = False
for line in lines:
    if '## Active' in line:
        in_active = True
        kept.append(line)
        continue
    if line.startswith('## ') and in_active:
        in_active = False
    if in_active and '| pending |' in line:
        # Extract check-after date (3rd pipe field)
        fields = line.split('|')
        if len(fields) >= 4:
            check_date = fields[2].strip()
            if re.match(r'\d{4}-\d{2}-\d{2}', check_date) and check_date < cutoff:
                # Skip items with Meta Task references (T followed by 6+ digits)
                what_field = fields[3] if len(fields) > 3 else ''
                if re.search(r'T\d{6,}', what_field):
                    kept.append(line)  # Keep — has open Meta Task
                    continue
                dropped.append(line.rstrip())
                continue
    kept.append(line)

if dropped:
    # Find Dropped section and append
    result = ''.join(kept)
    drop_lines = '\n'.join(d + ' — auto-dropped (>14d overdue)' for d in dropped)
    if '## Dropped' in result:
        result = result.replace('## Dropped', '## Dropped\n\n' + drop_lines)
    else:
        result += '\n## Dropped\n\n' + drop_lines + '\n'
    with open('$FOLLOWUPS', 'w') as f:
        f.write(result)
    print(f'Dropped {len(dropped)} stale items')
" 2>/dev/null || echo "$LOG_PREFIX   [WARN] Auto-drop failed (python error)"
    fi

    # Cap enforcement: count active items
    # Only count items in Active section (not Personal or Dropped)
    # Subtract 2 for header row + separator row (both match the pipe pattern)
    active_section_count=$(sed -n '/^## Active/,/^## /p' "$FOLLOWUPS" | grep -c '|.*|.*|.*|' 2>/dev/null || echo 0)
    active_section_count=$((active_section_count > 2 ? active_section_count - 2 : 0))

    if [ "$active_section_count" -gt 10 ]; then
        issues+=("FOLLOWUPS.md has $active_section_count active items (cap: 10). Drop or complete items.")
        echo "$LOG_PREFIX   [WARN] FOLLOWUPS.md: $active_section_count active items OVER CAP (10)"
    elif [ "$stale_followup_count" -gt 0 ]; then
        issues+=("FOLLOWUPS.md has $stale_followup_count stale items (overdue >14 days). Auto-dropped.")
        echo "$LOG_PREFIX   [WARN] FOLLOWUPS.md: auto-dropped $stale_followup_count stale items, $overdue_count total overdue"
    elif [ "$overdue_count" -gt 5 ]; then
        issues+=("FOLLOWUPS.md has $overdue_count overdue items (>5 threshold). Prune or act.")
        echo "$LOG_PREFIX   [WARN] FOLLOWUPS.md: $overdue_count overdue items"
    else
        echo "$LOG_PREFIX   [OK]   FOLLOWUPS.md: $overdue_count overdue, $active_section_count active (cap: 10)"
    fi
else
    echo "$LOG_PREFIX   [SKIP] FOLLOWUPS.md not found"
fi

# ── 1c. CLAUDE.md / INFRASTRUCTURE.md consistency ──────────

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
INFRA_MD="$CLAUDE_DIR/config/INFRASTRUCTURE.md"
if [ -f "$CLAUDE_MD" ] && [ -f "$INFRA_MD" ]; then
    infra_host=$(grep -oP 'Claude Code runs on \*\*\K[^*]+' "$INFRA_MD" 2>/dev/null | head -1)
    claude_host=$(grep -oP 'Claude Code runs on \*\*\K[^*]+' "$CLAUDE_MD" 2>/dev/null | head -1)
    if [ -n "$infra_host" ] && [ -n "$claude_host" ] && [ "$infra_host" != "$claude_host" ]; then
        issues+=("CLAUDE.md says primary host is '$claude_host' but INFRASTRUCTURE.md says '$infra_host'")
        echo "$LOG_PREFIX   [FAIL] Host mismatch: CLAUDE.md='$claude_host' vs INFRASTRUCTURE.md='$infra_host'"
    else
        echo "$LOG_PREFIX   [OK]   Primary host consistent: ${infra_host:-unknown}"
    fi
fi

# ── 1d. Infrastructure reference validation ────────────────
# Catch missing files that CLAUDE.md, hooks, or scripts depend on.
# This prevents "hidden broken" infrastructure — things that look configured
# but silently fail because a referenced file doesn't exist.

INFRA_REFS_MISSING=()

# Config files referenced by agents or hooks
for config_ref in QUALITY-GATE.md AUTO-LEARNINGS.md; do
    if [ ! -f "$CLAUDE_DIR/config/$config_ref" ]; then
        INFRA_REFS_MISSING+=("config:${config_ref}")
    fi
done

# Cheatsheets referenced by load_cheatsheet calls in cron scripts
for cheat in gdocs diff-common diff-review; do
    if [ ! -f "$CLAUDE_DIR/cheatsheets/cheatsheet-${cheat}.md" ]; then
        INFRA_REFS_MISSING+=("cheatsheet:cheatsheet-${cheat}.md (used by load_cheatsheet in cron scripts)")
    fi
done

# Hook-referenced tools/scripts
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    # Check that scripts referenced in hooks exist
    for hook_script in $(grep -oP '(~|'"$HOME"')/work/claude/scripts/\K[a-z0-9_-]+\.sh' "$SETTINGS_FILE" 2>/dev/null | sort -u); do
        if [ ! -f "$CLAUDE_DIR/scripts/$hook_script" ]; then
            INFRA_REFS_MISSING+=("hook-script:$hook_script (referenced in settings.json but missing)")
        fi
    done
fi

# ── 1d1. settings.json symlink self-heal ───────────────────────
# Claude Code occasionally rewrites ~/.claude/settings.json as a REAL file
# (plugin install, /config, permission edits), clobbering the symlink to the
# repo copy. When that happens the live config silently drifts from the
# canonical ~/work/claude/.claude/settings.json — hooks edited in the repo
# never reach the running harness. Self-heal: if the live file is not a
# symlink to the repo copy, re-link it (backing up first if it diverged).
SETTINGS_SRC="$CLAUDE_DIR/.claude/settings.json"  # repo copy under ~/work/claude/
if [ -f "$SETTINGS_SRC" ]; then
    if [ "$(readlink -f "$SETTINGS_FILE" 2>/dev/null)" != "$(readlink -f "$SETTINGS_SRC" 2>/dev/null)" ]; then
        if [ -e "$SETTINGS_FILE" ] && ! diff -q "$SETTINGS_FILE" "$SETTINGS_SRC" >/dev/null 2>&1; then
            cp "$SETTINGS_FILE" "${SETTINGS_FILE}.drift-bak" 2>/dev/null || true
            echo "$LOG_PREFIX   [WARN] settings.json drifted from repo copy — backed up to ${SETTINGS_FILE}.drift-bak before re-link"
            issues+=("settings.json had drifted from repo copy (real file, not symlink); backup at ${SETTINGS_FILE}.drift-bak")
        fi
        ln -sf "$SETTINGS_SRC" "$SETTINGS_FILE"
        echo "$LOG_PREFIX   [FIX]  settings.json re-symlinked to repo copy ($SETTINGS_SRC)"
    else
        echo "$LOG_PREFIX   [OK]   settings.json symlink intact → repo copy"
    fi
fi

if [ ${#INFRA_REFS_MISSING[@]} -gt 0 ]; then
    issues+=("Missing infrastructure references: ${INFRA_REFS_MISSING[*]}")
    echo "$LOG_PREFIX   [FAIL] ${#INFRA_REFS_MISSING[@]} missing infrastructure reference(s):"
    for ref in "${INFRA_REFS_MISSING[@]}"; do
        echo "$LOG_PREFIX         - $ref"
    done
else
    echo "$LOG_PREFIX   [OK]   All infrastructure references valid"
fi

# ── 1d2. settings.json structural lint ─────────────────────────
# Validates JSON, dedupe, missing scripts, sync-hook count.
# rc=0 ok, rc=1 hard fail, rc=2 warn (>4 sync hooks).
if [ -x "$CLAUDE_DIR/scripts/lint-settings.sh" ] || [ -f "$CLAUDE_DIR/scripts/lint-settings.sh" ]; then
    lint_out=$(bash "$CLAUDE_DIR/scripts/lint-settings.sh" "$SETTINGS_FILE" 2>&1)
    lint_rc=$?
    if [ "$lint_rc" -eq 0 ]; then
        echo "$LOG_PREFIX   [OK]   settings.json lint: $lint_out"
    elif [ "$lint_rc" -eq 2 ]; then
        echo "$LOG_PREFIX   [WARN] settings.json lint: $lint_out"
        issues+=("settings.json lint warning: $lint_out")
    else
        echo "$LOG_PREFIX   [FAIL] settings.json lint: $lint_out"
        issues+=("settings.json lint failed: $lint_out")
    fi
fi

# ── 1e. context/ folder size budget ─────────────────────────
# Excludes operational/generated files (digests, journals, gchat, comms, state)
# that are gitignored and don't count toward the content budget.

if [ -d "$CONTEXT_DIR" ]; then
    context_kb=$(du -sk --exclude='cache/digests' --exclude='cache/journals' --exclude='cache/gchat' --exclude='cache/comms' --exclude='cache/state' "$CONTEXT_DIR" 2>/dev/null | awk '{print $1}')
    context_mb=$((context_kb / 1024))
    if [ "$context_mb" -ge 2 ]; then
        issues+=("context/ folder is ${context_mb}MB (budget: 2MB, excludes operational caches). Run cleanup.")
        echo "$LOG_PREFIX   [WARN] context/ is ${context_mb}MB (excluding operational caches)"
    else
        echo "$LOG_PREFIX   [OK]   context/ is ${context_mb}MB (excluding operational caches)"
    fi
fi

# ── 1e2. ~/work/claude/state/ retention (90-day pruning) ─────────────────────
# Operational state files accumulate — prune anything older than 90 days.
CLAUDE_STATE_DIR="$HOME/work/claude/state"
if [ -d "$CLAUDE_STATE_DIR" ]; then
    pruned=$({ find "$CLAUDE_STATE_DIR" -type f -mtime +90 -delete -print 2>/dev/null || true; } | wc -l)
    [ "$pruned" -gt 0 ] && echo "$LOG_PREFIX   Pruned $pruned files >90 days from ~/work/claude/state/"
fi

# ── 1f. Stale cache files (>7 days old) ─────────────────────

CACHE_DIR="$CLAUDE_DIR/context/cache"
if [ -d "$CACHE_DIR" ]; then
    stale_cache_count=$({ find "$CACHE_DIR" -maxdepth 1 -name "*.md" -mtime +7 2>/dev/null || true; } | wc -l)
    if [ "$stale_cache_count" -gt 3 ]; then
        issues+=("$stale_cache_count stale cache files (>7 days). Clean up context/cache/.")
        echo "$LOG_PREFIX   [WARN] $stale_cache_count stale cache files"
    else
        echo "$LOG_PREFIX   [OK]   Cache freshness: $stale_cache_count files >7 days old"
    fi
fi

# ── 1f2. Cache manifest lint — flag root files not in CACHE-MANIFEST.yaml ──

MANIFEST_FILE="$CACHE_DIR/CACHE-MANIFEST.yaml"
if [ -f "$MANIFEST_FILE" ]; then
    manifest_files=$(grep '  - file:' "$MANIFEST_FILE" | sed 's/.*file: //')
    unlisted_count=0
    for f in "$CACHE_DIR"/*.{md,json,yaml,txt} ; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        if ! echo "$manifest_files" | grep -qx "$fname"; then
            issues+=("Unlisted cache file: $fname — add to CACHE-MANIFEST.yaml or move to archive/")
            unlisted_count=$((unlisted_count + 1))
        fi
    done
    if [ "$unlisted_count" -gt 0 ]; then
        echo "$LOG_PREFIX   [WARN] $unlisted_count root cache file(s) not in manifest"
    else
        echo "$LOG_PREFIX   [OK]   All root cache files in manifest"
    fi
else
    echo "$LOG_PREFIX   [SKIP] CACHE-MANIFEST.yaml not found"
fi

# ── 1f3. Auto-archive dated files older than 7 days ──────────

ARCHIVE_DIR="$CACHE_DIR/archive"
mkdir -p "$ARCHIVE_DIR"
auto_archived=0
for f in "$CACHE_DIR"/*-2026-*.md "$CACHE_DIR"/*-20260*.md ; do
    [ -f "$f" ] || continue
    file_age_days=$(( ($(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo "0")) / 86400 ))
    if [ "$file_age_days" -gt 7 ]; then
        mv "$f" "$ARCHIVE_DIR/"
        auto_archived=$((auto_archived + 1))
    fi
done
[ "$auto_archived" -gt 0 ] && echo "$LOG_PREFIX   Auto-archived $auto_archived dated file(s) to archive/"

# ── 1f4. Archive purge — delete files older than 60 days ─────

if [ -d "$ARCHIVE_DIR" ]; then
    purged=$({ find "$ARCHIVE_DIR" -type f -mtime +60 -delete -print 2>/dev/null || true; } | wc -l)
    [ "$purged" -gt 0 ] && echo "$LOG_PREFIX   Purged $purged archive file(s) older than 60 days"
fi

# ── 1f5. Journal rotation — trim journals exceeding 500 lines ─

JOURNAL_DIR="$CACHE_DIR/journals"
if [ -d "$JOURNAL_DIR" ]; then
    for jfile in "$JOURNAL_DIR"/*.md; do
        [ -f "$jfile" ] || continue
        jlines=$(wc -l < "$jfile" 2>/dev/null || echo "0")
        if [ "$jlines" -gt 500 ]; then
            # Archive rotated content
            rotated_file="$ARCHIVE_DIR/journals-rotated-$(date '+%Y-%m').md"
            head -$((jlines - 500)) "$jfile" >> "$rotated_file"
            tail -500 "$jfile" > "${jfile}.tmp" && mv "${jfile}.tmp" "$jfile"
            echo "$LOG_PREFIX   Journal rotated: $(basename "$jfile") ($jlines → 500 lines)"
        fi
    done
fi

# ── 1g. Cron heartbeat verification ────────────────────────

EXPECTED_HEARTBEATS=(
    "nightly-digest"
    "keepalive"
    "gdoc-comments"
    "ot-support-triage"
    "meeting-prep"
    "daily-progress"
    # daily-housekeeping, self-check, file-health, token-audit — all written by THIS script (don't check self)
    # weekly-report excluded — runs only Fridays, 48h max age would false-alarm by Sunday
    # area-monitor, leadership-radar — subsections of nightly, heartbeat written internally
)

HEARTBEAT_MAX_AGE=172800  # 48 hours — crons run daily, allow 1 missed run
# Ensure HEARTBEAT_DIR is set even if cron-alert.sh source failed
HEARTBEAT_DIR="${HEARTBEAT_DIR:-$HOME/work/claude/state/heartbeats}"
missing_heartbeats=()
stale_heartbeats=()

for hb in "${EXPECTED_HEARTBEATS[@]}"; do
    sentinel="$HEARTBEAT_DIR/cron-heartbeat-${hb}"
    [ ! -f "$sentinel" ] && sentinel="/tmp/cron-heartbeat-${hb}"
    if [ ! -f "$sentinel" ]; then
        missing_heartbeats+=("$hb")
    else
        hb_raw=$(cat "$sentinel" 2>/dev/null || echo "0")
        # Extract epoch timestamp — handle both pure-numeric ("1774443626") and
        # non-numeric formats ("completed 2026-03-25T11:32:24Z pid=2300950")
        # written by different cron systems (MyClaw vs standard).
        hb_ts=$(echo "$hb_raw" | grep -oE '^[0-9]+$' || echo "")
        if [ -z "$hb_ts" ]; then
            # Non-numeric content — fall back to file modification time
            hb_ts=$(stat -c %Y "$sentinel" 2>/dev/null || echo 0)
        fi
        hb_age=$(( $(date +%s) - ${hb_ts:-0} ))
        if [ "$hb_age" -gt "$HEARTBEAT_MAX_AGE" ]; then
            hb_hours=$((hb_age / 3600))
            stale_heartbeats+=("${hb}(${hb_hours}h)")
        fi
    fi
done

if [ ${#missing_heartbeats[@]} -gt 0 ] || [ ${#stale_heartbeats[@]} -gt 0 ]; then
    hb_msg=""
    [ ${#missing_heartbeats[@]} -gt 0 ] && hb_msg="missing: ${missing_heartbeats[*]}"
    [ ${#stale_heartbeats[@]} -gt 0 ] && hb_msg="${hb_msg:+$hb_msg; }stale: ${stale_heartbeats[*]}"
    issues+=("Cron heartbeat check failed — $hb_msg")
    echo "$LOG_PREFIX   [WARN] Heartbeats: $hb_msg"
else
    echo "$LOG_PREFIX   [OK]   All ${#EXPECTED_HEARTBEATS[@]} cron heartbeats fresh"
fi

# ── 1h. Digest sprawl check ───────────────────────────────

DIGESTS_DIR="$CLAUDE_DIR/context/cache/digests"
if [ -d "$DIGESTS_DIR" ]; then
    digest_count=$({ find "$DIGESTS_DIR" -name "*.md" -type f 2>/dev/null || true; } | wc -l)
    if [ "$digest_count" -gt 10 ]; then
        issues+=("$digest_count session digests in cache/digests/ (limit: 10). Run review-digests.sh to prune.")
        echo "$LOG_PREFIX   [WARN] Digest sprawl: $digest_count files (limit: 10)"
    else
        echo "$LOG_PREFIX   [OK]   Digests: $digest_count files"
    fi
fi

# Write validate alerts
if [ ${#issues[@]} -gt 0 ]; then
    cron_alert "daily-housekeeping" "Housekeeping found ${#issues[@]} issue(s): $(IFS='; '; echo "${issues[*]}")"
    echo "$LOG_PREFIX   Validate: ${#issues[@]} issue(s) found"
else
    cron_alert_clear "daily-housekeeping"
    echo "$LOG_PREFIX   Validate: all clear"
fi

write_heartbeat "self-check"

# ── 1i. Stale alert reaper — clear alerts for jobs that no longer exist ──

if [ -f "$ALERTS_FILE" ]; then
    # Extract all [cron:JOB_NAME] tags from active alerts
    active_tags=$(sed -n '/^## Active Alerts/,/^## /p' "$ALERTS_FILE" | grep -oP '\[cron:\K[^\]]+' 2>/dev/null || true)
    reaped=0
    for tag in $active_tags; do
        # Check if this job exists in crontab or as a script
        tag_in_crontab=$(crontab -l 2>/dev/null | grep -c "$tag" || true)
        tag_has_script=$({ find "$CLAUDE_DIR/scripts" -name "*${tag}*" -type f 2>/dev/null || true; } | wc -l)
        if [ "$tag_in_crontab" -eq 0 ] && [ "$tag_has_script" -eq 0 ]; then
            # Job doesn't exist — reap the alert (atomic: write temp then mv)
            sed "/\[cron:${tag}\]/d" "$ALERTS_FILE" > "${ALERTS_FILE}.tmp" && mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
            reaped=$((reaped + 1))
            echo "$LOG_PREFIX   [REAP] Cleared stale alert [cron:$tag] — no matching job or script"
        fi
    done
    # Restore (none) marker if all active alerts were reaped
    if [ "$reaped" -gt 0 ]; then
        remaining=$(sed -n '/^## Active Alerts/,/^## /p' "$ALERTS_FILE" | grep -c '^\- ' 2>/dev/null || true)
        if [ "$remaining" -eq 0 ]; then
            sed '/^## Active Alerts$/a (none)' "$ALERTS_FILE" > "${ALERTS_FILE}.tmp" && mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
        fi
        echo "$LOG_PREFIX   [OK]   Reaped $reaped stale alert(s)"
    else
        echo "$LOG_PREFIX   [OK]   No stale alerts to reap"
    fi
fi

# ── 1j. Cron script lint — detect common anti-patterns across all cron scripts ──

echo "$LOG_PREFIX [1j] Cron fleet lint"
cron_lint_issues=0

# Lint 1: Scripts that call cron-alert.sh functions but don't source it
for cscript in "$CLAUDE_DIR"/scripts/cron-*.sh; do
    [ -f "$cscript" ] || continue
    bname=$(basename "$cscript")
    [ "$bname" = "cron-alert.sh" ] && continue
    # Check if script uses functions from cron-alert.sh
    if grep -qE 'get_doc_id|get_doc_tab|get_gchat_space|write_heartbeat|cron_alert|tab_freshness_mark|ensure_gmux_healthy' "$cscript" 2>/dev/null; then
        if ! grep -q 'source.*cron-alert\.sh' "$cscript" 2>/dev/null; then
            echo "$LOG_PREFIX   [LINT] $bname: uses cron-alert.sh functions but doesn't source it"
            cron_lint_issues=$((cron_lint_issues + 1))
        fi
    fi
done

# Lint 2: grep in variable assignment under set -e without || true
for cscript in "$CLAUDE_DIR"/scripts/cron-*.sh; do
    [ -f "$cscript" ] || continue
    bname=$(basename "$cscript")
    # Only check scripts with set -e
    if grep -q 'set -e' "$cscript" 2>/dev/null; then
        # Find lines like var=$(grep ...) or var=$(... | grep ...) without || true
        unsafe_greps=$(grep -nP '=\$\(.*grep(?!.*\|\| true)' "$cscript" 2>/dev/null | grep -v '^\s*#' | head -3 || true)
        if [ -n "$unsafe_greps" ]; then
            echo "$LOG_PREFIX   [LINT] $bname: grep in assignment under set -e without || true"
            cron_lint_issues=$((cron_lint_issues + 1))
        fi
    fi
done

# Lint 3: Scripts that exist but aren't registered in crontab
registered_scripts=$(crontab -l 2>/dev/null | grep -oP 'cron_run \d+ \S+ \K\S+' | xargs -I{} basename {} 2>/dev/null | sort -u || true)
for cscript in "$CLAUDE_DIR"/scripts/cron-*.sh; do
    [ -f "$cscript" ] || continue
    bname=$(basename "$cscript")
    # Skip utility scripts (not cron jobs) and known deprecated scripts
    [[ "$bname" =~ ^cron-(alert|workflow-self-eval|self-check|file-health|token-audit|file-sync|sync-to-github|upstream-outside)\.sh$ ]] && continue
    if ! echo "$registered_scripts" | grep -qx "$bname"; then
        echo "$LOG_PREFIX   [LINT] $bname: exists but not registered in crontab"
        cron_lint_issues=$((cron_lint_issues + 1))
    fi
done

# Lint 4: shellcheck — catch set -e fragilities, quoting bugs, and POSIX issues
if command -v shellcheck &>/dev/null; then
    sc_issues=0
    sc_files_with_issues=""
    for cscript in "$CLAUDE_DIR"/scripts/cron-*.sh "$CLAUDE_DIR"/scripts/lib/*.sh "$CLAUDE_DIR"/private_scripts/cron-*.sh; do
        [ -f "$cscript" ] || continue
        bname=$(basename "$cscript")
        sc_out=$(shellcheck -S warning -e SC1090,SC1091,SC2034,SC2154 "$cscript" 2>/dev/null || true)
        if [ -n "$sc_out" ]; then
            sc_count=$(echo "$sc_out" | grep -c '^In ' || true)
            sc_issues=$((sc_issues + sc_count))
            sc_files_with_issues="${sc_files_with_issues:+$sc_files_with_issues, }${bname}(${sc_count})"
        fi
    done
    if [ "$sc_issues" -gt 0 ]; then
        echo "$LOG_PREFIX   [LINT] shellcheck: $sc_issues warning(s) in: $sc_files_with_issues"
        cron_lint_issues=$((cron_lint_issues + 1))
    else
        echo "$LOG_PREFIX   [OK]   shellcheck: all scripts clean"
    fi
else
    echo "$LOG_PREFIX   [SKIP] shellcheck not installed"
fi

# Lint 5: flake8 — catch Python errors, undefined names, unused imports
if command -v flake8 &>/dev/null; then
    py_issues=0
    py_files_with_issues=""
    for pyscript in "$CLAUDE_DIR"/private_scripts/*.py "$CLAUDE_DIR"/private_scripts/lib/*.py; do
        [ -f "$pyscript" ] || continue
        bname=$(basename "$pyscript")
        py_out=$(flake8 --max-line-length=200 --ignore=E501,W503,E402 "$pyscript" 2>/dev/null || true)
        if [ -n "$py_out" ]; then
            py_count=$(echo "$py_out" | wc -l)
            py_issues=$((py_issues + py_count))
            py_files_with_issues="${py_files_with_issues:+$py_files_with_issues, }${bname}(${py_count})"
        fi
    done
    if [ "$py_issues" -gt 0 ]; then
        echo "$LOG_PREFIX   [LINT] flake8: $py_issues issue(s) in: $py_files_with_issues"
        cron_lint_issues=$((cron_lint_issues + 1))
    else
        echo "$LOG_PREFIX   [OK]   flake8: all Python scripts clean"
    fi
else
    echo "$LOG_PREFIX   [SKIP] flake8 not installed"
fi

if [ "$cron_lint_issues" -gt 0 ]; then
    issues+=("Cron fleet lint: $cron_lint_issues issue(s) — check logs for [LINT] entries")
    echo "$LOG_PREFIX   Cron lint: $cron_lint_issues issue(s) found"
else
    echo "$LOG_PREFIX   [OK]   Cron fleet lint: all scripts clean"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: Security — Unicode injection scan (from scan-unicode-tags.sh)
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [2] Unicode injection scan"

# Rule-hook parity — verify enforcement CLAIMS across CLAUDE.md AND all cheatsheets
# are backed by real wired gates (documentation = reality). Alert on false-confidence
# (a rule that claims "hook-enforced" but has no installed gate — silent regression
# surface). This is what keeps NEW rules honest: any future "enforced" claim that
# isn't actually wired surfaces here within a day.
if [ -f "$CLAUDE_DIR/private_scripts/rule-hook-parity.py" ]; then
    _fc=$(python3 "$CLAUDE_DIR/private_scripts/rule-hook-parity.py" 2>/dev/null | grep -oE 'FALSE-CONFIDENCE \(([0-9]+)\)' | grep -oE '[0-9]+' || echo 0)
    if [ "${_fc:-0}" -gt 0 ]; then
        cron_alert "rule-hook-parity" "${_fc} rule(s) across CLAUDE.md/cheatsheets claim enforcement but have no wired gate (false confidence) — run private_scripts/rule-hook-parity.py"
    else
        cron_alert_clear "rule-hook-parity"
        echo "$LOG_PREFIX   [OK]   rule-hook parity: no false-confidence claims"
    fi
fi

# Auto-FIX (not just report): strip invisible injection chars in place. Operator
# request 2026-06-14 "debug and fix it, instead of simply reporting". Stripped:
# tag chars (U+E0000-E007F), zero-width (ZWSP/ZWNJ/BOM), and stray variation
# selectors on a non-emoji base. Preserves emoji (ZWJ U+200D, VS on emoji bases,
# keycap sequences). Files are git-tracked, so any over-strip is recoverable.
fix_summary=$(python3 - "$CLAUDE_DIR" <<'PYEOF' 2>/dev/null || true
import os, sys
root = sys.argv[1]
SKIP = ('/backup/', '/.git/', '/gchat-digests/', '/ot-myclaw-chat-cache/', '/notes/')

def strip_indices(c):
    drop = []
    for i, ch in enumerate(c):
        o = ord(ch)
        if 0xE0000 <= o <= 0xE007F:                 # invisible tag chars
            drop.append(i)
        elif o in (0x200B, 0x200C, 0xFEFF):          # ZWSP/ZWNJ/BOM (keep ZWJ 200D)
            drop.append(i)
        elif 0xFE00 <= o <= 0xFE0F and i > 0 and ord(c[i-1]) < 0x2000:
            if i + 1 < len(c) and ord(c[i+1]) == 0x20E3:  # keycap emoji — keep
                continue
            drop.append(i)                           # stray VS on non-emoji base
    return set(drop)

total, files = 0, []
for dp, _, fns in os.walk(root):
    if any(s.strip('/') in dp.split(os.sep) for s in SKIP):
        continue
    for fn in fns:
        if not fn.endswith('.md'):
            continue
        p = os.path.join(dp, fn)
        if any(s in p for s in SKIP):
            continue
        try:
            c = open(p, encoding='utf-8', errors='ignore').read()
        except Exception:
            continue
        d = strip_indices(c)
        if d:
            open(p, 'w', encoding='utf-8').write(''.join(ch for i, ch in enumerate(c) if i not in d))
            total += len(d)
            files.append(f"{os.path.relpath(p, root)}({len(d)})")
print(f"{total}|" + ", ".join(files[:10]))
PYEOF
)
fix_count="${fix_summary%%|*}"
fix_files="${fix_summary#*|}"
if [ "${fix_count:-0}" -gt 0 ]; then
    echo "$LOG_PREFIX   [FIXED] stripped ${fix_count} invisible char(s): ${fix_files}"
    cron_alert_clear "unicode-scan"   # auto-fixed → not an open problem
else
    cron_alert_clear "unicode-scan"
    echo "$LOG_PREFIX   [OK]   No invisible unicode injections"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: Scan (from file-health)
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [3] File health scan"

REPORT="$CLAUDE_DIR/context/cache/FILE-HEALTH.md"
STALE_DAYS=30  # Raised from 14: only active working files tracked (stable refs excluded)
SIZE_KB=20
TMP_DIR=$(mktemp -d)

# Single find pass: collect path, size (bytes), and modification time for all .md files
{ find "$CLAUDE_DIR" -name "*.md" \
    -not -path "*/backup/*" \
    -not -path "*/.claude/*" \
    -not -path "*/context/archived/*" \
    -not -path "*/context/static/*" \
    -not -path "*/context/cache/FILE-HEALTH.md" \
    -printf '%T@\t%s\t%p\n' 2>/dev/null || true; } | sort -t$'\t' -k3 > "$TMP_DIR/manifest.txt"

total_files=$(wc -l < "$TMP_DIR/manifest.txt")
echo "$LOG_PREFIX   Scanning $total_files .md files"

now_epoch=$(date +%s)
cutoff_epoch=$((now_epoch - STALE_DAYS * 86400))

total_age=0
stale_file_count=0
oversized_count=0
: > "$TMP_DIR/stale.txt"
: > "$TMP_DIR/oversized.txt"
: > "$TMP_DIR/sizes.txt"
: > "$TMP_DIR/basenames.txt"

while IFS=$'\t' read -r mod_float size_bytes filepath; do
    mod_epoch=${mod_float%.*}
    rel="${filepath#$CLAUDE_DIR/}"
    base=$(basename "$filepath" .md)
    kb=$((size_bytes / 1024))
    days_old=$(( (now_epoch - mod_epoch) / 86400 ))
    total_age=$((total_age + days_old))

    echo "$base" >> "$TMP_DIR/basenames.txt"

    # Stale check (skip stable reference directories that don't need frequent edits)
    # cheatsheets/ is intentionally NOT excluded — Denny wants stale cheatsheets flagged.
    if [[ "$rel" != config/* ]] \
       && [[ "$rel" != projects/* ]] && [[ "$rel" != sharings-public/* ]] \
       && [[ "$rel" != research-and-rampup-private/* ]] \
       && [[ "$rel" != context/people/* ]] && [[ "$rel" != context/myself/* ]]; then
        if [[ "$mod_epoch" -lt "$cutoff_epoch" ]]; then
            echo "$rel (${days_old}d)" >> "$TMP_DIR/stale.txt"
            stale_file_count=$((stale_file_count + 1))
        fi
    fi

    # Size check
    if [[ "$kb" -gt "$SIZE_KB" ]]; then
        echo "$rel (${kb}KB)" >> "$TMP_DIR/oversized.txt"
        oversized_count=$((oversized_count + 1))
    fi

    echo "$size_bytes $rel" >> "$TMP_DIR/sizes.txt"
done < "$TMP_DIR/manifest.txt"

avg_age=0
[[ "$total_files" -gt 0 ]] && avg_age=$((total_age / total_files))

echo "$LOG_PREFIX   Stale: $stale_file_count, Oversized: $oversized_count"

# Orphan detection
ROOTS="CLAUDE|ALERTS|FOLLOWUPS|CHEATSHEET-INDEX|INFRASTRUCTURE|MEMORY|STRATEGY|CORE|HANDOFF|MEETING-DIGEST|PREFS|GOALS-REFERENCE|STRATEGY-REFERENCE|TASKS|PROJECT-DOC|META|DISCOVERY|TRACKER|PIPELINE|EXCLUDE-PATTERNS|TEAM-ALIASES|PROTOCOLS|INDEX|REGISTRY|README|WEEKLY-STATUS|ONCALL-LOG|HUMAN-INPUTS|CHECKPOINT|DEBRIEF|ARCHITECTURE|MEGA-INPUTS|SUMMARY-POST|REUSABLE-COMPONENTS|COMMUNITY-RESEARCH"

echo "$LOG_PREFIX   Building content index..."
# Include .md, .sh, .yaml, .json, and .py files in reference check — files referenced
# from scripts, configs, or YAML are not orphans even if no .md file mentions them
# Cap at 50MB to prevent OOM on large trees
{
    cut -f3 "$TMP_DIR/manifest.txt" | xargs -r cat 2>/dev/null || true
    find "$CLAUDE_DIR" \( -name "*.sh" -o -name "*.yaml" -o -name "*.json" -o -name "*.py" \) \
        -not -path "*/backup/*" -not -path "*/.git/*" -not -path "*/node_modules/*" \
        -exec cat {} + 2>/dev/null || true
} | dd bs=1M count=50 iflag=fullblock 2>/dev/null > "$TMP_DIR/blob.txt" || true
echo "$LOG_PREFIX   Content index built ($(wc -c < "$TMP_DIR/blob.txt") bytes)"

orphaned_count=0
: > "$TMP_DIR/orphaned.txt"

while IFS=$'\t' read -r _ _ filepath; do
    bfile=$(basename "$filepath")
    base=$(basename "$filepath" .md)
    if echo "$bfile" | grep -qiE "^($ROOTS)\.md$"; then
        continue
    fi
    if ! grep -qiF "$base" "$TMP_DIR/blob.txt" 2>/dev/null; then
        rel="${filepath#$CLAUDE_DIR/}"
        echo "$rel" >> "$TMP_DIR/orphaned.txt"
        orphaned_count=$((orphaned_count + 1))
    fi
done < "$TMP_DIR/manifest.txt"

echo "$LOG_PREFIX   Orphaned: $orphaned_count"

# Top 5 largest
sort -rn "$TMP_DIR/sizes.txt" > "$TMP_DIR/sizes_sorted.txt"
head -5 "$TMP_DIR/sizes_sorted.txt" | while read -r sz path; do
    echo "- $path ($((sz / 1024))KB)"
done > "$TMP_DIR/top5.txt"
top5=$(cat "$TMP_DIR/top5.txt")

# Write report
cat > "$TMP_DIR/report.md" << ENDREPORT
# File Health Report

Generated: $(date '+%Y-%m-%d %H:%M') | Files: $total_files | Avg age: ${avg_age}d

## Orphaned Files ($orphaned_count)

Basename never referenced by other files (.md, .sh, .yaml, .json, .py). Consider linking or removing.

$(if [[ "$orphaned_count" -eq 0 ]]; then echo "(none)"; else sed 's/^/- /' "$TMP_DIR/orphaned.txt"; fi)

## Stale Files ($stale_file_count)

Not modified in ${STALE_DAYS}+ days (config/, projects/, sharings-public/, research-and-rampup-private/, people/, myself/ excluded; cheatsheets/ included — stale cheatsheets are flagged intentionally).

$(if [[ "$stale_file_count" -eq 0 ]]; then echo "(none)"; else sed 's/^/- /' "$TMP_DIR/stale.txt"; fi)

## Size Outliers ($oversized_count)

Exceeding ${SIZE_KB}KB.

$(if [[ "$oversized_count" -eq 0 ]]; then echo "(none)"; else sed 's/^/- /' "$TMP_DIR/oversized.txt"; fi)

## Top 5 Largest Files

$top5
ENDREPORT

cp "$TMP_DIR/report.md" "$REPORT"
echo "$LOG_PREFIX   Report written to $REPORT"

# Alert if too many issues
# Only alert on stale files (actionable). Orphans are informational — personal workspace files
# are often standalone notes that don't reference each other.
if [[ "$stale_file_count" -gt 20 ]]; then
    cron_alert "file-health" "File health: $stale_file_count stale files (>${STALE_DAYS} days untouched). See FILE-HEALTH.md"
else
    cron_alert_clear "file-health"
fi
write_heartbeat "file-health"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: Anti-sprawl (merged from maintenance Part 4 + self-check)
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [4] Anti-sprawl check"

SPRAWL_WARNINGS=()

# Startup files budget (10KB)
TOTAL_STARTUP_KB=0
for f in "$CONTEXT_DIR/STATE.md" "$CONTEXT_DIR/STRATEGY.md" "$CONTEXT_DIR/meetings/MEETING-DIGEST.md"; do
    if [ -f "$f" ]; then
        SIZE=$(stat --format='%s' "$f" 2>/dev/null || echo 0)
        TOTAL_STARTUP_KB=$((TOTAL_STARTUP_KB + SIZE))
    fi
done
TOTAL_STARTUP_KB=$((TOTAL_STARTUP_KB / 1024))
STARTUP_BUDGET_KB=30
echo "$LOG_PREFIX   Startup files: ${TOTAL_STARTUP_KB}KB / ${STARTUP_BUDGET_KB}KB"
if [ "$TOTAL_STARTUP_KB" -gt "$STARTUP_BUDGET_KB" ]; then
    SPRAWL_WARNINGS+=("Startup files ${TOTAL_STARTUP_KB}KB exceeds ${STARTUP_BUDGET_KB}KB budget")
fi

# Stale files and sprawl are logged, not alerted — they're informational, not P0 blockers
if [ "$stale_file_count" -gt 0 ]; then
    echo "$LOG_PREFIX   Found $stale_file_count stale file(s) — see FILE-HEALTH.md"
else
    echo "$LOG_PREFIX   No stale files"
fi

if [ "${#SPRAWL_WARNINGS[@]}" -gt 0 ]; then
    echo "$LOG_PREFIX   Sprawl warnings: ${SPRAWL_WARNINGS[*]}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: Backup (from maintenance Part 1)
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [5] Workspace backup"

BACKUP_DIR="$CLAUDE_DIR/backup"
HOSTNAME=$(hostname -s)
TIMESTAMP=$(date +%Y-%m-%d_%H%M)

# Load shared exclude patterns for tar
TAR_EXCLUDES=()
if [ -f "$EXCLUDE_FILE" ]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        TAR_EXCLUDES+=(--exclude="$line")
    done < "$EXCLUDE_FILE"
fi

mkdir -p "$BACKUP_DIR"
backup_name="workspace_${TIMESTAMP}_${HOSTNAME}.tar.gz"

# Skip backup if disk is critically full — tar will fail and waste I/O
backup_disk_pct=$(df "$BACKUP_DIR" --output=pcent 2>/dev/null | tail -1 | tr -d '% ')
if [ "${backup_disk_pct:-0}" -ge 95 ]; then
    echo "$LOG_PREFIX   [SKIP] Backup skipped — disk at ${backup_disk_pct}% (>=95%), would fail"
else
    # tar exits 1 on "file changed as we read it" — tolerate it
    rc=0
    tar czf "${BACKUP_DIR}/${backup_name}" \
        "${TAR_EXCLUDES[@]}" \
        --exclude='context/static' \
        --exclude='context/archived' \
        --exclude='projects/_archive' \
        --exclude='state/autolearn-metrics.csv' \
        --exclude='logs/cron-runtime.csv' \
        --exclude='context/cache/state/CLAUDE-SESSION-METRICS.md' \
        --exclude='context/cache/state/AI-AUDIT-HISTORY.json' \
        --exclude='context/cache/state/GDOC-COMMENT-COUNTS.json' \
        --exclude='context/cache/state/GDOC-COMMENTS-PROCESSED.json' \
        --exclude='context/cache/digests' \
        --exclude='context/cache/journals' \
        --exclude='context/cache/gchat' \
        -C "$(dirname "$CLAUDE_DIR")" "$(basename "$CLAUDE_DIR")" 2>/dev/null || rc=$?
    if [ "$rc" -gt 1 ]; then
        cron_alert "backup" "Workspace backup failed (exit $rc). Check ~/logs/daily-housekeeping.log"
    fi

    size_bytes=$(stat --format="%s" "${BACKUP_DIR}/${backup_name}" 2>/dev/null || echo 0)
    size_mb=$(( size_bytes / 1048576 ))
    echo "$LOG_PREFIX   Backup created: ${backup_name} (${size_mb}MB)"

    if [ "$size_mb" -gt 5 ]; then
        cron_alert "backup" "Workspace backup is ${size_mb}MB (threshold: 5MB). Check for large files or stale project data."
    else
        cron_alert_clear "backup"
    fi

    # Keep only the last 3 backups for this hostname
    ls -t "${BACKUP_DIR}"/workspace_*_${HOSTNAME}.tar.gz 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null
fi  # end backup_disk_pct check

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: Clean (from maintenance Part 2)
# ═══════════════════════════════════════════════════════════════════════════════

PROJECTS_DIR="$HOME/.claude/projects"
MAX_AGE_DAYS=3
EMERGENCY_AGE_DAYS=1
DISK_WARN_PCT=80
DISK_CRIT_PCT=90

disk_pct=$(df "$HOME" --output=pcent 2>/dev/null | tail -1 | tr -d '% ')
echo "$LOG_PREFIX [6] Disk reclamation (disk ${disk_pct}% used)"

if [ "${disk_pct:-0}" -ge "$DISK_CRIT_PCT" ]; then
    echo "$LOG_PREFIX   CRITICAL disk pressure (${disk_pct}%) — using ${EMERGENCY_AGE_DAYS}-day retention"
    MAX_AGE_DAYS=$EMERGENCY_AGE_DAYS
    cron_alert "disk" "Disk at ${disk_pct}% — emergency session cleanup triggered (${EMERGENCY_AGE_DAYS}-day retention)"
elif [ "${disk_pct:-0}" -ge "$DISK_WARN_PCT" ]; then
    echo "$LOG_PREFIX   High disk pressure (${disk_pct}%) — using 2-day retention"
    MAX_AGE_DAYS=2
else
    cron_alert_clear "disk"
fi

# 6a. Session transcripts (.jsonl)
if [[ -d "$PROJECTS_DIR" ]]; then
    before_size=$(du -sh "$PROJECTS_DIR" 2>/dev/null | cut -f1)
    deleted=$({ find "$PROJECTS_DIR" -name "*.jsonl" -mtime +${MAX_AGE_DAYS} -delete -print 2>/dev/null || true; } | wc -l)
    { find "$PROJECTS_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null || true; } | while read -r session_dir; do
        if [ -z "$(find "$session_dir" -maxdepth 1 -name '*.jsonl' 2>/dev/null || true)" ]; then
            rm -rf -- "$session_dir"
        fi
    done
    find "$PROJECTS_DIR" -maxdepth 1 -type d -empty -delete 2>/dev/null || true
    after_size=$(du -sh "$PROJECTS_DIR" 2>/dev/null | cut -f1)
    echo "$LOG_PREFIX   Sessions: deleted $deleted (>${MAX_AGE_DAYS}d). $before_size → $after_size"
fi

# 6b. /tmp claude launcher artifacts
tmp_deleted=$({ find /tmp -maxdepth 1 -name "claude_launcher_*" -mtime +1 -delete -print 2>/dev/null || true; } | wc -l)
tmp_deleted=$((tmp_deleted + $({ find /tmp -maxdepth 1 -name "claude_launcher_*.lock" -mtime +1 -delete -print 2>/dev/null || true; } | wc -l)))
[ "$tmp_deleted" -gt 0 ] && echo "$LOG_PREFIX   /tmp launcher files: deleted $tmp_deleted"

# 6c. Stale cron error logs and lock files
find /tmp -maxdepth 1 -name "cron-*-err.log" -mtime +3 -delete 2>/dev/null || true
find /tmp -maxdepth 1 -name "cron-*.lock" -mtime +1 -delete 2>/dev/null || true

# 6d. Claude file-history (edit snapshots)
FILE_HIST="$HOME/.claude/file-history"
if [ -d "$FILE_HIST" ]; then
    fh_deleted=$({ find "$FILE_HIST" -type f -mtime +7 -delete -print 2>/dev/null || true; } | wc -l)
    [ "$fh_deleted" -gt 0 ] && echo "$LOG_PREFIX   file-history: deleted $fh_deleted old snapshots"
fi

# 6e. Claude shell-snapshots
SHELL_SNAP="$HOME/.claude/shell-snapshots"
if [ -d "$SHELL_SNAP" ]; then
    ss_deleted=$({ find "$SHELL_SNAP" -type f -mtime +7 -delete -print 2>/dev/null || true; } | wc -l)
    [ "$ss_deleted" -gt 0 ] && echo "$LOG_PREFIX   shell-snapshots: deleted $ss_deleted old snapshots"
fi

# 6f. Claude tmp working dirs
if [ -d "/tmp/claude-${USER}" ]; then
    ct_deleted=$({ find "/tmp/claude-${USER}" -type f -mtime +1 -delete -print 2>/dev/null || true; } | wc -l)
    find "/tmp/claude-${USER}" -type d -empty -delete 2>/dev/null || true
    [ "$ct_deleted" -gt 0 ] && echo "$LOG_PREFIX   /tmp/claude-${USER}: deleted $ct_deleted old files"
fi

# 6g. Dotslash binary cache (can grow to 100G+, re-downloads on demand)
# Only clean files owned by current user to avoid permission errors on root-owned entries
# Two thresholds: always prune >3-day files when >2GB, aggressive 7-day prune when >5GB
DOTSLASH_OBJ="$HOME/.cache/dotslash/obj"
if [ -d "$DOTSLASH_OBJ" ]; then
    dotslash_mb=$({ timeout 30 du -sm "$DOTSLASH_OBJ" 2>/dev/null || true; } | awk '{print $1}')
    if [ "${dotslash_mb:-0}" -gt 5120 ]; then
        echo "$LOG_PREFIX   Dotslash cache: ${dotslash_mb}MB — pruning user-owned entries older than 7 days"
        ds_deleted=$({ find "$DOTSLASH_OBJ" -type f -user "$(whoami)" -mtime +7 -delete -print 2>/dev/null || true; } | wc -l)
        find "$DOTSLASH_OBJ" -type d -empty -delete 2>/dev/null || true
        dotslash_after=$({ du -sm "$DOTSLASH_OBJ" 2>/dev/null || true; } | awk '{print $1}')
        echo "$LOG_PREFIX   Dotslash cache: deleted $ds_deleted files (${dotslash_mb}MB → ${dotslash_after}MB)"
    elif [ "${dotslash_mb:-0}" -gt 2048 ]; then
        echo "$LOG_PREFIX   Dotslash cache: ${dotslash_mb}MB — pruning user-owned entries older than 3 days"
        ds_deleted=$({ find "$DOTSLASH_OBJ" -type f -user "$(whoami)" -mtime +3 -delete -print 2>/dev/null || true; } | wc -l)
        find "$DOTSLASH_OBJ" -type d -empty -delete 2>/dev/null || true
        dotslash_after=$({ du -sm "$DOTSLASH_OBJ" 2>/dev/null || true; } | awk '{print $1}')
        echo "$LOG_PREFIX   Dotslash cache: deleted $ds_deleted files (${dotslash_mb}MB → ${dotslash_after}MB)"
    else
        echo "$LOG_PREFIX   Dotslash cache: ${dotslash_mb}MB (under 2GB threshold)"
    fi
fi

# 6g2. Claude CLI Node.js cache (re-downloads on demand)
CLAUDE_NODE_CACHE="$HOME/.cache/claude-cli-nodejs"
if [ -d "$CLAUDE_NODE_CACHE" ]; then
    cn_deleted=$({ find "$CLAUDE_NODE_CACHE" -type f -mtime +1 -delete -print 2>/dev/null || true; } | wc -l)
    find "$CLAUDE_NODE_CACHE" -type d -empty -delete 2>/dev/null || true
    [ "$cn_deleted" -gt 0 ] && echo "$LOG_PREFIX   claude-cli-nodejs cache: deleted $cn_deleted files (>1 day old)"
fi

# 6h. Stale Claude worktree dirs in /tmp (agent isolation leftovers)
# Cron subprocesses create ~100+ .tmp* dirs/day — use 4-hour cutoff, not 3-day
wt_deleted=$({ find /tmp -maxdepth 1 -name '.tmp*' -type d -user "$(whoami)" -mmin +240 -exec rm -rf {} + -print 2>/dev/null || true; } | wc -l)
wt_files_deleted=$({ find /tmp -maxdepth 1 -name '.tmp*' -type f -user "$(whoami)" -mtime +1 -delete -print 2>/dev/null || true; } | wc -l)
[ "$wt_deleted" -gt 0 ] || [ "$wt_files_deleted" -gt 0 ] && echo "$LOG_PREFIX   /tmp worktrees: removed $wt_deleted dirs, $wt_files_deleted files"

# 6i. /tmp caches that grow unbounded (rebuilt on demand)
# Only clean user-owned directories to avoid permission errors on root-owned paths
for cache_target in \
    "/tmp/flow" \
    "/tmp/confucius_cli_fbpkg_cache" \
    "/tmp/eslint-cache" \
    "/tmp/fastzip-castree-uid-$(id -u)"; do
    if [ -d "$cache_target" ] && [ -O "$cache_target" ]; then
        cache_sz=$({ timeout 15 du -sm "$cache_target" 2>/dev/null || true; } | awk '{print $1}')
        if [ "${cache_sz:-0}" -gt 500 ]; then
            rm -rf "$cache_target"
            echo "$LOG_PREFIX   Cleared $cache_target (${cache_sz}MB)"
        fi
    fi
done

# 6j. Stale par_unpack dirs (PAR archive caches — keep only <7 days)
# Only clean user-owned dirs to avoid permission errors on root-owned entries
par_before=$({ du -sm /tmp/par_unpack* 2>/dev/null || true; } | awk '{sum+=$1} END {print sum+0}')
find /tmp -maxdepth 1 -name 'par_unpack*' -type d -user "$(whoami)" -mtime +7 -exec rm -rf {} + 2>/dev/null || true
par_after=$({ du -sm /tmp/par_unpack* 2>/dev/null || true; } | awk '{sum+=$1} END {print sum+0}')
par_freed=$((par_before - par_after))
[ "$par_freed" -gt 100 ] && echo "$LOG_PREFIX   par_unpack: freed ${par_freed}MB (${par_before}MB → ${par_after}MB)"

# 6k. Log rotation — truncate logs older than 7 days, keep last 500 lines
LOG_DIR="$HOME/logs"
if [ -d "$LOG_DIR" ]; then
    for logfile in "$LOG_DIR"/*.log; do
        [ -f "$logfile" ] || continue
        log_lines=$(wc -l < "$logfile" 2>/dev/null || echo 0)
        if [ "$log_lines" -gt 5000 ]; then
            # Atomic rotation: write to temp, then rename (prevents data loss if writer is active)
            tail -500 "$logfile" > "${logfile}.rotate.tmp" && mv "${logfile}.rotate.tmp" "$logfile"
            echo "$LOG_PREFIX   Log rotated: $(basename "$logfile") ($log_lines → 500 lines)"
        fi
    done
fi

# 6m. Screenshots — keep only 3 most recent, delete the rest
SCREENSHOTS_DIR="$CLAUDE_DIR/screenshots"
if [ -d "$SCREENSHOTS_DIR" ]; then
    screenshot_count=$({ find "$SCREENSHOTS_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null || true; } | wc -l)
    if [ "$screenshot_count" -gt 3 ]; then
        ss_deleted=$(ls -t "$SCREENSHOTS_DIR"/*.{png,jpg,jpeg} 2>/dev/null | tail -n +4 | xargs rm -f -v 2>/dev/null | wc -l)
        echo "$LOG_PREFIX   Screenshots: kept 3, deleted $ss_deleted old file(s)"
    fi
fi

# 6n. Sapling blackbox logs — purge when >20MB (blackbox regrows fast)
SL_BLACKBOX="$CLAUDE_DIR/.git/sl/blackbox"
SL_DIR="$CLAUDE_DIR/.git/sl"
if [ -d "$SL_BLACKBOX" ]; then
    bb_mb=$(du -sm "$SL_BLACKBOX" 2>/dev/null | awk '{print $1}')
    if [ "${bb_mb:-0}" -gt 20 ]; then
        rm -rf "$SL_BLACKBOX/v1/"*
        rm -f "$SL_DIR/blackbox.log."* 2>/dev/null
        truncate -s 0 "$SL_DIR/store/segments/v1/multimetalog/log" 2>/dev/null || true
        bb_after=$(du -sm "$SL_BLACKBOX" 2>/dev/null | awk '{print $1}')
        echo "$LOG_PREFIX   Sapling blackbox: ${bb_mb}MB → ${bb_after}MB (also cleaned rotated logs + multimetalog)"
    fi
fi

# 6l. Digest prefetch temp dirs (stale cron run leftovers)
find /tmp -maxdepth 1 -name 'digest-prefetch-*' -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
find /tmp -maxdepth 1 -name 'digest-cand-*' -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
find /tmp -maxdepth 1 -name 'digest-twophase-*' -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
find /tmp -maxdepth 1 -name 'digest-combined-*' -mtime +1 -delete 2>/dev/null || true

# 6o. Root filesystem emergency cleanup (adaptive)
root_pct=$(df / --output=pcent 2>/dev/null | tail -1 | tr -d '% ')
if [ "${root_pct:-0}" -ge 95 ]; then
    echo "$LOG_PREFIX   EMERGENCY: root filesystem at ${root_pct}% — aggressive /tmp cleanup"
    # More aggressive: .tmp worktrees >1 hour
    find /tmp -maxdepth 1 -name '.tmp*' -type d -user "$(whoami)" -mmin +60 -exec rm -rf {} + 2>/dev/null || true
    # All user-owned caches regardless of size (skip root-owned paths like /tmp/dotslash-0)
    for ec in /tmp/flow /tmp/confucius_cli_fbpkg_cache /tmp/eslint-cache \
              "/tmp/fastzip-castree-uid-$(id -u)"; do
        if [ -d "$ec" ] && [ -O "$ec" ]; then
            rm -rf "$ec" && echo "$LOG_PREFIX   Emergency: cleared $ec"
        fi
    done
    # par_unpack >3 days (user-owned only)
    find /tmp -maxdepth 1 -name 'par_unpack*' -type d -user "$(whoami)" -mtime +3 -exec rm -rf {} + 2>/dev/null || true
    root_after=$(df / --output=pcent 2>/dev/null | tail -1 | tr -d '% ')
    echo "$LOG_PREFIX   Emergency cleanup done: ${root_pct}% → ${root_after}%"
    if [ "${root_after:-100}" -ge 95 ]; then
        cron_alert "disk-root" "Root filesystem still at ${root_after}% after emergency cleanup"
    else
        cron_alert_clear "disk-root"
    fi
fi

# 6p. System-level disk cleanup (from P2266550552 — shared devserver best practices)
# clean-disk-space: Meta-provided tool that safely reclaims system caches
if [ -x /usr/lib/devservers/clean-disk-space ]; then
    echo "$LOG_PREFIX   [6p] Running system clean-disk-space..."
    timeout 120 /usr/lib/devservers/clean-disk-space 2>&1 | tail -3 || echo "$LOG_PREFIX   [WARN] clean-disk-space timed out or failed"
fi

# buck2 kill: release buck2 daemon memory + disk locks
# Use timeout to prevent hang on sick EdenFS mounts
if command -v buck2 &>/dev/null && [ -d "$HOME/fbsource/fbcode" ]; then
    echo "$LOG_PREFIX   [6q] buck2 kill..."
    timeout 30 bash -c 'cd "$HOME/fbsource/fbcode" && buck2 kill' 2>/dev/null && echo "$LOG_PREFIX   buck2 daemon killed" || true
fi

# eden doctor: check and repair EdenFS mounts
if command -v eden &>/dev/null; then
    echo "$LOG_PREFIX   [6r] eden doctor..."
    timeout 60 eden doctor 2>&1 | tail -5 && echo "$LOG_PREFIX   eden doctor completed" || echo "$LOG_PREFIX   [WARN] eden doctor timed out"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: Git auto-commit — persist local changes nightly
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [7] Git auto-commit (bucketed via commit-digest.sh)"

cd "$CLAUDE_DIR"
if git rev-parse --is-inside-work-tree &>/dev/null; then
    # Delegate to commit-digest.sh which splits changes into SIGNAL + STATE
    # commits with descriptive per-file hints (easier GitHub spot-checking).
    if bash "$CLAUDE_DIR/scripts/commit-digest.sh" 2>&1 | sed "s/^/$LOG_PREFIX   /"; then
        echo "$LOG_PREFIX   [OK]   commit-digest completed"
    else
        echo "$LOG_PREFIX   [FAIL] commit-digest failed"
    fi
else
    echo "$LOG_PREFIX   [SKIP] $CLAUDE_DIR is not a git repo"
fi

# ── 7a2. Prune old backup/ snapshots (keep last 14 days) ──────────────────
# backup/ is the bulk of the working tree (~36MB). Operator OK to lose backups
# (and git history) older than 2 weeks (2026-06-14 doc comment). Pruning here +
# the history squash below keeps the repo under REPO_SIZE_CAP_MB.
if [ -d "$CLAUDE_DIR/backup" ]; then
    pruned=$(find "$CLAUDE_DIR/backup" -mindepth 1 -maxdepth 1 -type d -mtime +14 2>/dev/null | wc -l)
    if [ "$pruned" -gt 0 ]; then
        find "$CLAUDE_DIR/backup" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} + 2>/dev/null || true
        echo "$LOG_PREFIX   [TRIM] pruned $pruned backup dir(s) >14 days old"
    fi
fi

# ── 7a3. Crontab drift — live jobs missing from setup-claude.sh heredoc ──────
# A live-only job won't survive a devserver reinstall (the heredoc is the source
# of truth). Alert so it's re-activated before reinstall, not discovered after.
_setup="$CLAUDE_DIR/scripts/setup-claude.sh"
if [ -f "$_setup" ]; then
    _live=$(crontab -l 2>/dev/null | grep -E '^[*0-9]' | grep -oE 'cron_run [0-9]+ [a-z0-9-]+' | awk '{print $3}' | sort -u)
    _hd=$(awk '/cat <<.?CRON.? \| crontab/{f=1} /^CRON$/{f=0} f&&/^[*0-9]/' "$_setup" | grep -oE 'cron_run [0-9]+ [a-z0-9-]+' | awk '{print $3}' | sort -u)
    _drift=$(comm -23 <(echo "$_live") <(echo "$_hd") | tr '\n' ' ' | xargs)
    if [ -n "$_drift" ]; then
        echo "$LOG_PREFIX   [DRIFT] live-only cron jobs (won't survive reinstall): $_drift"
        cron_alert "crontab-drift" "Live-only cron jobs not in setup-claude.sh heredoc — won't survive reinstall: $_drift"
    else
        cron_alert_clear "crontab-drift"
        echo "$LOG_PREFIX   [OK]   crontab matches heredoc (reinstall-safe)"
    fi
fi

# ── 7b. Repo size cap — squash history if .git grows too large ──
REPO_SIZE_CAP_MB=100
GIT_DIR="$CLAUDE_DIR/.git"

if [ -d "$GIT_DIR" ]; then
    repo_total_kb=$(du -sk "$CLAUDE_DIR" 2>/dev/null | awk '{print $1}')
    repo_total_mb=$((repo_total_kb / 1024))
    git_size_kb=$(du -sk "$GIT_DIR" 2>/dev/null | awk '{print $1}')
    git_size_mb=$((git_size_kb / 1024))
    commit_count=$(git -C "$CLAUDE_DIR" rev-list --count HEAD 2>/dev/null || echo 0)

    echo "$LOG_PREFIX   Repo: ${repo_total_mb}MB total, .git ${git_size_mb}MB, ${commit_count} commits (cap: ${REPO_SIZE_CAP_MB}MB)"

    if [ "$repo_total_mb" -ge "$REPO_SIZE_CAP_MB" ]; then
        echo "$LOG_PREFIX   [TRIM] Repo exceeds ${REPO_SIZE_CAP_MB}MB — squashing git history to single commit"

        cd "$CLAUDE_DIR"

        # Capture the current tree as an orphan branch, then replace main
        # Run in subshell so set -e failures don't leave detached HEAD
        orphan_branch="trim-$(date +%s)"
        # --no-verify: this is a mechanical squash of already-tracked content (the
        # pre-commit hook already passed on the original commits). Without it, a hook
        # rejection fails the commit and strands the repo on the orphan branch — the
        # exact 12-day wedge seen after 2026-06-01 that silently broke the cron cluster.
        if git checkout --orphan "$orphan_branch" &>/dev/null \
           && git add -A &>/dev/null \
           && git commit --no-verify -m "$(cat <<EOF
repo trim $(date '+%Y-%m-%d') — squashed history to stay under ${REPO_SIZE_CAP_MB}MB

Previous size: ${repo_total_mb}MB (.git: ${git_size_mb}MB, ${commit_count} commits).
All prior history collapsed into this single commit.
EOF
)" &>/dev/null; then
            # Replace main with the orphan
            git branch -D main &>/dev/null 2>&1 || true
            git branch -m main &>/dev/null

            # Purge old objects
            git reflog expire --expire=now --all &>/dev/null
            git gc --prune=now --aggressive &>/dev/null
        else
            echo "$LOG_PREFIX   [WARN] Squash failed — recovering to main"
            # `git checkout main` fails here: the orphan branch has 20k staged files
            # (git add -A), so checkout aborts on conflicts and `|| true` swallows it,
            # leaving the repo stranded on the orphan branch. Restore HEAD by POINTER
            # only (no checkout, no index conflict) + reset index to main's tree, which
            # cannot fail on staged/untracked files and never strands the working copy.
            if ! git checkout main &>/dev/null 2>&1; then
                git symbolic-ref HEAD refs/heads/main &>/dev/null 2>&1 || true
                git reset --mixed &>/dev/null 2>&1 || true
            fi
            git branch -D "$orphan_branch" &>/dev/null 2>&1 || true
            # Hard postcondition: never exit this block on an orphan branch.
            cur_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
            if [ "$cur_branch" != "main" ]; then
                cron_alert "repo-trim" "Trim recovery left repo on '$cur_branch', not main — manual fix needed"
                echo "$LOG_PREFIX   [ERROR] recovery did not land on main (on: $cur_branch)"
            fi
        fi

        new_total_kb=$(du -sk "$CLAUDE_DIR" 2>/dev/null | awk '{print $1}')
        new_total_mb=$((new_total_kb / 1024))
        new_git_kb=$(du -sk "$GIT_DIR" 2>/dev/null | awk '{print $1}')
        new_git_mb=$((new_git_kb / 1024))

        echo "$LOG_PREFIX   [OK]   Trimmed: ${repo_total_mb}MB → ${new_total_mb}MB (.git: ${git_size_mb}MB → ${new_git_mb}MB)"

        if [ "$new_total_mb" -ge "$REPO_SIZE_CAP_MB" ]; then
            worktree_kb=$(du -sk --exclude='.git' "$CLAUDE_DIR" 2>/dev/null | awk '{print $1}')
            worktree_mb=$((worktree_kb / 1024))
            cron_alert "repo-size" "Repo still ${new_total_mb}MB after git history trim (cap: ${REPO_SIZE_CAP_MB}MB). .git: ${new_git_mb}MB, working tree: ${worktree_mb}MB."
            echo "$LOG_PREFIX   [WARN] Repo still over cap — .git: ${new_git_mb}MB, working tree: ${worktree_mb}MB"
        else
            cron_alert_clear "repo-size"
        fi
    else
        cron_alert_clear "repo-size"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8: Token audit (from cron-token-audit.sh)
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX [8] Token audit"

STATS_FILE="$HOME/.claude/stats-cache.json"
AUDIT_DIR="$CLAUDE_DIR/context/cache/token-audit"
AUDIT_REPORT="$CLAUDE_DIR/context/cache/TOKEN-AUDIT.md"
TODAY=$(date +%Y-%m-%d)

DAILY_TOKEN_WARN=5000000
DAILY_TOKEN_CRIT=10000000
SPIKE_MULTIPLIER=2

if [ ! -f "$STATS_FILE" ]; then
    echo "$LOG_PREFIX   [SKIP] No stats-cache.json found"
else
    mkdir -p "$AUDIT_DIR"
    cp "$STATS_FILE" "$AUDIT_DIR/stats-$TODAY.json"

    # Extract daily token counts and generate report
    python3 - "$STATS_FILE" "$AUDIT_DIR" "$TODAY" <<'PYEOF'
import json, sys, os
from datetime import datetime, timedelta

stats_file = sys.argv[1]
audit_dir = sys.argv[2]
today = sys.argv[3]

with open(stats_file) as f:
    data = json.load(f)

daily_tokens = data.get("dailyModelTokens", [])
daily_activity = data.get("dailyActivity", [])

token_by_date = {}
for entry in daily_tokens:
    d = entry["date"]
    total = sum(entry.get("tokensByModel", {}).values())
    token_by_date[d] = {"total": total, "by_model": entry.get("tokensByModel", {})}

activity_by_date = {}
for entry in daily_activity:
    d = entry["date"]
    activity_by_date[d] = {
        "messages": entry.get("messageCount", 0),
        "sessions": entry.get("sessionCount", 0),
        "tool_calls": entry.get("toolCallCount", 0)
    }

dates = []
today_dt = datetime.strptime(today, "%Y-%m-%d")
for i in range(14):
    d = (today_dt - timedelta(days=i)).strftime("%Y-%m-%d")
    dates.append(d)

report = []
for d in reversed(dates):
    t = token_by_date.get(d, {"total": 0, "by_model": {}})
    a = activity_by_date.get(d, {"messages": 0, "sessions": 0, "tool_calls": 0})
    report.append({"date": d, "tokens": t["total"], "by_model": t["by_model"],
                    "messages": a["messages"], "sessions": a["sessions"], "tool_calls": a["tool_calls"]})

last_7 = [r for r in report if r["date"] != today][-7:]
avg_7d = sum(r["tokens"] for r in last_7) / max(len(last_7), 1)
today_data = next((r for r in report if r["date"] == today), {"tokens": 0})
today_tokens = today_data["tokens"]
spike_ratio = today_tokens / avg_7d if avg_7d > 0 else 0
model_usage = data.get("modelUsage", {})

output = {"daily": report, "avg_7d": int(avg_7d), "today_tokens": today_tokens,
          "spike_ratio": round(spike_ratio, 2), "model_usage": model_usage,
          "total_sessions": data.get("totalSessions", 0)}

with open(os.path.join(audit_dir, "report-latest.json"), "w") as f:
    json.dump(output, f, indent=2)
print(json.dumps({"today_tokens": today_tokens, "avg_7d": int(avg_7d), "spike_ratio": round(spike_ratio, 2)}))
PYEOF

    # Generate markdown report
    if [ -f "$AUDIT_DIR/report-latest.json" ]; then
        today_tokens=$(python3 -c "import json; d=json.load(open('$AUDIT_DIR/report-latest.json')); print(d['today_tokens'])")
        avg_7d=$(python3 -c "import json; d=json.load(open('$AUDIT_DIR/report-latest.json')); print(d['avg_7d'])")
        spike_ratio=$(python3 -c "import json; d=json.load(open('$AUDIT_DIR/report-latest.json')); print(d['spike_ratio'])")

        if [ "$today_tokens" -gt "$DAILY_TOKEN_CRIT" ]; then
            status="CRITICAL"
        elif [ "$today_tokens" -gt "$DAILY_TOKEN_WARN" ]; then
            status="WARNING"
        else
            status="OK"
        fi

        {
            echo "# Token Audit Report"
            echo "Generated: $TODAY $(date +%H:%M) PT"
            echo ""
            echo "## Summary"
            echo "| Metric | Value |"
            echo "|--------|-------|"
            echo "| Today's tokens | $(printf "%'d" "$today_tokens") |"
            echo "| 7-day average | $(printf "%'d" "$avg_7d") |"
            echo "| Spike ratio | ${spike_ratio}x |"
            echo "| Status | $status |"
            echo ""
            echo "## Daily Token Trend (14 days)"
            echo "| Date | Tokens | Messages | Sessions | Tool Calls |"
            echo "|------|--------|----------|----------|------------|"
            python3 -c "
import json
d = json.load(open('$AUDIT_DIR/report-latest.json'))
for r in d['daily']:
    t = f\"{r['tokens']:,}\"
    print(f\"| {r['date']} | {t} | {r['messages']:,} | {r['sessions']} | {r['tool_calls']:,} |\")
"
            echo ""
            echo "## Model Lifetime Usage"
            echo "| Model | Input Tokens | Output Tokens | Cache Read | Cache Write |"
            echo "|-------|-------------|---------------|------------|-------------|"
            python3 -c "
import json
d = json.load(open('$AUDIT_DIR/report-latest.json'))
for model, u in d.get('model_usage', {}).items():
    inp = f\"{u.get('inputTokens', 0):,}\"
    out = f\"{u.get('outputTokens', 0):,}\"
    cr = f\"{u.get('cacheReadInputTokens', 0):,}\"
    cw = f\"{u.get('cacheCreationInputTokens', 0):,}\"
    print(f'| {model} | {inp} | {out} | {cr} | {cw} |')
"
        } > "$AUDIT_REPORT"

        echo "$LOG_PREFIX   Tokens: $(printf "%'d" "$today_tokens") today, $(printf "%'d" "$avg_7d") 7d avg, ${spike_ratio}x spike — $status"

        # Alert on thresholds
        alerts=""
        if [ "$today_tokens" -gt "$DAILY_TOKEN_CRIT" ]; then
            alerts="CRITICAL: $(printf "%'d" "$today_tokens") tokens exceeds $(printf "%'d" $DAILY_TOKEN_CRIT) threshold"
        elif [ "$today_tokens" -gt "$DAILY_TOKEN_WARN" ]; then
            alerts="WARNING: $(printf "%'d" "$today_tokens") tokens exceeds $(printf "%'d" $DAILY_TOKEN_WARN) threshold"
        fi
        spike_int=$(echo "$spike_ratio" | cut -d. -f1)
        if [ "${spike_int:-0}" -ge "$SPIKE_MULTIPLIER" ] && [ "$today_tokens" -gt 1000000 ]; then
            spike_msg="SPIKE: ${spike_ratio}x of 7-day average"
            alerts="${alerts:+$alerts | }$spike_msg"
        fi

        if [ -n "$alerts" ]; then
            cron_alert "token-audit" "$alerts — see TOKEN-AUDIT.md"
        else
            cron_alert_clear "token-audit"
        fi
    fi

    # Cleanup old snapshots (keep 30 days)
    find "$AUDIT_DIR" -name "stats-*.json" -mtime +30 -delete 2>/dev/null || true
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Notes Repo Sync — push sharings-public/ to ~/notes for collab-files surface
# ═══════════════════════════════════════════════════════════════════════════════
# ONLY syncs sharings-public/. NEVER touches research-and-rampup-private/ or any other folder.
# Skips silently if notes repo is missing or in unhealthy state (incomplete clone).

NOTES_DIR="$HOME/notes"
NOTES_TARGET="$NOTES_DIR/users/dennyzhang/sharings-public"
SOURCE_DIR="$CLAUDE_DIR/sharings-public"

echo "$LOG_PREFIX === Notes repo sync ==="

if [ ! -d "$NOTES_DIR/.hg" ] && [ ! -d "$NOTES_DIR/.sl" ]; then
    echo "$LOG_PREFIX   [SKIP] $NOTES_DIR is not a Sapling/hg repo"
elif [ ! -d "$SOURCE_DIR" ]; then
    echo "$LOG_PREFIX   [SKIP] source $SOURCE_DIR missing"
elif (cd "$NOTES_DIR" && sl status --reason "clone health check - sl help status" 2>&1 | head -3 | grep -qF "has not finished cloning"); then
    echo "$LOG_PREFIX   [SKIP] $NOTES_DIR clone is incomplete — run 'sl checkout --continue' in $NOTES_DIR"
else
    mkdir -p "$NOTES_TARGET"
    if rsync -a --delete --exclude='.DS_Store' "$SOURCE_DIR/" "$NOTES_TARGET/" 2>&1; then
        echo "$LOG_PREFIX   Synced sharings-public/ → $NOTES_TARGET"
        cd "$NOTES_DIR"
        if sl status --reason "check pending changes in notes repo - sl help status" 2>/dev/null | grep -q .; then
            sl addremove "users/dennyzhang/sharings-public" --reason "track sharings-public changes - sl help addremove" 2>&1 || true
            if sl commit -m "dennyzhang: sync sharings-public $(date +%Y-%m-%d)" --reason "auto-commit sharings-public sync - sl help commit" 2>&1; then
                echo "$LOG_PREFIX   Committed in notes repo"
                if sl push --reason "push sharings-public sync - sl help push" 2>&1; then
                    echo "$LOG_PREFIX   Pushed to notes remote"
                else
                    echo "$LOG_PREFIX   [WARN] sl push failed"
                fi
            else
                echo "$LOG_PREFIX   [WARN] sl commit failed (likely no actual diff)"
            fi
        else
            echo "$LOG_PREFIX   No changes to commit"
        fi
        cd "$CLAUDE_DIR"
    else
        echo "$LOG_PREFIX   [WARN] rsync failed"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Heartbeat
# ═══════════════════════════════════════════════════════════════════════════════

write_heartbeat "token-audit"
write_heartbeat "daily-housekeeping"

echo "$LOG_PREFIX === Done (disk now $(df "$HOME" --output=pcent 2>/dev/null | tail -1 | tr -d ' ')used) ==="

# ── Fetch cache cleanup (24h TTL) ─────────────────────────
find "$HOME/work/claude/state/fetch-cache" -type f -mmin +1440 -delete 2>/dev/null || true

