#!/usr/bin/env bash
# upstream-files.sh — Track curated upstream files (CLAUDE.md, RUNBOOK.md, README.md)
# that other teams maintain in fbsource.
#
# Usage: upstream-files.sh <slug> <project_dir> <meta.yaml>
#
# Reads `upstream:` block from META.yaml. Format:
#   upstream:
#     files:
#       - fbcode/pe_mrs_ml/mrs-ot-agent/CLAUDE.md
#       - fbcode/pe_mrs_ml/README.md
#
# For each declared file:
#   - Snapshots the current content into signals/upstream/<sanitized-path>.md
#   - Hashes it. Compares against last hash stored in signals/upstream/.hashes
#   - Logs "changed" / "unchanged" / "missing" to signals/upstream-files.md (table)
#
# When a file changes, the snapshot is fresh — Claude reads the snapshot during
# distillation. The change log says *which* upstream files moved since last week,
# so distillation focuses on the deltas, not full re-reads.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib.sh"

slug="${1:?slug required}"
project_dir="${2:?project_dir required}"
meta_file="${3:?meta.yaml path required}"

FBSOURCE="$HOME/fbsource"

# Read `files:` list nested under `upstream:` block.
files=$(python3 - "$meta_file" <<'PY'
import re, sys
content = open(sys.argv[1]).read()
m = re.search(r'(?ms)^upstream:[ \t]*\n((?:^[ \t]+.*\n?)+)', content)
if not m:
    sys.exit(0)
block = m.group(1)
m2 = re.search(r'(?m)^[ \t]+files:[ \t]*\n((?:^[ \t]{4,}.*\n?)+)', block)
if not m2:
    sys.exit(0)
for line in m2.group(1).splitlines():
    s = line.split('#', 1)[0].strip()
    if not s:
        continue
    s = s.lstrip('-').strip().strip('"').strip("'")
    if s:
        print(s)
PY
)

[ -z "$files" ] && { echo "  [skip] no upstream.files declared"; exit 0; }

signal_dir="$project_dir/context/signals"
upstream_dir="$signal_dir/upstream"
hash_file="$upstream_dir/.hashes"
mkdir -p "$upstream_dir"
touch "$hash_file"

output="$signal_dir/upstream-files.md"
tmpout=$(mktemp -t upstream-files.XXXX.md)
TODAY=$(date '+%Y-%m-%d')

{
    echo "# Upstream files — change log"
    echo
    echo "<!-- Source: upstream-files. Regenerated weekly. Do not hand-edit. -->"
    echo "<!-- Last refresh: $(date -Iseconds) -->"
    echo
    echo "Snapshots live in \`signals/upstream/\`. Read the snapshot when a row says **changed**."
    echo
    echo "| Date | Status | Upstream file | Local snapshot |"
    echo "|------|--------|--------------|----------------|"
} > "$tmpout"

# Use FD 3 to feed the loop — protects stdin from python/cat consuming it.
while IFS= read -r rel <&3; do
    [ -z "$rel" ] && continue
    src="$FBSOURCE/$rel"
    sanitized=$(echo "$rel" | tr '/' '_')
    snap_file="$upstream_dir/$sanitized"

    if [ ! -f "$src" ]; then
        echo "| $TODAY | missing | \`$rel\` | _not found in fbsource_ |" >> "$tmpout"
        echo "  [missing] $rel"
        continue
    fi

    new_hash=$(sha256sum "$src" | awk '{print $1}')
    # `grep | awk` would trip pipefail when grep finds nothing — guard with `|| true`.
    old_hash=$( { grep -m1 "^$sanitized " "$hash_file" 2>/dev/null || true; } | awk '{print $2}')

    if [ "$new_hash" = "$old_hash" ]; then
        status="unchanged"
    elif [ -z "$old_hash" ]; then
        status="**new**"
    else
        status="**changed**"
    fi

    cp "$src" "$snap_file"

    # Update hash registry (atomic: rewrite without the old line, append fresh).
    tmp_hashes=$(mktemp -t hashes.XXXX)
    grep -v "^$sanitized " "$hash_file" > "$tmp_hashes" 2>/dev/null || true
    echo "$sanitized $new_hash $TODAY" >> "$tmp_hashes"
    mv "$tmp_hashes" "$hash_file"

    echo "| $TODAY | $status | \`$rel\` | [\`signals/upstream/$sanitized\`](upstream/$sanitized) |" >> "$tmpout"
    echo "  [$status] $rel"
done 3<<< "$files"

mv "$tmpout" "$output"
echo "  wrote $output"
