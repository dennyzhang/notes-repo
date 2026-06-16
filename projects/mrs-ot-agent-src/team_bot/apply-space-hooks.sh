#!/usr/bin/env bash
# apply-space-hooks.sh — idempotently apply required PreToolUse hooks to a
# MyClaw space settings.json.
#
# Usage:
#   bash apply-space-hooks.sh <path/to/spaces/<SPACE_ID>/.claude/settings.json>
#
# PORTABLE: the target space id is derived from the settings.json path
# (.../spaces/<SPACE_ID>/.claude/settings.json), NOT hardcoded — so this script
# works for ANY MyClaw instance on any server, not just the OT bot.
#
# Called by bootstrap.sh's apply_space_hooks() on every reinstall.
# Safe to re-run — exits 0 and prints "already present" if hooks are in place.
#
# Tracker: T266536788

set -euo pipefail

SETTINGS_PATH="${1:-}"
if [ -z "$SETTINGS_PATH" ]; then
  echo "Usage: $0 <path/to/settings.json>" >&2
  exit 1
fi

if [ ! -f "$SETTINGS_PATH" ]; then
  echo "[apply-space-hooks] $SETTINGS_PATH not found — skipping" >&2
  exit 0
fi

SPACE_ID=$(echo "$SETTINGS_PATH" | grep -oP '/spaces/\K[^/]+(?=/\.claude/settings\.json$)')
if [ -z "$SPACE_ID" ]; then
  echo "[apply-space-hooks] could not derive space id from $SETTINGS_PATH; expected .../spaces/<ID>/.claude/settings.json — skipping" >&2
  exit 0
fi

hook_present() {
  local detect="$1"
  jq -e --arg d "$detect" '.hooks.PreToolUse // [] | any(.hooks[]?; .command | contains($d))' "$SETTINGS_PATH" >/dev/null 2>&1
}

ADDED=()

add_hook_if_missing() {
  local detect="$1"
  local hook_json="$2"

  if hook_present "$detect"; then
    echo "[apply-space-hooks] already present: $detect" >&2
    return
  fi

  local backup="${SETTINGS_PATH%.json}.pre-hook-$(date +%s).json"
  cp "$SETTINGS_PATH" "$backup"

  jq --argjson hook "$hook_json" '
    .hooks //= {} |
    .hooks.PreToolUse //= [] |
    .hooks.PreToolUse += [$hook]
  ' "$SETTINGS_PATH" > "${SETTINGS_PATH}.tmp" && mv "${SETTINGS_PATH}.tmp" "$SETTINGS_PATH"

  ADDED+=("$detect")
}

# Hook 1: Thread-reply discipline (2026-05-29, thread GSSYzY7flFQ).
# Blocks google.chat.message send to THIS instance's home space without
# --reply-in-thread. Escape hatch: append '# new-topic'.
add_hook_if_missing "reply-in-thread" "$(cat <<HOOKEOF
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "cmd=\$(jq -r '.tool_input.command // empty'); case \"\$cmd\" in *\"google.chat.message send\"*\"spaces/${SPACE_ID}\"*) case \"\$cmd\" in *\"--reply-in-thread\"*) : ;; *\"# new-topic\"*) : ;; *) echo \"BLOCKED: send to home space without --reply-in-thread. Fold into the relevant existing thread (--reply-in-thread=spaces/${SPACE_ID}/threads/<id>). If genuinely a NEW topic, append '# new-topic' to confirm. (feedback_fold-messages-into-threads)\" >&2; exit 2 ;; esac ;; esac"
    }
  ]
}
HOOKEOF
)"

# Hook 2: gdocs comment-destruction guard (2026-06-02, thread 8IyKRxB9wPE).
# Blocks gdocs apply / replace / deleteContentRange when doc has comments.
add_hook_if_missing "gdocs-comment-guard-hook" "$(cat <<HOOKEOF
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "bash /home/dennyzhang/notes/users/dennyzhang/scripts/hooks/gdocs-comment-guard-hook.sh"
    }
  ]
}
HOOKEOF
)"

# Hook 3: task-owner guard (2026-06-08, feedback-coach owner/assignment 53x).
# Blocks meta tasks.task create/update that route to another oncall/person.
# Mechanical gate for the owner/assignment failure-mode (was prose-only).
add_hook_if_missing "task-owner-guard-hook" "$(cat <<HOOKEOF
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "bash /home/dennyzhang/notes/users/dennyzhang/scripts/hooks/task-owner-guard-hook.sh"
    }
  ]
}
HOOKEOF
)"

if [ ${#ADDED[@]} -eq 0 ]; then
  exit 0
fi

echo "[apply-space-hooks] applied ${#ADDED[@]} hook(s) for space ${SPACE_ID}: ${ADDED[*]}" >&2
