#!/bin/bash
# quality-gate-precheck.sh — OUTCOME-based pre-submit gate for jf/conf diffs.
#
# WHY THIS EXISTS (2026-06-12): the diff-cheatsheet hook only checked for the
# `# diff-cheatsheet-ok` TOKEN — token-presence, not outcome. An agent (or
# subagent) appends the token to clear the hook without actually applying the
# cheatsheet, so a non-compliant diff escapes (D105041081 v3, D106859537,
# D108480297 — the last shipped a >72-char title + no source URL). The
# cheatsheet referenced this script as the "mechanical gate" but it was never
# built. This is that gate: it READS the current commit message and BLOCKS on
# high-confidence violations, so the gate verifies the work instead of trusting
# a stamp.
#
# DESIGN PRINCIPLES:
#   - FAIL-OPEN. Any error / can't-read / non-fbsource → exit 0 (never wedge
#     submits; a broken gate must not block all diffs).
#   - CONSERVATIVE. Only HARD-block on high-confidence violations (title >72,
#     missing publish_when_ready, duplicate metadata fields, what-not-why
#     opener, grossly oversized summary, bare D/P refs). Softer issues
#     (missing source URL, empty Reviewers on a draft) are WARN-only — printed
#     but exit 0 — to avoid false-blocking legit drafts.
#   - Reads from $HOME/fbsource (the common case). Other repos fail-open.
#
# EXIT: 0 = pass (or fail-open); 2 = hard findings (printed to stderr).
# Usage: quality-gate-precheck.sh   (inspects `sl log -r .` in $HOME/fbsource)

set +e  # never abort on a sub-step; we decide the exit code explicitly

REPO="${FBSOURCE_DIR:-$HOME/fbsource}"
# --desc-file <f> is TEST-ONLY (the installed hook calls this with no args, so it
# cannot be a production bypass): read the commit desc from a file instead of sl.
if [ "$1" = "--desc-file" ] && [ -f "$2" ]; then
  desc=$(cat "$2")
else
  desc=$(cd "$REPO" 2>/dev/null && sl log -r . -T '{desc}' 2>/dev/null)
fi
[ -z "$desc" ] && exit 0   # fail-open: can't read the commit

title=$(printf '%s\n' "$desc" | head -1)
findings=""
warns=""

# 1. Title length (first line) ≤72 — strip a leading auto-prefix like
#    "[S###### - Oncall] " from the measurement? No: Phab/sl truncate the FULL
#    first line, so the full length is what matters. Hard.
tlen=${#title}
[ "$tlen" -gt 72 ] && findings="${findings}\n  - TITLE is ${tlen} chars (>72): \"${title}\" — trim it (Phab/sl truncate the first line)."

# 2. publish_when_ready tag present.
printf '%s\n' "$desc" | grep -qiE '^Tags:.*publish_when_ready' \
  || findings="${findings}\n  - Missing the publish_when_ready tag (Tags: line must include it)."

# 3. Duplicate metadata fields (exactly one each).
for field in Reviewers Tasks Tags; do
  n=$(printf '%s\n' "$desc" | grep -cE "^${field}:")
  [ "$n" -gt 1 ] && findings="${findings}\n  - Duplicate '${field}:' lines (${n}) — jf silently skips field updates on dups; keep exactly one."
done

# 4. Summary body checks (between 'Summary:' and 'Test Plan:').
summary=$(printf '%s\n' "$desc" | sed -n '/^Summary:/,/^Test Plan:/p' | sed '1d;$d')
if [ -n "$summary" ]; then
  # 4a. what-not-why opener.
  first_sent=$(printf '%s' "$summary" | grep -vE '^\s*$' | head -1)
  case "$first_sent" in
    "This diff"*|"This change"*|"Adds "*|"Add "*|"This adds"*|"Adding "*)
      findings="${findings}\n  - Summary opens what-not-why (\"$(printf '%s' "$first_sent" | cut -c1-40)…\") — lead with WHY (the broken state / motivation), not what it adds." ;;
  esac
  # 4b. grossly oversized (hard ceiling; finer size-based caps left to the author).
  wc_words=$(printf '%s' "$summary" | wc -w | tr -d ' ')
  [ "$wc_words" -gt 300 ] && findings="${findings}\n  - Summary is ${wc_words} words (>300 hard ceiling) — summarize problem+fix, don't narrate the diff."
  # 4c. bare D/P refs without an https URL (Phab needs clickable links).
  if printf '%s' "$summary" | grep -qE '(^|[^/A-Za-z0-9])[DP][0-9]{6,}' \
     && ! printf '%s' "$summary" | grep -qE 'https?://[^ )]*[DP][0-9]{6,}'; then
    warns="${warns}\n  - A bare D###### / P###### appears with no https:// URL — wrap it as a link."
  fi
  # 4d. source URL (oncall/incident traceability) — WARN only.
  printf '%s' "$summary" | grep -qE 'https?://' \
    || warns="${warns}\n  - Summary has no URL — if this is oncall/incident-driven, link the source (SEV / alert / thread)."
fi

# 5. Reviewers empty — WARN only (a draft may defer routing).
printf '%s\n' "$desc" | grep -qE '^Reviewers:[[:space:]]*[^[:space:]]' \
  || warns="${warns}\n  - Reviewers: is empty — set before it leaves draft (publish_when_ready will publish it)."

if [ -n "$findings" ]; then
  printf 'DIFF QUALITY GATE — hard findings (fix the commit message via sl metaedit, then re-submit):%b\n' "$findings" >&2
  [ -n "$warns" ] && printf 'Also (warnings):%b\n' "$warns" >&2
  exit 2
fi

[ -n "$warns" ] && printf 'DIFF QUALITY GATE — warnings (not blocking):%b\n' "$warns" >&2
exit 0
