#!/usr/bin/env bash
# diffs-by-author.sh — Harvest recent diffs authored by key people in this project.
#
# Usage: diffs-by-author.sh <slug> <project_dir> <meta.yaml>
#
# Reads `key_people:` list from META.yaml. Self-skips if absent.
# Writes signals/diffs-by-author.md atomically.
#
# This catches what path-based harvesting misses: diffs authored by domain experts
# in code paths NOT declared in workstreams (cross-area work, new initiatives).

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
output="$signal_dir/diffs-by-author.md"
tmpout=$(mktemp -t diffs-by-author.XXXX.md)
TODAY=$(date '+%Y-%m-%d')

{
    echo "# Recent diffs by key people"
    echo
    echo "<!-- Source: diffs-by-author. Regenerated weekly. Do not hand-edit. -->"
    echo "<!-- Last refresh: $(date -Iseconds) -->"
    echo
} > "$tmpout"

had_data=0

while read -r person <&3; do
    [ -z "$person" ] && continue
    echo "  author=$person"

    diff_json=$(meta search.doc search \
        --doc-type=DIFF \
        --author="$person" \
        --limit=10 \
        -o json 2>&1) || {
        echo "  [WARN] search failed for $person: $(echo "$diff_json" | head -1)" >&2
        continue
    }

    diff_ids=$(echo "$diff_json" | extract_diff_ids)
    diff_count=$(echo "$diff_ids" | grep -c '^D' || echo 0)
    [ "$diff_count" -eq 0 ] && continue

    had_data=1
    {
        echo "## $person"
        echo
        echo "*Discovered: $TODAY. $diff_count recent diffs.*"
        echo
        echo "| Date | Diff | Title | Author | Reviewers | Status |"
        echo "|------|------|-------|--------|-----------|--------|"
    } >> "$tmpout"

    for d in $diff_ids; do
        row=$(format_diff_row "$d" "$TODAY")
        [ -n "$row" ] && echo "$row" >> "$tmpout"
    done
    echo >> "$tmpout"
done 3<<< "$people"

if [ "$had_data" -eq 1 ]; then
    mv "$tmpout" "$output"
    echo "  wrote $output"
else
    rm -f "$tmpout"
    echo "  [skip] no data harvested"
fi
