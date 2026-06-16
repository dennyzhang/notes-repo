#!/usr/bin/env bash
# diff-cheatsheet-gate-hook.sh — PreToolUse(Bash) gate for diff/config submits.
#
# Enforces the diff-cheatsheet Pre-Submit Gate's UNAMBIGUOUS, low-false-positive
# checks on every `jf submit` / `conf submit` from the agent's Bash tool:
#   - title <= 72 chars
#   - Reviewers: non-empty
#   - Tags: publish_when_ready present
#   - the `# diff-cheatsheet-ok` assertion token is on the command line
# Blocks (exit 2) with specifics if any fail.
#
# WHY content-checks, not just token presence: the failure this fixes
# (D107448117, 2026-06-05) was STAMPING `# diff-cheatsheet-ok` WITHOUT running
# the gate — a 76-char title sailed through. A token-presence-only hook can't
# catch that; this reads the actual commit message. (The cheatsheet doc long
# CLAIMED a diff-cheatsheet-ok hook existed; it never did in apply-space-hooks.sh
# — this is that hook.)
#
# Deliberately NOT enforced: summary word-count (the cap is scope-dependent
# 60/120/5-paragraphs — a fixed cap would false-block legit large-feature
# diffs). Title<=72 / reviewers / publish_when_ready are always-required and
# unambiguous, so they're safe to hard-block.
#
# Contract: PreToolUse on Bash. Reads hook JSON on stdin, inspects
# .tool_input.command. Exit 0 = allow; exit 2 = block (stderr shown to agent).
# FAIL-OPEN: if the commit message can't be read (sl slow / odd cwd), ALLOW —
# a false block on a real submit is worse than a missed quality check here.
# Override (rare, conscious): append  # diff-gate-override  to the command.
#
# Only affects INTERACTIVE agent Bash submits (the cron-diff-signal-monitor and
# OT-bot crons run jf/conf submit as plain shell scripts, not via this tool, so
# they are unaffected). Owned by operator (dennyzhang); lives in notes; wired
# into space settings.json by apply-space-hooks.sh.
set -uo pipefail

IN=$(cat 2>/dev/null)
CMD=$(printf '%s' "$IN" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Skip when a text/agent tool leads the command (keywords are DATA, not an
# actual submit) — same guard shape as gdocs-comment-guard-hook.sh.
LEAD=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]*//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*//' | awk '{print $1}' | sed -E 's#.*/##')
case "$LEAD" in codex|echo|printf|cat|grep|egrep|fgrep|sed|awk|less|more|head|tail|jq|comm|diff|tee) exit 0 ;; esac

# Only gate an ACTUAL `jf submit` / `conf submit` INVOCATION — i.e. at a command
# position (start, or after ; && || | & ( ), optionally behind `timeout N`).
# Substring-matching anywhere false-blocks read-only commands that merely mention
# the words (e.g. `grep "jf submit|sl commit"`). (2026-06-05: that exact grep got
# blocked — this is the fix.)
CMDFLAT=$(printf '%s' "$CMD" | tr '\n\t\r' '   ')
SUBMIT_RE='(^|[;&|(]|&&|\|\|)[[:space:]]*(timeout[[:space:]]+[0-9]+[[:space:]]+)?(jf[[:space:]]+submit|conf[[:space:]]+submit)([[:space:]]|$)'
printf '%s' "$CMDFLAT" | grep -qE "$SUBMIT_RE" || exit 0
# Read-only / informational invocations are not real submits (e.g.
# `conf submit --help`, `jf submit --dry-run`). Don't gate them. (2026-06-06:
# `conf submit --help` was false-blocked because it matches "conf submit" at
# command position.)
case " $CMDFLAT " in *" --help "*|*" -h "*|*" --dry-run "*) exit 0 ;; esac
case "$CMDFLAT" in *"conf submit"*) REPO="/home/dennyzhang/configerator" ;; *) REPO="/home/dennyzhang/fbsource" ;; esac

# Conscious override for rare legit exceptions.
printf '%s' "$CMDFLAT" | grep -q '# diff-gate-override' && exit 0

# Read the message of the commit being submitted (best-effort: current commit).
DESC=$(timeout 25 sl --cwd "$REPO" log -r . -T '{desc}' \
  --reason "diff-cheatsheet gate hook: read commit message - sl help log" 2>/dev/null) || exit 0
[ -z "$DESC" ] && exit 0   # fail-open: couldn't read -> allow

ERRS=""
TITLE=$(printf '%s\n' "$DESC" | head -1)
[ "${#TITLE}" -gt 72 ] && ERRS="${ERRS}- title is ${#TITLE} chars (cap 72): \"${TITLE}\"\n"
printf '%s' "$DESC" | grep -qE '^Reviewers:[[:space:]]*[^[:space:]]' || ERRS="${ERRS}- Reviewers: is empty (add a real reviewer / #project)\n"
printf '%s' "$DESC" | grep -qiE 'publish_when_ready' || ERRS="${ERRS}- missing the publish_when_ready tag\n"
printf '%s' "$CMDFLAT" | grep -q '# diff-cheatsheet-ok' || ERRS="${ERRS}- command is missing the '# diff-cheatsheet-ok' gate token (run the full Pre-Submit Gate, then append it)\n"

[ -z "$ERRS" ] && exit 0

printf 'BLOCKED (diff-cheatsheet gate) — fix the commit message, then resubmit:\n%b\nReference: cheatsheets/diff/common.md Pre-Submit Gate. Conscious exception: append  # diff-gate-override  to the command. (diff-cheatsheet-gate-hook)\n' "$ERRS" >&2
exit 2
