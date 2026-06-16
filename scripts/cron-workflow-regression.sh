#!/usr/bin/env bash
# cron-workflow-regression.sh — Weekly regression test for workflow design rules.
# Checks all cron scripts and hooks against the 6 design rules.
# Reports violations to ALERTS.md.
#
# Schedule: Weekly Sunday 8 PM via setup-claude.sh crontab

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"

source "$SCRIPT_DIR/cron-alert.sh"

echo "$LOG_PREFIX === Workflow Design Regression ==="

violations=0

# Rule 1: Session Isolation — check for unscoped /tmp/ paths in hooks
echo "$LOG_PREFIX [1] Session Isolation"
for f in "$REPO_DIR"/config/hooks/*.sh "$REPO_DIR"/scripts/enforce-prerequisites.sh; do
    [ -f "$f" ] || continue
    # Find /tmp/claude- paths that don't use ${SID or $$ or ${DOC_KEY
    # grep -v returns 1 when it filters out ALL lines; || true prevents pipefail abort
    unscoped=$(grep -n '/tmp/claude-[a-z]' "$f" 2>/dev/null | grep -v 'SID_SHORT\|DOC_KEY\|\$\$\|cron\|heartbeat\|file-locks\|audit\|backup' | head -3 || true)
    if [ -n "$unscoped" ]; then
        echo "$LOG_PREFIX   [VIOLATION] $(basename $f): unscoped /tmp/ path"
        echo "$unscoped" | head -2
        violations=$((violations + 1))
    fi
done

# Rule 2: Heartbeat Integrity — check for unconditional heartbeats
echo "$LOG_PREFIX [2] Heartbeat Integrity"
checks_completed=0
for f in "$REPO_DIR"/scripts/cron-*.sh; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .sh)
    # Skip libraries and non-cron scripts
    [[ "$name" == "cron-alert" || "$name" == "cron-workflow-self-eval" || "$name" == "cron-workflow-regression" ]] && continue
    # Check ALL heartbeat lines (not just the last one)
    while IFS= read -r heartbeat_line; do
        [ -z "$heartbeat_line" ] && continue
        line_num=$(echo "$heartbeat_line" | cut -d: -f1)
        # Check if the 3 lines before contain a conditional
        context=$(sed -n "$((line_num > 3 ? line_num-3 : 1)),$((line_num))p" "$f" 2>/dev/null)
        if ! echo "$context" | grep -qE 'if |then|&&|\[\['; then
            echo "$LOG_PREFIX   [VIOLATION] $name: unconditional heartbeat at line $line_num"
            violations=$((violations + 1))
        fi
    done < <(grep -n 'cron-heartbeat-' "$f" 2>/dev/null | grep 'echo.*date')
    checks_completed=$((checks_completed + 1))
done

# Rule 3: Dedup Before Append — check for raw >> to shared files without lock
echo "$LOG_PREFIX [3] Dedup Before Append"
for f in "$REPO_DIR"/scripts/cron-*.sh; do
    [ -f "$f" ] || continue
    # Check for raw appends to FOLLOWUPS.md or ALERTS.md without file_lock
    # Only exclude actual comment lines (starting with #), not lines containing # anywhere
    raw_append=$(grep -n '>> .*FOLLOWUPS\|>> .*ALERTS\|>> .*AUTO-LEARNINGS' "$f" 2>/dev/null | grep -v 'file_lock\|cron_alert' | grep -v '^\s*#' | head -3 || true)
    if [ -n "$raw_append" ]; then
        echo "$LOG_PREFIX   [VIOLATION] $(basename $f): raw append without file_lock"
        violations=$((violations + 1))
    fi
    checks_completed=$((checks_completed + 1))
done

# Rule 6: TTL on All State — check for sentinel files without age check
echo "$LOG_PREFIX [6] TTL on State"
# Count stale sentinel dirs in /tmp
# find can return non-zero on unreadable /tmp subdirs; pipefail + set -e would abort
stale_dirs=$({ find /tmp -name "claude-prereq-*" -type d -mmin +$((60*24)) 2>/dev/null || true; } | wc -l)
stale_preflight=$({ find /tmp -name "claude-preflight-*" -type d -mmin +$((60*24)) 2>/dev/null || true; } | wc -l)
if [ "$stale_dirs" -gt 0 ] || [ "$stale_preflight" -gt 0 ]; then
    echo "$LOG_PREFIX   [WARN] $stale_dirs stale prereq dirs, $stale_preflight stale preflight dirs (>24h old)"
    # Clean them up
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
