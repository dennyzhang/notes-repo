#!/usr/bin/env bash
# diffs-by-path.sh — Harvest recent diffs that touched declared workstream paths.
#
# Usage: diffs-by-path.sh <slug> <project_dir> <meta.yaml>
#
# Reads `workstreams:` dict (name → fbsource path) from META.yaml.
# Writes signals/diffs-by-path.md atomically. Self-skips if `workstreams:` absent.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

slug="${1:?slug required}"
project_dir="${2:?project_dir required}"
meta_file="${3:?meta.yaml path required}"

workstreams=$(read_yaml_dict workstreams "$meta_file")
[ -z "$workstreams" ] && { echo "  [skip] no workstreams declared"; exit 0; }

signal_dir="$project_dir/context/signals"
mkdir -p "$signal_dir"
output="$signal_dir/diffs-by-path.md"
tmpout=$(mktemp -t diffs-by-path.XXXX.md)
TODAY=$(date '+%Y-%m-%d')

{
    echo "# Recent diffs by code path"
    echo
    echo "<!-- Source: diffs-by-path. Regenerated weekly. Do not hand-edit. -->"
    echo "<!-- Last refresh: $(date -Iseconds) -->"
    echo
} > "$tmpout"

had_data=0

while IFS=$'\t' read -r workstream path <&3; do
    [ -z "$workstream" ] && continue
    echo "  workstream=$workstream path=$path"

    diff_json=$(meta search.doc search \
        --doc-type=DIFF \
        --diff-modified-file-directories="fbsource/${path}" \
        --limit=20 \
        -o json 2>&1) || {
        echo "  [WARN] search failed for $workstream: $(echo "$diff_json" | head -1)" >&2
        continue
    }

    diff_ids=$(echo "$diff_json" | extract_diff_ids)
    diff_count=$(echo "$diff_ids" | grep -c '^D' || echo 0)
    [ "$diff_count" -eq 0 ] && continue

    had_data=1
    {
        echo "## $workstream — $path"
        echo
        echo "*Discovered: $TODAY. $diff_count diffs.*"
        echo
        echo "| Date | Diff | Title | Author | Reviewers | Status |"
        echo "|------|------|-------|--------|-----------|--------|"
    } >> "$tmpout"

    for d in $diff_ids; do
        row=$(format_diff_row "$d" "$TODAY")
        [ -n "$row" ] && echo "$row" >> "$tmpout"
    done
    echo >> "$tmpout"
done 3<<< "$workstreams"

if [ "$had_data" -eq 1 ]; then
    mv "$tmpout" "$output"
    echo "  wrote $output"
else
    rm -f "$tmpout"
    echo "  [skip] no data harvested"
fi
