#!/usr/bin/env bash
# cron-auth-sync-nudge.sh — Nudge Denny to re-auth MyClaw before it expires.
#
# How it works:
#   1. Every 15 min, check MyClaw auth state via GraphQL (xfb_myclaw_auth_status)
#   2. If not authenticated, post ONE nudge to the MyClaw briefing GChat space
#      with the click-once re-auth action
#   3. 6h cooldown on nudges (don't re-ping if user hasn't acted yet)
#
# Reinstall-survivable: lives in the repo, registered in setup-claude.sh cron block.
#
# Schedule: */15 * * * * (every 15 min)
# Log: ~/logs/auth-sync-nudge.log
# State: ~/work/claude/state/auth-sync-nudge-last

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/cron-alert.sh"

STATE_FILE="$CLAUDE_STATE_DIR/auth-sync-nudge-last"
COOLDOWN=21600  # 6h — avoid spam if user hasn't acted

NOW=$(date +%s)

# Cooldown check
if [ -f "$STATE_FILE" ]; then
    last=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    since=$((NOW - last))
    if [ "$since" -lt "$COOLDOWN" ]; then
        cron_log "[SKIP] Cooldown: last nudge ${since}s ago (cooldown ${COOLDOWN}s)"
        write_heartbeat "auth-sync-nudge"
        exit 0
    fi
fi

# MyClaw auth state via GraphQL. We only use `is_authenticated`; the schema's
# `auth_url` is a bare redirect path without scheme/hostname, so we build the
# full URL with the user's FQDN below.
my_status="unknown"
if jf_out=$(jf graphql --query 'query { xfb_myclaw_auth_status { is_authenticated } }' 2>/dev/null); then
    my_status=$(python3 -c "import json,sys; print(json.load(sys.stdin)['xfb_myclaw_auth_status']['is_authenticated'])" <<< "$jf_out" 2>/dev/null || echo "unknown")
fi

if [ "$my_status" != "False" ]; then
    cron_log "[OK] MyClaw auth fresh (status=$my_status)"
    write_heartbeat "auth-sync-nudge"
    exit 0
fi

cron_log "[TRIGGER] MyClaw expired"

hostname_fqdn=$(hostname -f 2>/dev/null || hostname)
my_url="https://www.internalfb.com/intern/myclaw_auth_redirect/?hostname=$hostname_fqdn"
msg=$(cat <<EOF
🔐 *MyClaw auth — one click re-auth*

MyClaw auth expired.

  → Click: $my_url
       Approve the Duo push → "You're In" page → done.

Fallback if the URL is broken: type \`/reauth\` in any MyClaw GChat message.
EOF
)

# Send to the MyClaw briefing space (DAILY-DOCS.json gchat_spaces -> "briefing").
SPACE=$(get_gchat_space briefing)
if echo -e "$msg" | google-mux chat send "$SPACE" - 2>&1; then
    echo "$NOW" > "$STATE_FILE"
    cron_log "[SENT] Auth nudge to $SPACE"
    write_heartbeat "auth-sync-nudge"
else
    cron_alert "auth-sync-nudge" "google-mux chat send failed"
    exit 1
fi
