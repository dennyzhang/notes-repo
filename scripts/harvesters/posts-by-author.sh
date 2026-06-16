#!/usr/bin/env bash
# posts-by-author.sh — Harvest recent Workplace posts by key people.
#
# Usage: posts-by-author.sh <slug> <project_dir> <meta.yaml>
#
# Reads `key_people:` list from META.yaml. Self-skips if absent.
# Writes signals/posts-by-author.md atomically.
#
# Catches design discussions, status updates, and announcements that never
# show up in code-path or diff-author harvest.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

slug="${1:?slug required}"
project_dir="${2:?project_dir required}"
meta_file="${3:?meta.yaml path required}"

people=$(read_yaml_list key_people "$meta_file")
[ -z "$people" ] && { echo "  [skip] no key_people declared"; exit 0; }

signal_dir="$project_dir/context/signals"
mkdir -p "$signal_dir"
output="$signal_dir/posts-by-author.md"
tmpout=$(mktemp -t posts-by-author.XXXX.md)
TODAY=$(date '+%Y-%m-%d')

{
    echo "# Recent Workplace posts by key people"
    echo
    echo "<!-- Source: posts-by-author. Regenerated weekly. Do not hand-edit. -->"
    echo "<!-- Last refresh: $(date -Iseconds) -->"
    echo
} > "$tmpout"

had_data=0

while read -r person <&3; do
    [ -z "$person" ] && continue
    echo "  author=$person"

    post_json=$(meta search.doc search \
        --doc-type=GROUP_POST \
        --author="$person" \
        --limit=5 \
        -o json 2>&1) || {
        echo "  [WARN] search failed for $person: $(echo "$post_json" | head -1)" >&2
        continue
    }

    rows=$(echo "$post_json" | python3 -c "
import json, sys, html
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
results = data.get('results') if isinstance(data, dict) else data
if not isinstance(results, list):
    sys.exit(0)
for r in results[:5]:
    title = (r.get('title','') or r.get('snippet','') or '')[:80].replace('|','\\\\|').replace('\\n',' ')
    url = r.get('url', '')
    if not title:
        continue
    print(f'| $TODAY | [{title}]({url}) |')
")

    [ -z "$rows" ] && continue
    had_data=1

    {
        echo "## $person"
        echo
        echo "*Discovered: $TODAY.*"
        echo
        echo "| Date | Post |"
        echo "|------|------|"
        echo "$rows"
        echo
    } >> "$tmpout"
done 3<<< "$people"

if [ "$had_data" -eq 1 ]; then
    mv "$tmpout" "$output"
    echo "  wrote $output"
else
    rm -f "$tmpout"
    echo "  [skip] no data harvested"
fi
