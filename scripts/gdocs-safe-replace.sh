#!/usr/bin/env bash
# gdocs-safe-replace.sh — Comment-safe wrapper for gdocs replace.
#
# EVERY script and session that wants to replace Google Doc content
# MUST use this wrapper instead of calling gdocs replace directly.
#
# It checks comment count BEFORE replacing. If comments > 0, it BLOCKS.
# No flag, no override, no exception.
#
# Usage:
#   bash gdocs-safe-replace.sh <DOC_ID> [--tab-id TAB] --from <FILE> [other gdocs flags]
#
# If blocked: exits 1 with instructions to use batch-update instead.

set -eo pipefail

# Extract doc ID (first arg or from flags)
DOC_ID=""
ARGS=("$@")
for arg in "${ARGS[@]}"; do
    if [[ "$arg" =~ ^[a-zA-Z0-9_-]{25,}$ ]] && [ -z "$DOC_ID" ]; then
        DOC_ID="$arg"
    fi
done

if [ -z "$DOC_ID" ]; then
    echo "ERROR: Could not extract doc ID from arguments"
    echo "Usage: bash gdocs-safe-replace.sh <DOC_ID> --from <FILE> [flags]"
    exit 1
fi

# Tab-scoped replace: when --tab-id is a non-default tab (not t.0), gdocs replace
# only touches that tab's content. Comments live on their own tabs, so replacing
# tab B doesn't destroy comments on tab A. Skip the doc-level comment check.
TAB_ID=""
for ((i=0; i<${#ARGS[@]}; i++)); do
    if [[ "${ARGS[$i]}" == "--tab-id" ]] && [[ $((i+1)) -lt ${#ARGS[@]} ]]; then
        TAB_ID="${ARGS[$((i+1))]}"
    fi
done
if [[ -n "$TAB_ID" && "$TAB_ID" != "t.0" ]]; then
    echo "[gdocs-safe-replace] Tab-scoped replace (${TAB_ID}) — skipping doc-level comment check."
    exec gdocs replace "$@"
fi

# HARD CHECK: count comments — FAIL CLOSED via the shared Python helper.
# The helper encapsulates gmux invocation, banner stripping, and JSON parse.
HELPER_PY="$(cd "$(dirname "$0")" && pwd)/lib/gdocs_helper.py"
COMMENT_COUNT=$(python3 "$HELPER_PY" count-comments --doc-id "$DOC_ID" 2>&1) || {
    echo "HARD BLOCKED: Could not verify comment count (gmux timeout or API error)."
    echo "Assuming doc has comments. Fix gmux first, or use find-replace/batch-update."
    echo "Details: $COMMENT_COUNT"
    exit 1
}

if [ "$COMMENT_COUNT" -gt 0 ]; then
    echo "HARD BLOCKED: Doc $DOC_ID has $COMMENT_COUNT comments."
    echo "gdocs replace would destroy ALL of them. No override available."
    echo ""
    echo "Use instead:"
    echo "  python3 ~/work/claude/private_scripts/ai-health-push.py  (for AI Health Dashboard)"
    echo "  gdocs content find-replace  (for text changes)"
    echo "  gdocs batch-update  (for table cell updates)"
    echo "  gdocs content insert-text  (for adding content)"
    exit 1
fi

# 0 comments — safe to replace
echo "[gdocs-safe-replace] Doc has 0 comments. Proceeding with replace."
exec gdocs replace "$@"
