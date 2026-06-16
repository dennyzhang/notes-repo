#!/usr/bin/env bash
# gdocs-safe-write.sh — Comment-safe wrapper for ALL Google Doc write operations.
#
# POLICY: User's Google Doc comments must NEVER be deleted.
# This wrapper checks comment count before ANY destructive operation.
# Used by cron scripts (which don't go through Claude Code hooks).
#
# FAIL CLOSED: if we can't check comments (gmux down, timeout), BLOCK.
# Never assume "0 comments" when the check fails.
#
# Usage:
#   source ~/work/claude/scripts/gdocs-safe-write.sh
#   gdocs_safe_replace <DOC_ID> [gdocs replace args...]
#   gdocs_safe_apply <DOC_ID> [gdocs apply args...]
#
# If doc has >0 comments OR check fails → HARD BLOCK, return 1. No override.

_check_comments() {
    local doc_id="$1"
    local operation="$2"
    # Delegate to the shared Python helper (encapsulates gmux call + parse).
    # Exit 1 from the helper → fail closed.
    local helper_py
    helper_py="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/gdocs_helper.py"
    local count
    if ! count=$(python3 "$helper_py" count-comments --doc-id "$doc_id" 2>&1); then
        echo "[gdocs-safe-write] BLOCKED: Could not verify comment count for $doc_id (gmux/helper error)."
        echo "[gdocs-safe-write] Details: $count"
        echo "[gdocs-safe-write] Fix gmux or use find-replace/batch-update."
        return 1
    fi
    if [ "$count" -gt 0 ]; then
        echo "[gdocs-safe-write] BLOCKED: Doc $doc_id has $count comments."
        echo "[gdocs-safe-write] $operation would destroy comments. Use find-replace or batch-update."
        return 1
    fi
    echo "[gdocs-safe-write] Doc has 0 comments. $operation allowed."
    return 0
}

gdocs_safe_replace() {
    local doc_id="$1"
    shift
    _check_comments "$doc_id" "gdocs replace" || return 1
    gdocs replace "$doc_id" "$@"
}

gdocs_safe_apply() {
    local doc_id="$1"
    shift
    _check_comments "$doc_id" "gdocs apply" || return 1
    gdocs apply "$doc_id" "$@"
}
