#!/usr/bin/env bash
# cron-keepalive.sh — SSH mux + google-mux daemon keepalive (every 10 min).
#
# Ensures persistent SSH connections to devservers/GPU servers.
# Session watchdog moved to cron-session-watchdog.sh.
#
# Usage:
#   bash cron-keepalive.sh                   # Run SSH keepalive
#   bash cron-keepalive.sh --ssh-status      # Show SSH socket status only
#   bash cron-keepalive.sh --ssh-kill        # Tear down all SSH sockets
#
# Crontab: */10 * * * * bash ~/work/claude/scripts/cron-keepalive.sh >> ~/logs/keepalive.log 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cron-alert.sh"
# Removed: ensure_gmux_healthy call here was redundant — gmux_ensure_daemon() at the end
# does a full check+restart cycle. Running both back-to-back wasted 23s worst-case.

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [keepalive] $*"; }

# ========================================================================
# Section 1: SSH Connectivity Keepalive
# ========================================================================

# Authoritative server list — keep in sync with config/INFRASTRUCTURE.md "Devservers" table.
SERVERS=(
    "devvm32180.nha0.facebook.com"
    "devvm28012.ftw0.facebook.com"
)
MUX_DIR="$HOME/ssh-mux"
SSH_OPTS="-o ControlPath=$MUX_DIR/%h -o ServerAliveInterval=30 -o ServerAliveCountMax=3"

load_servers() {
    if [[ ${#SERVERS[@]} -eq 0 ]]; then
        log "WARN: No servers configured — skipping SSH keepalive"
        return 1
    fi
    mkdir -p "$MUX_DIR"
    return 0
}

check_socket() { ssh -F /dev/null $SSH_OPTS -O check "$1" 2>/dev/null; }

start_autossh() {
    autossh -M 0 -f -N \
        -o ControlMaster=yes $SSH_OPTS -o ControlPersist=yes "$1"
}

start_plain_ssh() {
    ssh -o ControlMaster=yes $SSH_OPTS -o ControlPersist=yes -fN "$1"
}

kill_socket() {
    ssh -F /dev/null $SSH_OPTS -O exit "$1" 2>/dev/null
    pkill -f "autossh.*$1" 2>/dev/null
}

ssh_status_only() {
    load_servers || return
    for host in "${SERVERS[@]}"; do
        if check_socket "$host"; then echo "OK    $host"
        else echo "DOWN  $host"; fi
    done
}

ssh_kill_all() {
    load_servers || return
    for host in "${SERVERS[@]}"; do
        echo "Killing socket for $host..."
        kill_socket "$host"
    done
    echo "All sockets torn down."
}

ssh_ensure_connections() {
    load_servers || return
    local has_autossh=false
    local failed_hosts=()
    command -v autossh &>/dev/null && has_autossh=true

    for host in "${SERVERS[@]}"; do
        if check_socket "$host"; then
            log "SSH OK    $host"
            continue
        fi

        log "SSH DOWN  $host — reconnecting..."
        pkill -f "autossh.*$host" 2>/dev/null
        rm -f "$MUX_DIR/$host"

        local connected=false
        if $has_autossh; then
            if start_autossh "$host"; then
                log "SSH UP    $host (autossh)"
                connected=true
            else
                log "SSH FAIL  $host (autossh failed, trying plain ssh...)"
                if start_plain_ssh "$host"; then
                    log "SSH UP    $host (plain ssh)"
                    connected=true
                fi
            fi
        else
            if start_plain_ssh "$host"; then
                log "SSH UP    $host (plain ssh)"
                connected=true
            fi
        fi

        if $connected; then
            cron_alert_clear "server-keepalive-${host%%.*}"
        else
            log "SSH FAIL  $host"
            failed_hosts+=("$host")
        fi
    done

    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        for fhost in "${failed_hosts[@]}"; do
            cron_alert "server-keepalive-${fhost%%.*}" "SSH mux to ${fhost} failed — check credentials or server status"
        done
    else
        for host in "${SERVERS[@]}"; do
            cron_alert_clear "server-keepalive-${host%%.*}"
        done
    fi
}

# ========================================================================
# Section 2: Google-Mux Daemon Keepalive
# ========================================================================
# The google-mux daemon holds CAT/DCAT auth context from the interactive
# session that started it. Cron jobs can't create DCAT tokens (no FBID in
# cron env), but they CAN use the daemon socket if it's alive.
# This section keeps the daemon alive by checking its status and pinging it.

# Socket path uses a random suffix now — find it dynamically
GMUX_SOCKET="$(ls /tmp/gmux-${USER}*.sock 2>/dev/null | head -1)"

cert_ensure_fresh() {
    # Renew FBID cert via clicat create. This is lightweight and idempotent.
    # Without a valid cert, google-mux and meta CLI both fail.
    #
    # Track cert mtime to detect actual renewals (not just idempotent no-ops).
    # When the cert changes, the daemon must be restarted to pick up new auth.
    local cert_path="/var/facebook/credentials/$USER/x509/$USER.pem"
    local old_mtime=""
    [ -f "$cert_path" ] && old_mtime=$(stat -c %Y "$cert_path" 2>/dev/null || echo "")

    if clicat create &>/dev/null; then
        log "CERT OK   clicat create succeeded"
    else
        log "CERT FAIL clicat create failed"
        cron_alert "cert-renewal" "clicat create failed — Google API and meta CLI will break"
        return 1
    fi
    cron_alert_clear "cert-renewal"

    # If cert was actually renewed (mtime changed), restart daemon to pick up fresh auth
    local new_mtime=""
    [ -f "$cert_path" ] && new_mtime=$(stat -c %Y "$cert_path" 2>/dev/null || echo "")
    if [ -n "$old_mtime" ] && [ -n "$new_mtime" ] && [ "$old_mtime" != "$new_mtime" ]; then
        log "CERT RENEWED (mtime $old_mtime → $new_mtime) — forcing daemon restart"
        pkill -9 'google-mux' 2>/dev/null || true
        rm -f "$GMUX_SOCKET"
        sleep 1
    fi

    return 0
}

gmux_ensure_daemon() {
    local daemon_pid
    daemon_pid=$(pgrep -f 'google-mux.*daemon' | head -1 || echo '')

    # Re-discover socket (may have been created since script start)
    GMUX_SOCKET="$(ls /tmp/gmux-${USER}*.sock 2>/dev/null | head -1)"

    if [ -n "$GMUX_SOCKET" ] && [ -S "$GMUX_SOCKET" ] && google-mux daemon status &>/dev/null; then
        # Daemon reports alive — but is it actually responsive? Probe with timeout.
        # A wedged daemon passes status checks but hangs on actual API calls.
        if timeout 10 gdocs tabs list "$(get_doc_id routine)" &>/dev/null; then
            log "GMUX OK   daemon alive + responsive (pid ${daemon_pid:-?})"
            cron_alert_clear "gmux-daemon"
            return 0
        else
            # Daemon is alive but wedged — kill it and restart below
            log "GMUX WEDGE daemon alive but not responsive — killing"
            pkill -9 'google-mux' 2>/dev/null || true
            rm -f /tmp/gmux-${USER}*.sock
            sleep 2
        fi
    fi

    # Kill any orphaned daemon processes before starting fresh
    if [ -n "$daemon_pid" ]; then
        pkill -9 'google-mux' 2>/dev/null || true
        rm -f /tmp/gmux-${USER}*.sock
        sleep 1
    fi

    # Daemon not running (or just killed above) — start it
    log "GMUX DOWN daemon not running — attempting restart..."
    google-mux daemon start --background --idle-timeout 86400 2>/dev/null
    sleep 3
    if google-mux daemon status &>/dev/null; then
        log "GMUX UP   daemon restarted"
        cron_alert_clear "gmux-daemon"
    else
        log "GMUX FAIL daemon restart failed"
        cron_alert "gmux-daemon" "google-mux daemon failed to start — gdocs/gchat cron jobs will fail"
    fi
}

# ========================================================================
# Section 3: Agent x509 Cert Keepalive
# ========================================================================
# The credential agent on devservers manages /var/facebook/credentials/
# (ramfs). It creates symlinks for claude_code_$USER.pem but never
# generates the actual cert (fb-sks-agent isn't installed). Our workaround
# copies the confucius cert to that path, but the credential agent can
# overwrite it with a broken symlink. This section re-copies as needed.

cert_ensure_agent_x509() {
    local user
    user=$(whoami)
    local agent_x509="/var/facebook/credentials/$user/agent_x509"
    local broken_cert="$agent_x509/claude_code_${user}.pem"
    local fallback_cert="$agent_x509/confucius.pem"

    # Only act if confucius cert exists (it's our source of truth)
    if [ ! -f "$fallback_cert" ]; then
        log "CERT SKIP no confucius cert to copy from"
        return 0
    fi

    # Check if claude_code cert is missing or is a broken symlink
    if [ ! -f "$broken_cert" ]; then
        cp "$fallback_cert" "$broken_cert" 2>/dev/null \
            && log "CERT FIX  copied confucius → claude_code_${user}.pem" \
            || log "CERT FAIL could not copy cert (permission denied?)"
    fi
}

# ========================================================================
# Section 4: Tab-Level Staleness Check
# ========================================================================
# Checks tab_freshness_mark sentinels written by each cron script.
# Each sentinel records the epoch when a specific gdoc tab was last updated.
# Alerts if any tab hasn't been updated within its expected cadence.
# No API calls needed — purely local sentinel files.
# Only runs once per hour (not every 10 min).

STALENESS_SENTINEL="$CLAUDE_STATE_DIR/last-staleness-check"

gdoc_staleness_check() {
    # Rate limit: only run once per hour
    if [ -f "$STALENESS_SENTINEL" ]; then
        local last_check
        last_check=$(cat "$STALENESS_SENTINEL" 2>/dev/null || echo 0)
        local now
        now=$(date +%s)
        if (( now - last_check < 3600 )); then
            return 0
        fi
    fi

    # Only check during working hours (7 AM - 11 PM) when crons should have run
    local hour
    hour=$(date +%H)
    if (( hour < 7 )); then
        return 0
    fi

    log "STALENESS checking tab freshness via sentinels..."

    # Tab registry: sentinel_key | display_name | max_age_hours | cron_schedule
    local -a tabs=(
        "routine-daily-digest|Routine > Daily Digest|8|2 AM daily"
        "routine-workflow-eval|Routine > Workflow Eval|8|2 AM daily"
        "area-org-monitor|Routine > Org Monitor|28|3 AM daily"
        "area-ai-skill-monitor|Routine > AI Skill Monitor|28|3 AM daily"
    )
    # 2026-06-01 (Denny: only routine gdoc updates now): removed probes for tabs fed
    # by retired crons — ai-playbook-health (ai-health), project-* (project-gdoc-sync),
    # shared-doc-scanner. Only routine + area-monitor tabs are still maintained.

    local now_epoch
    now_epoch=$(date +%s)
    local stale_tabs=""
    local checked=0
    local stale=0
    local missing=0

    for entry in "${tabs[@]}"; do
        IFS='|' read -r key name max_age_hours schedule <<< "$entry"
        local sentinel_file="$TAB_FRESHNESS_DIR/$key"
        checked=$((checked + 1))

        if [ ! -f "$sentinel_file" ]; then
            # Sentinel doesn't exist yet — cron hasn't run since instrumentation
            missing=$((missing + 1))
            log "STALENESS MISS  $name — no sentinel yet (will appear after next cron run)"
            continue
        fi

        local last_epoch
        last_epoch=$(cat "$sentinel_file" 2>/dev/null || echo 0)
        local age_hours=$(( (now_epoch - last_epoch) / 3600 ))

        if (( age_hours >= max_age_hours )); then
            stale=$((stale + 1))
            log "STALENESS STALE $name — ${age_hours}h since last update (threshold: ${max_age_hours}h, schedule: $schedule)"
            stale_tabs="${stale_tabs}${name} (${age_hours}h), "
            cron_alert "stale-tab-${key}" "${name} not updated in ${age_hours}h — check its cron ($schedule)"
        else
            log "STALENESS OK    $name — ${age_hours}h ago"
            cron_alert_clear "stale-tab-${key}"
        fi
    done

    if [ $stale -gt 0 ]; then
        log "STALENESS RESULT ${stale}/${checked} tabs stale: ${stale_tabs%, }"
    else
        log "STALENESS RESULT all ${checked} tabs OK ($missing awaiting first sentinel)"
    fi

    # Write sentinel
    echo "$now_epoch" > "$STALENESS_SENTINEL"
}

# ========================================================================
# Main
# ========================================================================

case "${1:-}" in
    --ssh-status) ssh_status_only ;;
    --ssh-kill)   ssh_kill_all ;;
    *)
        ssh_ensure_connections
        cert_ensure_fresh
        cert_ensure_agent_x509
        gmux_ensure_daemon
        gdoc_staleness_check
        write_heartbeat "keepalive"
        ;;
esac
