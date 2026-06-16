#!/usr/bin/env bash
# cheatsheet-accept.sh — THE single acceptance gate for cheatsheet changes.
# The auto-create pipeline calls this once per candidate. Default-FAIL: a candidate
# lands ONLY if both stages pass.
#   stage 1  deterministic  — lint-cheatsheets.sh --gate (structure, provenance, links,
#                             evidence-log, grounding-token). Fast, no LLM.
#   stage 2  adversarial    — cheatsheet-content-verify.sh (LLM: dedup, contradiction,
#                             grounding-resolve). Default-reject.
#
# Usage:  cheatsheet-accept.sh <candidate.md> [more.md ...]
# Exit:   0 = accept (land it)   1 = reject   2 = bug/setup error
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
[ "$#" -ge 1 ] || { echo "usage: $0 <candidate.md> [more.md ...]" >&2; exit 2; }

echo "== stage 1/2: deterministic gate (lint --gate, strict) =="
# CS_STRICT=1: this IS the auto-author path, so grounding is a hard block (not the
# human-edit WARN). Every generated rule must cite a resolvable source.
if ! CS_STRICT=1 bash "$DIR/lint-cheatsheets.sh" --gate "$@"; then
  echo "REJECT: failed deterministic gate (stage 1)" >&2; exit 1
fi
echo "  stage 1 PASS"

echo "== stage 2/2: adversarial content verify (LLM) =="
if ! bash "$DIR/cheatsheet-content-verify.sh" "$@"; then
  echo "REJECT: failed content verify (stage 2)" >&2; exit 1
fi
echo "ACCEPT: all stages passed — safe to land"
