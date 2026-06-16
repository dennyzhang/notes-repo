#!/bin/bash
# gdocs-cleanup-stale-claude-replies.sh — Delete superseded [Claude] placeholder replies.
#
# Problem: cron-gdoc-comments.sh used to post `[Claude] Seen — will address in next cycle`
# fallback replies when the LLM phase failed. A later session would then post the real
# `[Claude] Done ...` reply. The placeholder lingered, polluting the thread with two
# [Claude] replies where one would do.
#
# This script deletes any `[Claude] Seen/processing delayed/will address next cycle`
# reply that has a SUBSEQUENT `[Claude]` reply on the same comment which is NOT itself
# a placeholder. Orphan placeholders (no follow-up real reply) are left alone — they
# still represent "pending work".
#
# Usage:
#   source ~/work/claude/scripts/gdocs-cleanup-stale-claude-replies.sh
#   gdocs_cleanup_stale_claude_replies <DOC_ID> [--dry-run]
#
# Safe to run any number of times — idempotent.

gdocs_cleanup_stale_claude_replies() {
    local doc_id="$1"
    local dry_run=0
    [ "${2:-}" = "--dry-run" ] && dry_run=1

    if [ -z "$doc_id" ]; then
        echo "gdocs_cleanup_stale_claude_replies: doc_id required" >&2
        return 1
    fi

    # Fetch all comments with replies via Drive API
    local raw
    raw=$(google-mux api call GET \
        "https://www.googleapis.com/drive/v3/files/${doc_id}/comments?fields=comments(id,replies(id,content,author(displayName),createdTime))&pageSize=100" \
        2>/dev/null | python3 -c "
import re, sys
txt = sys.stdin.read()
m = re.search(r'^\{', txt, re.MULTILINE)
sys.stdout.write(txt[m.start():] if m else txt)
")

    if [ -z "$raw" ]; then
        echo "gdocs_cleanup_stale_claude_replies: could not fetch comments for $doc_id" >&2
        return 1
    fi

    # Identify stale placeholders (superseded) via python.
    # Pass $raw on stdin (via pipe); use -c for the script. A heredoc for the
    # script would steal stdin and leave sys.stdin.read() empty.
    local stale
    stale=$(printf '%s' "$raw" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
PATTERNS = ['[claude] seen', 'processing delayed', 'will address in next cycle']
def is_placeholder(c): return any(p in c.lower() for p in PATTERNS)
def is_claude(c): return c.strip().startswith('[Claude]')

stale = []
for cm in data.get('comments', []):
    cid = cm.get('id','')
    replies = sorted(cm.get('replies', []) or [], key=lambda r: r.get('createdTime',''))
    for i, rep in enumerate(replies):
        cnt = rep.get('content','')
        if not (is_claude(cnt) and is_placeholder(cnt)): continue
        for later in replies[i+1:]:
            if is_claude(later.get('content','')) and not is_placeholder(later.get('content','')):
                stale.append((cid, rep['id']))
                break
for cid, rid in stale:
    print(f'{cid}\t{rid}')
")

    local count=0
    local deleted=0
    local failed=0
    while IFS=$'\t' read -r cid rid; do
        [ -z "$cid" ] && continue
        count=$((count + 1))
        if [ "$dry_run" -eq 1 ]; then
            echo "  [dry-run] would delete ${cid}/${rid}"
            continue
        fi
        if google-mux api call DELETE \
            "https://www.googleapis.com/drive/v3/files/${doc_id}/comments/${cid}/replies/${rid}" \
            >/dev/null 2>&1; then
            deleted=$((deleted + 1))
        else
            failed=$((failed + 1))
            echo "  [WARN] failed to delete ${cid}/${rid}" >&2
        fi
    done <<< "$stale"

    if [ "$dry_run" -eq 1 ]; then
        echo "  Found ${count} stale placeholder(s) (dry-run — nothing deleted)"
    else
        echo "  Stale placeholder cleanup: ${deleted}/${count} deleted, ${failed} failed"
    fi
    return 0
}

# Allow running as standalone script: ./gdocs-cleanup-stale-claude-replies.sh <DOC_ID>
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    gdocs_cleanup_stale_claude_replies "$@"
fi
