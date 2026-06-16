#!/bin/bash
# lint-settings.sh — validates settings.json before/after edits.
# Checks: JSON validity, no duplicate hook commands, all referenced scripts exist,
#         sync-PreToolUse-Bash count <=4 (CLAUDE.md hook performance rule).
# Exit 0 = pass, 1 = fail. Used by cron-daily-housekeeping and Stop hook.

set -uo pipefail

SETTINGS="${1:-$HOME/work/claude/.claude/settings.json}"
ERRORS=()

if [ ! -f "$SETTINGS" ]; then
  echo "FAIL: settings file not found: $SETTINGS"
  exit 1
fi

# 1. JSON validity
if ! python3 -m json.tool "$SETTINGS" > /dev/null 2>&1; then
  echo "FAIL: invalid JSON in $SETTINGS"
  exit 1
fi

# 2-4. Inspect hook structure with python (avoids brittle grep)
python3 - "$SETTINGS" <<'PY' || ERRORS+=("python checks failed")
import json, sys, os, re
from collections import Counter

p = sys.argv[1]
s = json.load(open(p))
hooks = s.get("hooks", {})

dup_count = 0
sync_pretooluse_bash = 0
missing_scripts = []
seen_commands = Counter()

for event, matchers in hooks.items():
    for m in matchers:
        for h in m.get("hooks", []):
            cmd = h.get("command", "").strip()
            seen_commands[(event, m.get("matcher"), cmd)] += 1
            if event == "PreToolUse" and m.get("matcher") == "Bash" and not h.get("async", False):
                sync_pretooluse_bash += 1
            # Check referenced bash scripts exist (literal paths only)
            for tok in re.findall(r'(/[\w./~-]+\.sh|~/[\w./~-]+\.sh)', cmd):
                path = os.path.expanduser(tok)
                if not os.path.exists(path):
                    missing_scripts.append((event, m.get("matcher"), tok))

warnings = []
# Check var-paths separately (warn, don't fail — can't validate statically)
import re as _re
for event, matchers in hooks.items():
    for m in matchers:
        for h in m.get("hooks", []):
            cmd = h.get("command", "")
            if _re.search(r'\$\{?[A-Z_][A-Z0-9_]*\}?/[\w./-]*\.sh', cmd):
                warnings.append(f"  [{event}/{m.get('matcher')}] var-path (cannot statically validate): {cmd[:80]}")

dups = [(k, v) for k, v in seen_commands.items() if v > 1]
if dups:
    print("FAIL: duplicate hook commands:")
    for (event, matcher, cmd), count in dups:
        print(f"  [{event}/{matcher}] x{count}: {cmd[:80]}")
    sys.exit(1)

if missing_scripts:
    print("FAIL: hook references non-existent scripts:")
    for event, matcher, tok in missing_scripts:
        print(f"  [{event}/{matcher}] {tok}")
    sys.exit(1)

warn_rc = 0
if warnings:
    print("WARN: var-path script references found:")
    for w in warnings: print(w)
    warn_rc = 2

if sync_pretooluse_bash > 4:
    print(f"WARN: {sync_pretooluse_bash} sync PreToolUse Bash hooks (CLAUDE.md flags >4)")
    warn_rc = 2

print(f"OK: {sum(seen_commands.values())} hooks, {sync_pretooluse_bash} sync PreToolUse Bash")
sys.exit(warn_rc)
PY

rc=$?
if [ $rc -ne 0 ] && [ $rc -ne 2 ]; then
  exit 1
fi
exit $rc
