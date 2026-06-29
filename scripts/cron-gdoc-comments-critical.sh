#!/usr/bin/env bash
# cron-gdoc-comments-critical.sh — address OPEN comments on the AI-generated docs
# Denny actively comments on, promptly (every 30 min), so feedback isn't left to
# the daily doc-regen cadence.
#
# History: the broad gdoc-comments / gdoc-comments-critical crons (all generated
# docs) were deprecated 2026-06-01 ("only routine gdoc needs updates") and the
# script deleted. But Denny keeps leaving comments on the AI Playbook expecting
# them addressed. The daily ai-health comments-first gate covers the Playbook, but
# only at 06:30 -> ~24h latency. This is the NARROW revival: just the doc(s) Denny
# iterates on, on a 30-min cadence. Reuses gdoc_address_comments_first (no new logic).
#
# Schedule: every 30 min.
# Crontab entry:
#   10,40 * * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 1200 gdoc-comments-critical ~/work/claude/scripts/cron-gdoc-comments-critical.sh >> ~/logs/gdoc-comments-critical.log 2>&1

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOCK_FILE="/tmp/cron-gdoc-comments-critical.lock"

# Docs to scan, by config doc-key (resolved via get_doc_id). Keep this list SMALL —
# only docs Denny actively comments on. The broad "all generated docs" version was
# deliberately deprecated; do not re-add every doc here.
# routine added 2026-06-27: Denny actively comments on the routine doc (had 7 open
# comments, one unaddressed for days) but it was missing here, so this cron never
# saw them — only ai_playbook was scanned.
# ai_infra_miner ("Domain — AI Infra Reliability") added 2026-06-27 per Denny.
DOC_KEYS=("ai_playbook" "routine" "ai_infra_miner")

unset CLAUDECODE CLAUDE_CODE_CURRENT_SESSION_ID 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/gdocs_lib.sh"

[ -f "$REPO_DIR/CLAUDE.md" ] || { cron_alert "gdoc-comments-critical" "Workspace missing"; exit 1; }
command -v claude &>/dev/null || { cron_alert "gdoc-comments-critical" "claude CLI not available"; exit 1; }

# Lock — runs every 30 min; an LLM comment pass can take minutes. Reclaim >25min stale.
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$lock_age" -lt 1500 ]; then
        echo "$(date '+%Y-%m-%d %H:%M') Already running (pid $pid), skipping"; exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

echo "$(date '+%Y-%m-%d %H:%M') Starting gdoc-comments-critical (docs: ${DOC_KEYS[*]})"
cd "$REPO_DIR"

for key in "${DOC_KEYS[@]}"; do
    doc_id=$(get_doc_id "$key" 2>/dev/null)
    if [ -z "$doc_id" ]; then
        echo "$(date '+%Y-%m-%d %H:%M') [WARN] no doc id for key '$key' — skipping"
        continue
    fi
    echo "$(date '+%Y-%m-%d %H:%M') Checking comments on $key ($doc_id)"
    # Cheap no-op when 0 open comments; runs a bounded LLM pass only when one exists.
    gdoc_address_comments_first "$doc_id"
done

cron_alert_clear "gdoc-comments-critical"
write_heartbeat "gdoc-comments-critical"
echo "$(date '+%Y-%m-%d %H:%M') gdoc-comments-critical done"
