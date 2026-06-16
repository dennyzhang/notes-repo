#!/bin/bash
# Daily disk cleanup for devserver
#
# Install: crontab -e → 0 */4 * * * ~/notes/users/dennyzhang/scripts/disk-cleanup.sh >> ~/disk-cleanup.log 2>&1

set -euo pipefail

LOG_TAG="disk-cleanup"
TIMEOUT=300  # 5 min max per step

log() {
    logger -t "$LOG_TAG" "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

clear_dir() {
    local dir="$1" label="$2"
    if [ -d "$dir" ]; then
        size=$(du -sm "$dir" 2>/dev/null | cut -f1)
        rm -rf "$dir"/* 2>/dev/null || sudo rm -rf "$dir"/* 2>/dev/null || true
        log "Cleared $label (${size}MB)"
    fi
}

avail_before=$(df -h / | awk 'NR==2{print $4}')
log "Starting disk cleanup (available: $avail_before)"

# --- Caches (all re-download on demand) ---

clear_dir "$HOME/.cache/dotslash" "dotslash cache"
clear_dir /var/cache/hgcache "hgcache"
clear_dir /var/cache/casd/keyed_blake3 "CAS daemon cache"

if command -v dnf &>/dev/null; then
    dnf clean all &>/dev/null
    log "Cleared dnf cache"
fi

# --- Temp files ---

clear_dir /var/tmp/cores "core dumps"

# Claude Code worktree session dirs (can grow to 50G+ each)
# Use ls instead of find to avoid hanging on stale mounts inside /tmp
worktree_dirs=$(ls -d /tmp/.tmp* 2>/dev/null) || true
if [ -n "$worktree_dirs" ]; then
    count=$(echo "$worktree_dirs" | wc -l)
    echo "$worktree_dirs" | xargs -P4 rm -rf 2>/dev/null || true
    log "Cleared $count Claude Code worktree dirs from /tmp"
fi

# PAR unpack caches
par_dirs=$(ls -d /tmp/par_unpack.* 2>/dev/null) || true
if [ -n "$par_dirs" ]; then
    count=$(echo "$par_dirs" | wc -l)
    echo "$par_dirs" | sudo xargs -P4 rm -rf 2>/dev/null || true
    log "Cleared $count PAR unpack dirs"
fi

# fastzip castree caches
rm -rf /tmp/fastzip-castree-* 2>/dev/null || true
log "Cleared fastzip-castree caches"

rm -rf /tmp/confucius_cli_fbpkg_cache 2>/dev/null || true

# --- Logs ---

timeout $TIMEOUT find /var/log -name "*.gz" -delete 2>/dev/null || true
timeout $TIMEOUT find /var/log -name "*.[0-9]" -delete 2>/dev/null || true
timeout $TIMEOUT find /var/log -name "*.old" -delete 2>/dev/null || true
sudo rm -f /var/log/messages-* 2>/dev/null || true
log "Cleared rotated logs"

sudo rm -rf /var/log/below/* 2>/dev/null || true
log "Cleared below resource logs"

journalctl --vacuum-time=7d &>/dev/null 2>&1 || true
log "Vacuumed journal"

# --- Xarfuse ---

timeout $TIMEOUT find /mnt/xarfuse -mindepth 2 -name ".xar_cache" -type d -exec rm -rf {} + 2>/dev/null || true
log "Cleared xarfuse caches"

# --- Eden ---

eden gc 2>/dev/null && log "Eden GC complete" || true

# --- Final ---

sync
avail_after=$(df -h / | awk 'NR==2{print $4}')
log "Cleanup complete. Available: $avail_before → $avail_after"
