#!/bin/bash
# msg-budget-gate.sh — deterministic WHOLE-MESSAGE size gate for LLM-rendered team/1:1
# messages that have no deterministic renderer (daily-brief, shift-summary, any digest
# the LLM assembles as free text).
#
# Operator 2026-06-09: "the char budget should apply to the whole msg, not a section …
# same budget rule for the daily brief — concise + effective for the team to digest and
# act on." The fleet-health digest enforces this in its renderer; LLM-rendered messages
# can't, so this gate is the mechanical equivalent: the cron pipes the FULLY-ASSEMBLED
# message through this BEFORE sending. Exit 0 = within budget (send it); exit 3 = OVER
# (loud overage on stderr) → the caller MUST trim by priority and re-run; NEVER send an
# over-budget message. This is the "mechanical, not prose" enforcement (a prose '<=N
# lines' note gets skipped under task focus — the lesson from the fleet-pulse char-budget
# that never fired).
#
# Usage:  printf '%s' "$MSG" | bash msg-budget-gate.sh --max-chars 1200 --max-lines 16
set -uo pipefail
MAX_CHARS=1200
MAX_LINES=16
while [ $# -gt 0 ]; do
  case "$1" in
    --max-chars) MAX_CHARS="$2"; shift 2 ;;
    --max-lines) MAX_LINES="$2"; shift 2 ;;
    *) shift ;;
  esac
done
MAX_CHARS="${MAX_CHARS}" MAX_LINES="${MAX_LINES}" python3 -c "
import sys, os
m = sys.stdin.read().rstrip('\n')
c = len(m); l = m.count('\n') + 1 if m else 0
mc = int(os.environ['MAX_CHARS']); ml = int(os.environ['MAX_LINES'])
if c > mc or l > ml:
    sys.stderr.write(
        f'OVER-BUDGET: {c} chars / {l} lines exceeds {mc}c / {ml}L. '
        'Trim by priority (drop the lowest-value content first) and re-run this gate '
        'BEFORE sending — do not send an over-budget message.\n')
    sys.exit(3)
print(f'within budget ({c} chars / {l} lines, limit {mc}c/{ml}L)')
"
