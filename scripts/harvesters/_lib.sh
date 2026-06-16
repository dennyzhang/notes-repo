#!/usr/bin/env bash
# _lib.sh — Shared helpers for project context harvesters.
#
# Sourced by every harvester in scripts/harvesters/. Provides:
#   - read_yaml_dict <field> <meta.yaml>   → emits "key<TAB>value" lines
#   - read_yaml_list <field> <meta.yaml>   → emits one item per line
#   - extract_diff_ids                     → reads JSON from stdin, prints D-numbers
#   - format_diff_row <diff-id> <date>     → fetches metadata, prints markdown table row

read_yaml_dict() {
    local field="$1" file="$2"
    [ -f "$file" ] || return 0
    python3 - "$file" "$field" <<'PY'
import re, sys
content = open(sys.argv[1]).read()
field = sys.argv[2]
m = re.search(rf'(?m)^{field}:[ \t]*\n((?:^[ \t]+.*\n?)+)', content)
if not m:
    sys.exit(0)
for line in m.group(1).splitlines():
    s = line.split('#', 1)[0].strip()
    if not s or ':' not in s:
        continue
    name, _, val = s.partition(':')
    name = name.strip().strip('-').strip()
    val = val.strip().strip('"').strip("'")
    if name and val:
        print(f"{name}\t{val}")
PY
}

read_yaml_list() {
    local field="$1" file="$2"
    [ -f "$file" ] || return 0
    python3 - "$file" "$field" <<'PY'
import re, sys
content = open(sys.argv[1]).read()
field = sys.argv[2]
m = re.search(rf'(?m)^{field}:[ \t]*\n((?:^[ \t]+.*\n?)+)', content)
if not m:
    sys.exit(0)
for line in m.group(1).splitlines():
    s = line.split('#', 1)[0].strip()
    if not s:
        continue
    s = s.lstrip('-').strip().strip('"').strip("'")
    # Allow `name: comment` form too — take the key.
    if ':' in s:
        s = s.split(':', 1)[0].strip()
    if s:
        print(s)
PY
}

extract_diff_ids() {
    python3 -c "
import json, sys, re
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
results = data.get('results') if isinstance(data, dict) else data
if not isinstance(results, list):
    results = []
seen = set()
for r in results:
    for key in ('diff_number', 'number', 'id', 'url', 'title'):
        v = str(r.get(key, ''))
        m = re.search(r'D(\d{7,})', v)
        if m:
            seen.add('D' + m.group(1))
            break
for d in sorted(seen):
    print(d)
"
}

format_diff_row() {
    local diff_id="$1" date="$2"
    local meta_out
    meta_out=$(meta phabricator.diff metadata -n "$diff_id" -o json 2>&1) || return 0
    echo "$meta_out" | ROW_DATE="$date" python3 -c "
import json, sys, re, os
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
num    = d.get('number', '?')
title  = (d.get('title', '') or '').replace('|', '\\\\|')[:70]
author = d.get('author', '?')
revs   = d.get('reviewers', '') or ''
STATUS = {'accepted', 'added', 'resisted', 'commented', 'blocking',
          'auto_added', 'auto-added', 'requested-changes', 'request-changes'}
tokens = re.findall(r'#?[a-z][a-z0-9_-]*', str(revs).lower())
names  = [t for t in tokens if t not in STATUS]
revs = ', '.join(names[:4])
status = d.get('status', '?')
date = os.environ.get('ROW_DATE', '?')
print(f'| {date} | [{num}](https://www.internalfb.com/diff/{num}) | {title} | {author} | {revs} | {status} |')
"
}
