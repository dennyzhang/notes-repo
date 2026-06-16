#!/usr/bin/env bash
# gdocs-comment-guard-hook.sh — PreToolUse(Bash) guard against comment destruction.
#
# Blocks `gdocs apply` / `gdocs replace` (without --full-replace-removes-comments) /
# `deleteContentRange` whenever the target Google Doc has comments — because those
# ops orphan/delete operator comments anchored to changed text.
#
# Motivating incident (2026-06-02): a re-render used `gdocs edit -> apply` on the
# OT shift-summary tab (199 comments); it deleted operator comments anchored to the
# edited lines. The gdocs cheatsheet says this should be HARD BLOCKED by a hook —
# but no such hook existed in this lane. This is that hook.
#
# Contract: PreToolUse on the Bash tool. Reads the hook JSON on stdin, inspects
# .tool_input.command. Exit 0 = allow; exit 2 = block (stderr shown to the agent).
#
# Safe paths that are always allowed: find-replace, insert-text, batch-update
# (insertText/updateTextStyle/updateTableColumnProperties), comments reply.
# Override (use only when you have verified the doc/tab is commentless):
#   append the literal token  # gdocs-comments-ok  to the command.
#
# Owned by operator (dennyzhang); lives in notes. Wired into the space settings.json
# PreToolUse hooks; reinstalled by apply-space-hooks on bootstrap.
set -uo pipefail

IN=$(cat 2>/dev/null)
CMD=$(printf '%s' "$IN" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Only inspect ACTUAL gdocs invocations. Skip when the command is LED by a text/agent
# tool that takes the keywords as DATA (e.g. `codex exec "...gdocs apply..."`, echo,
# grep) — else the keyword match false-positives. Identify the leading program (after
# env-var assignments, path stripped) and bail if it's such a tool. This keeps real
# invocations like `if gdocs apply`, `command gdocs apply`, `/usr/local/bin/gdocs
# apply`, `timeout N gdocs apply` in scope (their lead token is not a text tool).
# (2026-06-02: codex adversarial review found BOTH the false-positive and the
#  too-narrow earlier gate that let `if gdocs apply` / abspath bypass.)
LEAD=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]*//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*//' | awk '{print $1}' | sed -E 's#.*/##')
case "$LEAD" in codex|echo|printf|cat|grep|egrep|fgrep|sed|awk|less|more|head|tail|jq|comm|diff|tee) exit 0 ;; esac
case "$CMD" in *gdocs*) ;; *) exit 0 ;; esac

# Explicit, conscious override.
printf '%s' "$CMD" | grep -q '# gdocs-comments-ok' && exit 0

danger=0
# Flatten newlines/tabs/CR to spaces FIRST — grep is line-based, so a newline (or
# tab) between `gdocs` and the subcommand would otherwise split the match and bypass
# detection (codex finding: `gdocs\napply` slipped through). Detect on the flattened
# form; boundary on the subcommand so 'applyXYZ' doesn't false-match.
CMDFLAT=$(printf '%s' "$CMD" | tr '\n\t\r' '   ')
printf '%s' "$CMDFLAT" | grep -qE 'gdocs[^|]* apply( |$)' && danger=1
# gdocs replace WITHOUT the explicit comment-loss acknowledgment flag
if printf '%s' "$CMDFLAT" | grep -qE 'gdocs[^|]* replace( |$)'; then
  printf '%s' "$CMDFLAT" | grep -q -- '--full-replace-removes-comments' || danger=1
fi
# any deleteContentRange (batch-update path)
printf '%s' "$CMDFLAT" | grep -q 'deleteContentRange' && danger=1

[ "$danger" -eq 0 ] && exit 0

# Parse the doc id (from a /document/d/<id> URL or a bare 40+ char token).
DOC=$(printf '%s' "$CMD" | grep -oE 'document/d/[A-Za-z0-9_-]{25,}' | head -1 | sed 's#document/d/##')
[ -z "$DOC" ] && DOC=$(printf '%s' "$CMD" | grep -oE '[A-Za-z0-9_-]{40,}' | head -1)

if [ -z "$DOC" ]; then
  echo "gdocs-guard: BLOCKED — apply/replace/deleteContentRange detected but doc id unparseable. Use find-replace / batch-update / insert-text / comments reply, or append '# gdocs-comments-ok' if you have verified the tab is commentless." >&2
  exit 2
fi

# Fail-safe comment-count check. If the count can't be verified (API slow/timeout),
# BLOCK — the heavy, comment-laden docs are exactly the ones that time out and the
# ones we most need to protect.
# Capture the FETCH exit code separately from grep — `grep -c` exits 1 on zero
# matches, which previously tripped the fail-safe and falsely blocked commentless
# docs (codex finding, 2026-06-02). RC now reflects only whether the list succeeded.
RAW=$(timeout 20 gdocs -q comments list "$DOC" --untrusted-authors-mode 2>/dev/null); RC=$?
CNT=$(printf '%s' "$RAW" | grep -cE 'AAAB[A-Za-z0-9]{6,}')
if [ "$RC" -ne 0 ]; then
  echo "gdocs-guard: BLOCKED — could not verify comment count for $DOC within 20s (rc=$RC). Fail-safe block on apply/replace/deleteContentRange. Use comment-preserving ops (find-replace / batch-update / insert-text / comments reply). Override with '# gdocs-comments-ok' ONLY if you have verified the tab is commentless." >&2
  exit 2
fi
if [ "${CNT:-0}" -gt 0 ]; then
  echo "gdocs-guard: BLOCKED — $DOC has $CNT comment(s); apply/replace/deleteContentRange would orphan/delete them (2026-06-02 incident). Use find-replace / batch-update / insert-text / comments reply instead. Override with '# gdocs-comments-ok' only if intentional." >&2
  exit 2
fi

exit 0
