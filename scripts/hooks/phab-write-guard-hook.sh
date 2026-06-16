#!/usr/bin/env bash
# phab-write-guard-hook.sh — PreToolUse(Bash) hard block on posting to Phabricator.
#
# WHY: "never comment on / accept a Phabricator diff" is a hard rule —
# the API authenticates as the operator, so any post lands in his voice. But the
# rule lived only in prompts (CLAUDE.md/SOUL/HEARTBEAT.md) with NO enforcement, so
# it kept leaking: `jf submit -m "..."` posts the message as a diff COMMENT, and a
# heartbeat agent could run `meta phabricator.diff comment/reply-comment/accept`.
# (2026-06-07: D106871328 accumulated 3+ "auto-fix..." comments via `jf submit -m`.)
# Prompt-only mandates get skipped — this is the hook that makes the rule real
# (same lesson as diff-cheatsheet-gate-hook).
#
# BLOCKS (exit 2) from the agent's Bash tool, at command position:
#   - meta phabricator.diff comment | reply-comment | inline-comment
#   - meta phabricator.diff accept | resist | request-changes
#   - jf submit ... with -m / --message  (the comment vector)
# ALLOWS (read-only / state-only, per SOUL's narrow exceptions):
#   - meta phabricator.diff comments (PLURAL = list/read) | metadata | ci-status |
#     land-status | stack | abandon | remove-dependency | publish
#   - `publish` promotes a draft to Needs Review — a STATE change, no voiced text
#     posted (like abandon). Explicitly authorized by Denny 2026-06-09.
#   - jf submit --draft / --update-fields  (no -m)
#
# Only affects INTERACTIVE agent Bash. Crons run jf/meta as plain shell, NOT via
# this tool, so they're unaffected (the cron's own `jf submit -m` was fixed in
# code). Conscious override: append  # phab-write-override.
# FAIL-OPEN: unreadable input -> allow (a false block on real work is worse here).
set -uo pipefail

IN=$(cat 2>/dev/null)
CMD=$(printf '%s' "$IN" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

CMDFLAT=$(printf '%s' "$CMD" | tr '\n\t\r' '   ')

# Conscious override.
printf '%s' "$CMDFLAT" | grep -q '# phab-write-override' && exit 0

# COMMAND-POSITION matching (start, or after ; & | && || ( , optionally behind
# `timeout N`). This is deliberately NOT a lead-only skip: a lead skip let a
# piped/stdin post slip (`printf x | meta phabricator.diff comment --file=-`).
# Command-position anchoring catches that while NOT false-blocking a quoted
# mention like `grep "phabricator.diff comment"` (there `meta` isn't at a command
# position). (2026-06-07: closed the pipe-bypass in this guard.)

# 1) `meta [flags] phabricator.diff <write-verb>` at command position (comment
#    SINGULAR, not the read-only `comments`). The optional [^;&|]* keeps the match
#    inside ONE command segment (won't cross a pipe).
PHAB_POST_RE='(^|[;&|(]|&&|\|\|)[[:space:]]*(timeout[[:space:]]+[0-9]+[[:space:]]+)?meta[[:space:]]+([^;&|]*[[:space:]])?phabricator\.diff[[:space:]]+(comment|reply-comment|inline-comment|accept|resist|request-changes)([[:space:]]|$)'
if printf '%s' "$CMDFLAT" | grep -qE "$PHAB_POST_RE"; then
    printf 'BLOCKED (phab-write-guard) — never post to a Phabricator diff (it posts in the operator'\''s voice).\nDo the code fix -> amend -> `jf submit --draft`, and PASTE the reply draft in chat for the operator to post.\nRead-only verbs (comments/metadata/ci-status) + abandon/remove-dependency/publish are fine. Conscious exception: append  # phab-write-override. (phab-write-guard)\n' >&2
    exit 2
fi

# 2) `jf submit` at command position carrying -m / --message → posts a diff comment.
JF_SUBMIT_RE='(^|[;&|(]|&&|\|\|)[[:space:]]*(timeout[[:space:]]+[0-9]+[[:space:]]+)?jf[[:space:]]+submit([[:space:]]|$)'
if printf '%s' "$CMDFLAT" | grep -qE "$JF_SUBMIT_RE" \
   && printf '%s' "$CMDFLAT" | grep -qE '(^|[[:space:]])(-m|--message)([[:space:]]|=)'; then
    printf 'BLOCKED (phab-write-guard) — `jf submit -m/--message` posts the message as a diff COMMENT in the operator'\''s voice.\nSubmit without -m (use `jf submit --draft` / `--update-fields`); the change itself carries the commit message. Conscious exception: append  # phab-write-override. (phab-write-guard)\n' >&2
    exit 2
fi

exit 0
