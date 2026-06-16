#!/usr/bin/env bash
# task-owner-guard-hook.sh — PreToolUse(Bash) gate.
#
# Enforces the CLAUDE.md "Never Do" rule: a bot-filed meta task MUST be
# owner=dennyzhang and MUST NOT be routed to another person/oncall. The
# operator routes tasks himself after seeing the bot's framing; auto-routed
# tasks land on confused strangers or get bounced.
#
# This is the mechanical gate for the owner/assignment failure-mode
# (feedback-coach: 53x recurring, previously prose-only). Command-shape gate
# (greps the COMMAND, not any model output) — safe per the "hooks only for
# command-shape rules" lesson (content-grep hooks are the false-positive trap).
#
# Blocks ONLY explicit wrong-routing:
#   --assign-to-oncall=<any>
#   --owner=<not dennyzhang>
#   assigned_to_user_unixname=<not dennyzhang>
# Allows: --owner=dennyzhang, missing --owner, subscribers (--subscriber/
# --add-subscriber are explicitly permitted), and every non-task command.
#
# Exit 0 = allow · Exit 2 = block (stderr carries the reason).

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)

# Only act on meta task create/update; pass everything else straight through.
case "$cmd" in
  *"tasks.task create"*|*"tasks.task update"*) : ;;
  *) exit 0 ;;
esac

# 1) Never route to another oncall queue.
case "$cmd" in
  *"--assign-to-oncall"*)
    echo "BLOCKED (task-owner-guard): never --assign-to-oncall. Bot files owner=dennyzhang only; the operator routes to other oncalls/people himself. (CLAUDE.md Never-Do)" >&2
    exit 2 ;;
esac

# 2) --owner must be dennyzhang if present.
owner=$(printf '%s' "$cmd" | grep -oE -- '--owner[= ][^ ]+' | head -1 | sed -E 's/^--owner[= ]//')
if [ -n "$owner" ] && [ "$owner" != "dennyzhang" ]; then
  echo "BLOCKED (task-owner-guard): --owner=$owner — bot-filed tasks must be --owner=dennyzhang. (CLAUDE.md Never-Do)" >&2
  exit 2
fi

# 3) assigned_to_user_unixname (tasks.task update field) must be dennyzhang if present.
assignee=$(printf '%s' "$cmd" | grep -oE 'assigned_to_user_unixname[=: ][^ "]+' | head -1 | sed -E 's/^assigned_to_user_unixname[=: ]//')
if [ -n "$assignee" ] && [ "$assignee" != "dennyzhang" ]; then
  echo "BLOCKED (task-owner-guard): assigned_to_user_unixname=$assignee — bot-filed tasks stay owner=dennyzhang. (CLAUDE.md Never-Do)" >&2
  exit 2
fi

exit 0
