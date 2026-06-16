#!/usr/bin/env bash
# cron-upstream-outside.sh — Check external GitHub repos for updates
# Runs on MAC (has direct internet access). Devserver fwdproxy blocks api.github.com.
#
# FAST PATH: checks SHAs in pure bash first. Only invokes Claude if repos actually changed.
# Quick mode (cron default): only high-priority repos (4 of 8).
#
# Crontab entry:
#   0 7,15,23 * * * $HOME/work/claude/scripts/cron-upstream-outside.sh >> ~/logs/upstream-outside.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOCK_FILE="/tmp/cron-upstream-outside.lock"
REPOS_YAML="$REPO_DIR/config/UPSTREAM-REPOS.yaml"

# Clear Claude Code session markers so nested claude -p works
unset CLAUDECODE 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Pre-check: workspace exists
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "upstream-outside" "Workspace missing — ~/work/claude/CLAUDE.md missing"
    exit 1
fi

# Prevent overlapping runs
LOCK_MAX_AGE_SECONDS=7200
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if [ "$lock_age" -gt "$LOCK_MAX_AGE_SECONDS" ]; then
            echo "$(date '+%Y-%m-%d %H:%M') Lock held by pid $pid for ${lock_age}s (>${LOCK_MAX_AGE_SECONDS}s) — killing stale process"
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
        else
            echo "$(date '+%Y-%m-%d %H:%M') Already running (pid $pid, age ${lock_age}s), skipping"
            exit 0
        fi
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

echo "$(date '+%Y-%m-%d %H:%M') Starting upstream-outside scan (quick mode)"

# Verify internet access
if ! curl -s --connect-timeout 5 --max-time 15 https://api.github.com/rate_limit >/dev/null; then
    cron_alert "upstream-outside" "GitHub API unreachable — check internet connection"
    exit 1
fi

# ========== FAST PATH: bash-only SHA check ==========
# Extract high-priority repos and their SHAs, check for changes without Claude.
# Format: owner/repo branch last_sha
changed_repos=""
checked=0
unchanged=0

# Parse high-priority repos from YAML (simple grep-based, no yq dependency)
while IFS= read -r line; do
    # Extract owner, repo, branch, last_checked_sha for high-priority repos
    owner=$(echo "$line" | cut -d'|' -f1)
    repo=$(echo "$line" | cut -d'|' -f2)
    branch=$(echo "$line" | cut -d'|' -f3)
    old_sha=$(echo "$line" | cut -d'|' -f4)
    name=$(echo "$line" | cut -d'|' -f5)

    new_sha=$(curl -s --connect-timeout 5 --max-time 15 "https://api.github.com/repos/${owner}/${repo}/commits/${branch}" | grep -m1 '"sha"' | sed 's/.*"sha": *"//;s/".*//' || true)

    if [ -z "$new_sha" ]; then
        echo "  WARNING: Failed to fetch SHA for ${owner}/${repo}"
        continue
    fi

    checked=$((checked + 1))

    if [ "$new_sha" = "$old_sha" ]; then
        unchanged=$((unchanged + 1))
    else
        changed_repos="${changed_repos}${name} "
        echo "  CHANGED: ${name} (${old_sha:0:8} -> ${new_sha:0:8})"
    fi
done <<EOF
$(awk '
/^  - name:/ { name=$3 }
/owner:/ { owner=$2 }
/repo:/ { repo=$2 }
/branch:/ { branch=$2 }
/priority: high/ { is_high=1 }
/priority: low/ { is_high=0 }
/last_checked_sha:/ {
    sha=$2;
    if (is_high) print owner"|"repo"|"branch"|"sha"|"name
}
' "$REPOS_YAML")
EOF

echo "$(date '+%Y-%m-%d %H:%M') Checked $checked high-priority repos: $unchanged unchanged"

# If no repos changed, we're done — no need to invoke Claude at all
if [ -z "$changed_repos" ]; then
    echo "$(date '+%Y-%m-%d %H:%M') All repos up to date. Skipping Claude invocation."
    cron_alert_clear "upstream-outside"
    write_heartbeat "upstream-outside"
    exit 0
fi

# ========== SLOW PATH: invoke Claude only for changed repos ==========
echo "$(date '+%Y-%m-%d %H:%M') Changes detected in: $changed_repos — invoking Claude for analysis"

if ! command -v claude &>/dev/null; then
    cron_alert "upstream-outside" "claude CLI not available"
    exit 1
fi

cd "$REPO_DIR"
exit_code=0
run_llm "upstream-outside" 1800 /dev/stdout "You are running as a cron job. Execute /my-upstream outside quick:

Changes detected in repos: ${changed_repos}

1. Read config/UPSTREAM-REPOS.yaml
2. For ONLY the changed repos listed above, fetch comparison and analyze watch_paths for new patterns
3. Log cherry-pick candidates to context/cache/UPSTREAM-SCAN-LOG.md
4. Update last_checked_sha and last_checked_date in UPSTREAM-REPOS.yaml
5. Output: 'Upstream Outside: N candidates from M repos'

Do NOT apply changes. Just log candidates." -- \
    --allowedTools Bash Read Write Edit Glob Grep \
    --model opus \
    --max-turns 30 || exit_code=$?

if [ $exit_code -eq 0 ]; then
    # Verify scan log was actually updated
    SCAN_LOG="$REPO_DIR/context/cache/UPSTREAM-SCAN-LOG.md"
    if [ -f "$SCAN_LOG" ]; then
        scan_date=$(date -r "$SCAN_LOG" +%Y-%m-%d 2>/dev/null || echo "unknown")
        if [ "$scan_date" = "$(date +%Y-%m-%d)" ]; then
            echo "$(date '+%Y-%m-%d %H:%M') Analysis complete and verified"
        else
            echo "$(date '+%Y-%m-%d %H:%M') WARNING: UPSTREAM-SCAN-LOG.md not updated today (last: $scan_date)"
        fi
    fi
    cron_alert_clear "upstream-outside"
else
    cron_alert "upstream-outside" "Analysis failed with exit code $exit_code — check /tmp/cron-upstream-outside-err.log"
    echo "$(date '+%Y-%m-%d %H:%M') Analysis failed (exit $exit_code)"
fi

# Write heartbeat sentinel
write_heartbeat "upstream-outside"
