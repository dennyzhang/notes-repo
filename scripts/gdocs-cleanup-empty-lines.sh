#!/usr/bin/env bash
# gdocs-cleanup-empty-lines.sh — Delete empty paragraphs from Google Docs.
#
# Removes empty NORMAL_TEXT, HEADING_2, and HEADING_3 elements created by
# insert-text --as-html. These are single-newline artifacts (endIndex - startIndex == 1).
#
# Two operations:
#   1. DELETE empty elements that aren't immediately before a TABLE
#   2. DOWNGRADE empty HEADING_2/HEADING_3 before a TABLE to NORMAL_TEXT
#      (Google Docs requires a paragraph before tables, so we can't delete them)
#
# Usage:
#   As standalone:
#     bash ~/work/claude/scripts/gdocs-cleanup-empty-lines.sh <DOC_ID> [--tab-id <TAB_ID>] [--log-prefix <PREFIX>]
#
#   As sourceable function:
#     source ~/work/claude/scripts/gdocs-cleanup-empty-lines.sh
#     gdocs_cleanup_empty_lines <DOC_ID> [--tab-id <TAB_ID>] [--log-prefix <PREFIX>]
#
# Returns 0 on success (including "nothing to clean"), 1 on error.

gdocs_cleanup_empty_lines() {
    local doc_id="$1"
    shift

    local tab_id="t.0"
    local log_prefix="[cleanup]"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tab-id) tab_id="$2"; shift 2 ;;
            --log-prefix) log_prefix="$2"; shift 2 ;;
            *) echo "$log_prefix Unknown arg: $1"; shift ;;
        esac
    done

    if [ -z "$doc_id" ]; then
        echo "$log_prefix ERROR: doc_id required"
        return 1
    fi

    # Fetch structure to a temp file (piping large output to python can get killed)
    local tmpfile="/tmp/gdocs-cleanup-structure-$$"
    timeout 15 gdocs content get-structure "$doc_id" --tab-id "$tab_id" 2>/dev/null > "$tmpfile" || true
    if [ ! -s "$tmpfile" ]; then
        echo "$log_prefix WARNING: Could not fetch structure for $doc_id (tab $tab_id)"
        rm -f "$tmpfile"
        return 1
    fi

    # Generate batch-update requests: deletes + heading downgrades
    local reqs_file="/tmp/gdocs-cleanup-reqs-$$"
    python3 -c "
import re, json

tab_id = '$tab_id'
entries = []
with open('$tmpfile') as f:
    for line in f:
        m = re.match(r'\[(\d+)-(\d+)\] (\S+?):?\s', line.strip())
        if m:
            entries.append((int(m.group(1)), int(m.group(2)), m.group(3)))

to_del = []
to_downgrade = []
for i, (s, e, t) in enumerate(entries):
    if i >= len(entries) - 1:
        continue
    next_t = entries[i + 1][2]
    is_empty = e - s == 1

    if t == 'NORMAL_TEXT' and is_empty:
        # Empty NORMAL_TEXT before TABLE is benign (required by Google Docs) — skip
        if next_t != 'TABLE':
            to_del.append((s, e))
    elif t in ('HEADING_1', 'HEADING_2', 'HEADING_3') and is_empty:
        if next_t == 'TABLE':
            # Can't delete (required paragraph), but downgrade from heading to plain text
            to_downgrade.append((s, e))
        else:
            to_del.append((s, e))

if not to_del and not to_downgrade:
    import sys; sys.exit(0)

reqs = []

# Downgrades first (updateParagraphStyle doesn't shift indices)
for s, e in reversed(to_downgrade):
    reqs.append({
        'updateParagraphStyle': {
            'range': {'startIndex': s, 'endIndex': e, 'tabId': tab_id},
            'paragraphStyle': {'namedStyleType': 'NORMAL_TEXT'},
            'fields': 'namedStyleType'
        }
    })

# Then deletes (highest index first)
if to_del:
    to_del.sort()
    merged = [list(to_del[0])]
    for s, e in to_del[1:]:
        if s <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], e)
        else:
            merged.append([s, e])
    for s, e in reversed(merged):
        reqs.append({'deleteContentRange': {'range': {'startIndex': s, 'endIndex': e, 'tabId': tab_id}}})

with open('$reqs_file', 'w') as f:
    json.dump(reqs, f)

n_down = len(to_downgrade)
n_del = len([m for m in (merged if to_del else [])])
print(f'{n_down} downgrade + {n_del} delete = {n_down + n_del} total')
" 2>/dev/null
    local py_exit=$?

    rm -f "$tmpfile"

    if [ $py_exit -ne 0 ] || [ ! -s "$reqs_file" ]; then
        echo "$log_prefix No empty lines to clean"
        rm -f "$reqs_file"
        return 0
    fi

    local summary
    summary=$(cat "$reqs_file" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")

    gdocs batch-update "$doc_id" --data @"$reqs_file" 2>/dev/null && \
        echo "$log_prefix Empty lines cleaned ($summary ops)" || \
        { echo "$log_prefix WARNING: batch-update failed"; rm -f "$reqs_file"; return 1; }

    rm -f "$reqs_file"
    return 0
}

# Run as standalone if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gdocs_cleanup_empty_lines "$@"
fi
