#!/usr/bin/env bash
# cron-workflow-regression.sh — Weekly regression test for workflow design rules.
# Delegates all cron-script checks to the canonical lint at
# private_scripts/lib/cron_audit.py (10 mechanical checks), then keeps the
# layered concerns the lint doesn't cover: hook-only /tmp scoping, raw-append
# detection, stale-sentinel cleanup, enforcement-metrics summary.
#
# Schedule: Weekly Sunday 8 PM via setup-claude.sh crontab.
# Consolidated 2026-06-17: previously had inline grep-based duplicates of
# cron_audit.py rules A/C/D/E — now delegated to the single source of truth.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
CRON_AUDIT="$REPO_DIR/private_scripts/lib/cron_audit.py"

source "$SCRIPT_DIR/cron-alert.sh"

echo "$LOG_PREFIX === Workflow Design Regression ==="

violations=0
checks_completed=0

# [1] Cron-script audit — delegate to canonical lint (10 mechanical checks).
# Covers: A sources cron-alert, B locking, C heartbeat, D heartbeat-gated,
# E /tmp scoping, F claude --model tier, G fan-out cap, H/I/J registration.
echo "$LOG_PREFIX [1] Cron-script audit (cron_audit.py --all)"
if [ -f "$CRON_AUDIT" ] && command -v python3 >/dev/null 2>&1; then
    audit_out=$(python3 "$CRON_AUDIT" --all 2>&1 || true)
    cron_fail=$(echo "$audit_out" | awk '/^Total FAIL gaps:/ {print $4}' | head -1)
    cron_fail="${cron_fail:-0}"
    cron_clean=$(echo "$audit_out" | awk '/^Clean \(0 gaps\):/ {print $4}' | head -1)
    cron_clean="${cron_clean:-?}"
    cron_total=$(echo "$audit_out" | awk '/^Total crons:/ {print $3}' | head -1)
    cron_total="${cron_total:-?}"
    echo "$LOG_PREFIX   $cron_total crons, $cron_clean clean, $cron_fail FAIL items"
    if [ "$cron_fail" -gt 0 ]; then
        # Surface the by-check breakdown so the weekly digest is actionable
        echo "$audit_out" | grep -E "^\s*\[(fail|warn)\]" | head -12 | sed "s/^/$LOG_PREFIX   /"
        violations=$((violations + cron_fail))
    fi
    checks_completed=$((checks_completed + 1))
else
    echo "$LOG_PREFIX   [SKIP] cron_audit.py missing or python3 unavailable"
fi

# [2] Hook /tmp scoping — not covered by cron_audit (it checks crons, not hooks)
# Skips comment lines; exclusions cover legitimate singleton state.
echo "$LOG_PREFIX [2] Hook /tmp scoping"
for f in "$REPO_DIR"/config/hooks/*.sh "$REPO_DIR"/scripts/enforce-prerequisites.sh; do
    [ -f "$f" ] || continue
    # Exclude comment lines (^\s*#), and known-safe patterns.
    unscoped=$(grep -nE '^\s*[^#].*\/tmp/claude-[a-z]' "$f" 2>/dev/null \
        | grep -vE 'SID_SHORT|\$SID\b|\${SID\b|DOC_KEY|\$\$|cron|heartbeat|file-locks|audit|backup|notify' \
        | head -3 || true)
    if [ -n "$unscoped" ]; then
        echo "$LOG_PREFIX   [VIOLATION] $(basename "$f"): unscoped /tmp/ path"
        echo "$unscoped" | head -2 | sed "s/^/$LOG_PREFIX     /"
        violations=$((violations + 1))
    fi
done
checks_completed=$((checks_completed + 1))

# [3] Raw append without file_lock — semantic check, not in cron_audit
echo "$LOG_PREFIX [3] Raw append to shared files without file_lock"
for f in "$REPO_DIR"/scripts/cron-*.sh "$REPO_DIR"/private_scripts/cron-*.sh; do
    [ -f "$f" ] || continue
    raw_append=$(grep -n '>> .*FOLLOWUPS\|>> .*ALERTS\|>> .*AUTO-LEARNINGS' "$f" 2>/dev/null | grep -v 'file_lock\|cron_alert' | grep -v '^\s*#' | head -3 || true)
    if [ -n "$raw_append" ]; then
        echo "$LOG_PREFIX   [VIOLATION] $(basename "$f"): raw append without file_lock"
        violations=$((violations + 1))
    fi
done
checks_completed=$((checks_completed + 1))

# [4] Stale sentinel cleanup — runtime hygiene, not in cron_audit
echo "$LOG_PREFIX [4] TTL on sentinel dirs"
stale_dirs=$({ find /tmp -name "claude-prereq-*" -type d -mmin +$((60*24)) 2>/dev/null || true; } | wc -l)
stale_preflight=$({ find /tmp -name "claude-preflight-*" -type d -mmin +$((60*24)) 2>/dev/null || true; } | wc -l)
if [ "$stale_dirs" -gt 0 ] || [ "$stale_preflight" -gt 0 ]; then
    echo "$LOG_PREFIX   [WARN] $stale_dirs stale prereq dirs, $stale_preflight stale preflight dirs (>24h)"
    find /tmp -name "claude-prereq-*" -type d -mmin +$((60*24)) -exec rm -rf {} + 2>/dev/null || true
    find /tmp -name "claude-preflight-*" -type d -mmin +$((60*24)) -exec rm -rf {} + 2>/dev/null || true
fi

# Enforcement metrics summary (if log exists)
echo "$LOG_PREFIX [metrics] Enforcement summary"
METRICS_LOG="$HOME/logs/enforcement-metrics.csv"
if [ -f "$METRICS_LOG" ]; then
    total=$(tail -n +2 "$METRICS_LOG" | wc -l) || total=0
    blocked=$(grep -c ',blocked,' "$METRICS_LOG" 2>/dev/null) || blocked=0
    warned=$(grep -c ',warned,' "$METRICS_LOG" 2>/dev/null) || warned=0
    overridden=$(grep -c ',overridden,' "$METRICS_LOG" 2>/dev/null) || overridden=0
    echo "$LOG_PREFIX   Total events: $total | Blocked: $blocked | Warned: $warned | Overridden: $overridden"

    # Top 5 rules by fire count
    echo "$LOG_PREFIX   Top rules:"
    tail -n +2 "$METRICS_LOG" | cut -d, -f3 | sort | uniq -c | sort -rn | head -5 | while read count rule; do
        echo "$LOG_PREFIX     $count × $rule"
    done || true

    # Override abuse detection
    if [ "$overridden" -gt 10 ]; then
        cron_alert "override-abuse" "CLAUDE_OVERRIDE used $overridden times this period — review enforcement-metrics.csv"
        echo "$LOG_PREFIX   [WARN] Override used $overridden times — potential abuse"
        violations=$((violations + 1))
    fi

    # Trim log to last 90 days
    cutoff=$(date -d "-90 days" '+%Y-%m-%d' 2>/dev/null || date -v-90d '+%Y-%m-%d' 2>/dev/null || echo "")
    if [ -n "$cutoff" ]; then
        tmp=$(mktemp)
        head -1 "$METRICS_LOG" > "$tmp"
        tail -n +2 "$METRICS_LOG" | awk -F, -v cutoff="$cutoff" '$1 >= cutoff' >> "$tmp"
        mv "$tmp" "$METRICS_LOG"
    fi
fi

# Report
if [ "$violations" -gt 0 ]; then
    cron_alert "workflow-regression" "$violations workflow design rule violations found — check ~/logs/workflow-regression.log"
    echo "$LOG_PREFIX   $violations violations found"
else
    cron_alert_clear "workflow-regression"
    echo "$LOG_PREFIX   All checks passed"
fi

# Heartbeat only if checks actually ran (Rule 2 compliance)
if [ "$checks_completed" -gt 0 ]; then
    write_heartbeat "workflow-regression"
fi
echo "$LOG_PREFIX === Workflow Regression Done ==="
