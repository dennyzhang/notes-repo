#!/usr/bin/env bash
# lint-doc-images.sh — fail if a markdown file embeds a too-small / thin-strip diagram.
#
# Recurring miss: graphviz/diagrams render hard-to-read — a too-small thumbnail, or a wide-thin LR
# strip (e.g. 1904x295). The durable fix is a SIMPLE diagram (few boxes, clean linear flow, ONE
# feedback arrow), BIG fonts, and no thin strips.
#
# NOTE (2026-06-12): a WIDE landscape image is FINE — it fills a wide doc column and renders large.
# Do NOT narrow for narrowness. An earlier too-wide cap here was WRONG (the operator's viewer renders
# wide images at full size). The enemies are CLUTTER (too many boxes/edges) and THIN STRIPS, not width.
#
# Usage: lint-doc-images.sh <file.md> [more.md ...]
# Pass = exit 0. Violations = exit 1 with one line each.
# Thresholds: min 900px wide · min 300px tall · max aspect ratio 3.0 (no thin strips).
set -uo pipefail
MINW=900; MINH=300; MAXASPECT=3.0
fails=0

for md in "$@"; do
  [ -f "$md" ] || { echo "skip (missing): $md"; continue; }
  dir=$(dirname "$md")
  while IFS= read -r img; do
    [ -z "$img" ] && continue
    p="$dir/$img"; [ -f "$p" ] || p="$img"
    if [ ! -f "$p" ]; then echo "BROKEN   $md -> $img (image file not found)"; fails=$((fails+1)); continue; fi
    case "$img" in *.svg) continue;; esac  # vector scales; skip raster check
    dim=$(file "$p" | grep -oE '[0-9]+ x [0-9]+' | head -1)
    w=${dim% x *}; h=${dim##* x }
    [ -z "${w:-}" ] || [ -z "${h:-}" ] && continue
    asp=$(awk -v a="$w" -v b="$h" 'BEGIN{printf "%.2f", (a>b)?a/b:b/a}')
    bad=""
    [ "$w" -lt "$MINW" ] && bad="$bad width<${MINW}(${w}px)"
    [ "$h" -lt "$MINH" ] && bad="$bad height<${MINH}(${h}px)"
    awk -v r="$asp" -v m="$MAXASPECT" 'BEGIN{exit !(r>m)}' && bad="$bad thin-strip(aspect ${asp})"
    if [ -n "$bad" ]; then echo "UNREADABLE $md -> $img [${w}x${h}]:$bad"; fails=$((fails+1)); fi
  done < <( { grep -oE '!\[[^]]*\]\([^)]+\.(png|jpg|jpeg|svg)\)' "$md" | sed -E 's/.*\(([^)]+)\)/\1/'; \
             grep -oiE '<img[^>]+src="[^"]+\.(png|jpg|jpeg|svg)"' "$md" | sed -E 's/.*src="([^"]+)".*/\1/'; } )
done

if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails unreadable image(s). Too-small/thin -> SIMPLIFY (few boxes), big fonts, rankdir=TB, no thin strips; verify with: file <img.png>." >&2
  exit 1
fi
echo "ok: all embedded images readable"
