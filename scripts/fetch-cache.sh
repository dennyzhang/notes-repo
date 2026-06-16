#!/usr/bin/env bash
# fetch-cache.sh — Shared fetch cache for expensive API calls.
# Source this, then use: cached_fetch "key" "max_age_seconds" "fetch_command"
#
# If cached data exists and is fresh (< max_age), returns cached data.
# If stale or missing, runs fetch_command, caches result, returns it.
#
# Usage:
#   source scripts/fetch-cache.sh
#   data=$(cached_fetch "gchat-space-SPACEID" 1800 "google-mux chat messages SPACEID --limit 50")
#   data=$(cached_fetch "gdoc-comments-DOCID" 900 "gdocs comments list DOCID --untrusted-authors-mode")

FETCH_CACHE_DIR="${FETCH_CACHE_DIR:-$HOME/work/claude/state/fetch-cache}"
mkdir -p "$FETCH_CACHE_DIR" 2>/dev/null

cached_fetch() {
    local key="$1"
    local max_age="$2"
    shift 2
    local cmd="$*"
    
    local cache_file="$FETCH_CACHE_DIR/${key}.cache"
    local sentinel="$FETCH_CACHE_DIR/${key}.ts"
    
    # Check if cache is fresh
    if [ -f "$cache_file" ] && [ -f "$sentinel" ]; then
        local cached_ts=$(cat "$sentinel" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local age=$((now - cached_ts))
        if [ "$age" -lt "$max_age" ]; then
            # Cache hit — return cached data
            cat "$cache_file"
            return 0
        fi
    fi
    
    # Cache miss — fetch, cache, return
    local result
    result=$(eval "$cmd" 2>/dev/null)
    local exit_code=$?
    
    if [ "$exit_code" -eq 0 ] && [ -n "$result" ]; then
        echo "$result" > "$cache_file"
        echo "$(date +%s)" > "$sentinel"
    fi
    
    echo "$result"
    return $exit_code
}

# Utility: check if a fetch was done recently (without fetching)
is_fresh() {
    local key="$1"
    local max_age="$2"
    local sentinel="$FETCH_CACHE_DIR/${key}.ts"
    
    if [ -f "$sentinel" ]; then
        local cached_ts=$(cat "$sentinel" 2>/dev/null || echo 0)
        local age=$(($(date +%s) - cached_ts))
        [ "$age" -lt "$max_age" ] && return 0
    fi
    return 1
}

# Utility: invalidate cache for a key
invalidate_cache() {
    local key="$1"
    rm -f "$FETCH_CACHE_DIR/${key}.cache" "$FETCH_CACHE_DIR/${key}.ts"
}

# Cleanup: remove cache files older than 24h
cleanup_fetch_cache() {
    find "$FETCH_CACHE_DIR" -type f -mmin +1440 -delete 2>/dev/null
}
