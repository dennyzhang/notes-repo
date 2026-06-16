#!/bin/bash
# render-hooks.sh — regenerate settings.json "hooks" block from config/hooks.yaml.
# Atomic: writes to a temp file, lints, swaps. Aborts on lint failure.
# Pre-edit, settings.json is backed up to .claude/backups/.
#
# Usage: bash scripts/render-hooks.sh [--dry-run]

set -euo pipefail

CLAUDE_DIR="$HOME/work/claude"
HOOKS_YAML="$CLAUDE_DIR/config/hooks.yaml"
SETTINGS="$CLAUDE_DIR/.claude/settings.json"
BACKUP_DIR="$HOME/.claude/backups"
DRY_RUN=0

[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

if [ ! -f "$HOOKS_YAML" ]; then
  echo "FAIL: $HOOKS_YAML not found"; exit 1
fi
if [ ! -f "$SETTINGS" ]; then
  echo "FAIL: $SETTINGS not found"; exit 1
fi

mkdir -p "$BACKUP_DIR"

/usr/bin/python3 - "$HOOKS_YAML" "$SETTINGS" "$DRY_RUN" "$BACKUP_DIR" <<'PY'
import json, os, sys, shutil
from datetime import datetime, timezone

# Minimal YAML parser dependency: try PyYAML, else hand-parse the very limited subset we use.
try:
    import yaml
    have_yaml = True
except ImportError:
    have_yaml = False

hooks_yaml, settings_path, dry_run, backup_dir = sys.argv[1:5]
dry_run = (dry_run == "1")

if not have_yaml:
    print("FAIL: PyYAML required (pip3 install pyyaml or use venv)")
    sys.exit(1)

with open(hooks_yaml) as f:
    cfg = yaml.safe_load(f)

CLAUDE_DIR = os.path.expanduser("~/work/claude")

# --- Pre-flight schema validation ---
VALID_EVENTS = {"PreToolUse", "PostToolUse", "Stop", "SessionStart", "PreCompact", "UserPromptSubmit"}
VALID_TYPES = {"script", "nudge", "block", "inline"}
errors = []
for event, rows in (cfg or {}).items():
    if event.startswith("_"):  # allow _comment etc
        continue
    if event not in VALID_EVENTS:
        errors.append(f"unknown event: {event} (valid: {sorted(VALID_EVENTS)})")
        continue
    if not isinstance(rows, list):
        errors.append(f"{event}: must be a list")
        continue
    for i, r in enumerate(rows):
        if "matcher" not in r:
            errors.append(f"{event}[{i}]: missing 'matcher'")
        if "type" not in r:
            errors.append(f"{event}[{i}]: missing 'type'")
        elif r["type"] not in VALID_TYPES:
            errors.append(f"{event}[{i}] matcher={r.get('matcher')}: invalid type '{r['type']}' (valid: {sorted(VALID_TYPES)})")
            continue
        t = r.get("type")
        if t == "script" and "script" not in r:
            errors.append(f"{event}[{i}] matcher={r.get('matcher')}: type=script requires 'script' field")
        if t in ("nudge", "block") and "message" not in r:
            errors.append(f"{event}[{i}] matcher={r.get('matcher')}: type={t} requires 'message' field")
        if t == "inline" and "inline" not in r:
            errors.append(f"{event}[{i}] matcher={r.get('matcher')}: type=inline requires 'inline' field")
        # Validate referenced script exists
        if t == "script":
            rel = r.get("script", "")
            full = os.path.join(CLAUDE_DIR, rel) if not rel.startswith("/") else rel
            full = os.path.expanduser(full)
            if not os.path.exists(full):
                errors.append(f"{event}[{i}] matcher={r.get('matcher')}: script not found at {full}")

if errors:
    print(f"FAIL: hooks.yaml schema errors:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

TIMING_WRAPPER = "~/work/claude/config/hooks/_run-with-timing.sh"

def render_command(spec):
    t = spec["type"]
    parts = []
    env = spec.get("env")
    if env:
        parts.append(env)
    if t == "script":
        rel = spec["script"]
        path = f"~/work/claude/{rel}" if not rel.startswith("/") and not rel.startswith("~") else rel
        # stdin-piped scripts can't go through the timing wrapper without breaking stdin chain
        if spec.get("stdin"):
            parts.append(f"cat | {path}")
        else:
            args = spec.get("args", "")
            # Wrap with timing recorder unless explicitly opted out
            if spec.get("no_timing"):
                parts.append(f"bash {path}{(' ' + args) if args else ''}")
            else:
                parts.append(f"bash {TIMING_WRAPPER} {path}{(' ' + args) if args else ''}")
    elif t == "nudge":
        msg = spec["message"].rstrip("\n").replace("'", "'\"'\"'")
        parts.append(f"echo '{msg}' && exit 0")
    elif t == "block":
        msg = spec["message"].rstrip("\n").replace("'", "'\"'\"'")
        parts.append(f"echo '{msg}' && exit 1")
    elif t == "inline":
        parts.append(spec["inline"].rstrip("\n"))
    else:
        raise ValueError(f"unknown type: {t}")
    return " ".join(parts)

def build_hook_obj(spec):
    obj = {"type": "command", "command": render_command(spec)}
    if spec.get("async"):
        obj["async"] = True
    if "timeout" in spec:
        obj["timeout"] = spec["timeout"]
    return obj

# Group by event, then by matcher (preserving order)
out_hooks = {}
for event in ("PreToolUse", "PostToolUse", "Stop", "SessionStart", "PreCompact", "UserPromptSubmit"):
    rows = cfg.get(event, [])
    if not rows:
        continue
    out_hooks[event] = []
    # Group consecutive same-matcher entries (preserves user-intended grouping)
    current_matcher = None
    current_group = None
    for r in rows:
        m = r["matcher"]
        if m != current_matcher:
            current_group = {"matcher": m, "hooks": []}
            out_hooks[event].append(current_group)
            current_matcher = m
        current_group["hooks"].append(build_hook_obj(r))

# Load + replace
with open(settings_path) as f:
    settings = json.load(f)
settings["hooks"] = out_hooks

if dry_run:
    print("=== DRY RUN — would write ===")
    print(json.dumps({"hooks": out_hooks}, indent=2)[:2000])
    print(f"... (truncated)\nNo backup or write performed.")
    sys.exit(0)

# Backup current (only on real run)
ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%S-%fZ")
backup = os.path.join(backup_dir, f"settings.json.backup-{ts}")
shutil.copy2(settings_path, backup)

# Write to temp, lint, THEN swap (don't pollute live settings.json with a bad render)
tmp = settings_path + ".render.tmp"
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

# Validate JSON before swap
with open(tmp) as f:
    json.load(f)

# Run lint-settings.sh against the temp file BEFORE swap.
# rc=0 ok, rc=2 warn (warns are allowed — already at threshold), rc=1 hard fail.
import subprocess
lint = subprocess.run(["bash", os.path.expanduser("~/work/claude/scripts/lint-settings.sh"), tmp],
                      capture_output=True, text=True)
if lint.returncode == 1:
    os.unlink(tmp)
    print(f"FAIL: lint rejected rendered settings.json — aborting swap")
    print(lint.stdout)
    print(lint.stderr, file=sys.stderr)
    sys.exit(1)

os.rename(tmp, settings_path)
print(f"OK: rendered {sum(len(g['hooks']) for ev in out_hooks.values() for g in ev)} hooks across {sum(len(out_hooks[ev]) for ev in out_hooks)} matchers")
print(f"Backup: {backup}")
PY

# Post-render: rotate backups (keep last 3). Lint already ran pre-swap inside python block.
if [ "$DRY_RUN" -eq 0 ]; then
  ls -1t "$BACKUP_DIR"/settings.json.backup-* 2>/dev/null | tail -n +4 | xargs -r rm -- 2>/dev/null || true
fi
