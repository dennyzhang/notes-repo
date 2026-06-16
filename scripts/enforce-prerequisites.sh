#!/usr/bin/env bash
# enforce-prerequisites.sh — Enforce "read X before doing Y" rules + hard blocks.
#
# Two modes (set via ENFORCE_MODE env var):
#   TRACK  — called by PostToolUse on Read. Records that a prerequisite was loaded.
#   CHECK  — called by PreToolUse on Bash. Verifies prerequisite was loaded before action.
#
# Sentinel files: /tmp/claude-prereq-{name} with timestamp.
# Sentinels expire after 4 hours (a session should not be longer).
#
# Usage in hooks:
#   PostToolUse Read:  ENFORCE_MODE=TRACK bash ~/work/claude/scripts/enforce-prerequisites.sh "$CLAUDE_TOOL_INPUT"
#   PreToolUse Bash:   ENFORCE_MODE=CHECK bash ~/work/claude/scripts/enforce-prerequisites.sh "$CLAUDE_TOOL_INPUT"

TOOL_INPUT="${1:-}"
MODE="${ENFORCE_MODE:-CHECK}"
MAX_AGE=14400  # 4 hours

# Load enforcement metrics logging
SCRIPT_DIR_EP="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "$HOME/work/claude/scripts")"
source "$SCRIPT_DIR_EP/enforcement-log.sh" 2>/dev/null || true

# Session-scoped sentinel directory — prevents cross-session false positives.
# Source order: env var (if harness exports it) → JSON stdin payload → PID fallback.
# Claude Code does NOT propagate CLAUDE_CODE_CURRENT_SESSION_ID into hook subprocesses
# but DOES include "session_id" in the JSON payload passed via stdin (which becomes $1).
# Without parsing the JSON, every Bash call gets a different PID and sentinels written
# by Read tracking are unreachable from later Bash checks — silently breaking enforcement.
SID="${CLAUDE_CODE_CURRENT_SESSION_ID:-}"
if [ -z "$SID" ]; then
    SID=$(printf '%s' "$TOOL_INPUT" | grep -oP '"session_id"\s*:\s*"\K[^"]+' | head -1)
fi
if [ -n "$SID" ]; then
    SID_SHORT=$(echo "$SID" | md5sum | cut -c1-8)
else
    SID_SHORT="$$"
    # Regression alarm: hook input looks like JSON (Claude harness payload) but
    # session_id couldn't be extracted. This means harness changed payload format
    # or env propagation broke — silently degrades sentinels to per-PID, which is
    # what caused D104170893's miss. Emit a one-line warning to the metrics CSV.
    if printf '%s' "$TOOL_INPUT" | head -c 1 | grep -q '{'; then
        log_enforcement "sid-fallback" "session_id parse" "warned" "JSON payload but no session_id; falling back to PID — check harness env propagation" 2>/dev/null || true
    fi
fi
SENTINEL_DIR="/tmp/claude-prereq-${SID_SHORT}"
mkdir -p "$SENTINEL_DIR"

# ── TRACK mode: record prerequisite was loaded ───────────────────────────────
if [ "$MODE" = "TRACK" ]; then
    # gdocs cheatsheet (matches both old path and new folder path)
    if echo "$TOOL_INPUT" | grep -qE 'cheatsheet-gdocs|gdocs/rules'; then
        date +%s > "$SENTINEL_DIR/gdocs"
    fi
    # diff-common cheatsheet
    if echo "$TOOL_INPUT" | grep -qE 'cheatsheet-diff-common|diff/common'; then
        date +%s > "$SENTINEL_DIR/diff"
    fi
    # diff-review cheatsheet
    if echo "$TOOL_INPUT" | grep -qE 'cheatsheet-diff-review|diff/review'; then
        date +%s > "$SENTINEL_DIR/diff-review"
    fi
    exit 0
fi

# ── CHECK mode: verify prerequisite before action ────────────────────────────
if [ "$MODE" = "CHECK" ]; then

    # Escape hatch: if CLAUDE_OVERRIDE=1 is set, log and allow all actions
    if [ "${CLAUDE_OVERRIDE:-0}" = "1" ]; then
        log_enforcement "OVERRIDE" "$(echo "$TOOL_INPUT" | head -c 80)" "overridden" "escape hatch used"
        exit 0
    fi

    check_sentinel() {
        local name="$1"
        local label="$2"
        local sentinel="$SENTINEL_DIR/$name"
        # Fallback for cron-spawned sessions (different PID, no session ID)
        local cron_sentinel="/tmp/claude-prereq-cron/$name"

        # Check session-scoped sentinel first
        if [ -f "$sentinel" ]; then
            local ts
            ts=$(cat "$sentinel" 2>/dev/null || echo "0")
            local age=$(( $(date +%s) - ts ))
            if [ "$age" -le "$MAX_AGE" ]; then
                return 0
            fi
            rm -f "$sentinel"
        fi

        # Fallback: check cron sentinel (set by load_cheatsheet in cron scripts)
        if [ -f "$cron_sentinel" ]; then
            local ts
            ts=$(cat "$cron_sentinel" 2>/dev/null || echo "0")
            local age=$(( $(date +%s) - ts ))
            if [ "$age" -le "$MAX_AGE" ]; then
                return 0
            fi
            rm -f "$cron_sentinel"
        fi

        return 1
    }

    # ── HARD BLOCKS: actions that should NEVER happen ────────────────────────

    # gdocs replace — HARD BLOCK if doc has comments. No flag overrides this.
    # The flag --full-replace-removes-comments is NOT an override — it just means
    # you know comments will be destroyed. The hook STILL blocks if comments exist.
    # Only allowed on docs with ZERO comments.
    if echo "$TOOL_INPUT" | grep -qE 'gdocs replace\b'; then
        doc_id=$(echo "$TOOL_INPUT" | grep -oP '[a-zA-Z0-9_-]{25,}' | head -1)
        if [ -n "$doc_id" ]; then
            comment_count=$(timeout 10 google-mux api call GET \
                "https://www.googleapis.com/drive/v3/files/${doc_id}/comments?fields=comments(id)&pageSize=100" \
                < /dev/null 2>/dev/null | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('comments',[])))" 2>/dev/null || echo "0")
            if [ "$comment_count" -gt 0 ]; then
                log_enforcement "gdocs-replace" "gdocs replace" "HARD-BLOCKED" "doc has $comment_count comments"
                echo "HARD BLOCKED: Doc has $comment_count comments. gdocs replace destroys ALL of them."
                echo "No flag overrides this. Use batch-update + find-replace to preserve comments."
                echo "Or reply to comments first, wait for user to resolve, then replace when count = 0."
                exit 1
            fi
        fi
        if ! echo "$TOOL_INPUT" | grep -q "full-replace-removes-comments"; then
            log_enforcement "gdocs-replace" "gdocs replace" "blocked" "missing flag on 0-comment doc"
            echo "BLOCKED: gdocs replace requires --full-replace-removes-comments flag."
            exit 1
        fi
        log_enforcement "gdocs-replace" "gdocs replace" "allowed" "0 comments + explicit flag"
    fi

    # gdocs get --text — discards formatting, comments, hyperlink URLs
    if echo "$TOOL_INPUT" | grep -qE 'gdocs get.*--text'; then
        log_enforcement "gdocs-get-text" "gdocs get --text" "blocked" "discards formatting"
        echo "BLOCKED: Never use '--text' for reading. It discards formatting, comments, and hyperlinks."
        echo "Use bare 'gdocs get <DOC>' (ghtml format) instead."
        exit 1
    fi

    # gdocs comments resolve — Denny resolves comments himself
    if echo "$TOOL_INPUT" | grep -qE 'gdocs comments resolve'; then
        log_enforcement "gdocs-comments-resolve" "gdocs comments resolve" "blocked" "user resolves manually"
        echo "BLOCKED: Never resolve Google Doc comments. Denny resolves them himself."
        exit 1
    fi

    # gchat send/post — GChat is READ-ONLY
    if echo "$TOOL_INPUT" | grep -qE 'gchat (send|post)|SendMessage'; then
        log_enforcement "gchat-readonly" "gchat send/post" "blocked" "GChat is read-only"
        echo "BLOCKED: GChat is READ-ONLY. Never send messages."
        exit 1
    fi

    # ── CONDITIONAL BLOCKS: blocked when specific conditions are met ─────────

    # gdocs apply — blocked when doc has unresolved comments (uses cached comment counts)
    if echo "$TOOL_INPUT" | grep -qE 'gdocs apply\b'; then
        DOC_ID=$(printf '%s' "$TOOL_INPUT" | grep -oP '[a-zA-Z0-9_-]{30,}' | head -1 | tr -cd 'a-zA-Z0-9_-')
        COMMENT_CACHE="$HOME/work/claude/context/cache/state/gdocs-comment-counts.json"
        if [ -n "$DOC_ID" ] && [ -f "$COMMENT_CACHE" ]; then
            COMMENT_COUNT=$(python3 -c "import json; print(json.load(open('$COMMENT_CACHE')).get('$DOC_ID', 0))" 2>/dev/null || echo 0)
            if [ "$COMMENT_COUNT" -gt 0 ]; then
                log_enforcement "gdocs-apply-comments" "gdocs apply" "blocked" "doc $DOC_ID has $COMMENT_COUNT comments"
                echo "BLOCKED: Doc $DOC_ID has $COMMENT_COUNT cached unresolved comments."
                echo "'gdocs apply' replaces the entire body and destroys comment anchors."
                echo "Use batch-update or find-replace for surgical changes instead."
                echo "If comments were resolved since last cache update, run: gdocs comments list $DOC_ID"
                exit 1
            fi
        fi
    fi

    # jf submit without --draft — publishing triggers reviewer notifications
    if echo "$TOOL_INPUT" | grep -qE 'jf submit\b'; then
        if ! echo "$TOOL_INPUT" | grep -qF -- '--draft'; then
            log_enforcement "jf-submit-no-draft" "jf submit" "blocked" "missing --draft flag"
            echo "BLOCKED: 'jf submit' requires '--draft'. Never publish directly."
            echo "Use: jf submit --draft"
            exit 1
        fi

        # publish_when_ready tag in commit message — auto-publishes on CI green
        # even when submitted with --draft. This was the root cause of the
        # 2026-05-01 D103341001 unintended publish: --draft submit succeeded,
        # then CI signals went green and the tag triggered auto-publication.
        # Default policy is "draft truly means draft". Opt in to auto-publish
        # via ALLOW_PUBLISH_WHEN_READY=1.
        if [ "${ALLOW_PUBLISH_WHEN_READY:-0}" != "1" ]; then
            # Find the active sl repo. Prefer the cwd's repo (since the harness
            # runs hooks from the user's cwd). Fall back to known paths.
            ACTIVE_REPO=""
            for cand in "$PWD" "$(dirname "$PWD")" "/data/users/$USER/fbsource" "$HOME/local/configerator" "$HOME/configerator" "$HOME/www" "$HOME/fbsource"; do
                if [ -n "$cand" ] && [ -d "$cand" ] && (cd "$cand" 2>/dev/null && sl root >/dev/null 2>&1); then
                    ACTIVE_REPO=$(cd "$cand" && sl root 2>/dev/null)
                    [ -n "$ACTIVE_REPO" ] && break
                fi
            done

            if [ -n "$ACTIVE_REPO" ]; then
                # If --stack is in the command, walk every draft commit in
                # the stack (ancestors of . that are still draft, plus .
                # itself). Otherwise check only the current commit.
                if echo "$TOOL_INPUT" | grep -qF -- '--stack'; then
                    REVSET='ancestors(.) and draft() + .'
                else
                    REVSET='.'
                fi

                # Use {phabstatus} to skip commits in terminal states. jf will
                # silently skip those during --stack submission, so blocking on
                # their tags is a false positive. Terminal states: Committed,
                # Closed, Abandoned. Active: Draft, Needs Review, Accepted, Landing.
                if ! ALL_MSGS=$(cd "$ACTIVE_REPO" && sl log -r "$REVSET" -T '{phabstatus}\n{desc}\n---PWR-COMMIT-BREAK---\n' 2>/dev/null); then
                    # FAIL-CLOSED: cannot read commit messages → block with
                    # explanation. Better to false-positive than to miss a
                    # publish_when_ready tag.
                    log_enforcement "jf-submit-publish-tag" "jf submit" "blocked" "could not read commit messages (fail-closed)"
                    echo "BLOCKED: 'jf submit' — could not read commit message(s) from $ACTIVE_REPO."
                    echo "Hook fails closed on this check to prevent accidental publish."
                    echo "Verify 'sl log -r .' works, then retry."
                    exit 1
                fi

                # Detect the tag. Handle two layouts: same-line ('Tags: foo, publish_when_ready')
                # and continuation-indent ('Tags:\n  publish_when_ready'). The python check
                # treats every line that follows a 'Tags:' header (until the next blank
                # line or non-indented header) as a continuation tag value.
                if BAD_DESC=$(printf '%s' "$ALL_MSGS" | python3 -c "
import sys, re
data = sys.stdin.read()
TERMINAL = {'Committed', 'Closed', 'Abandoned'}
header_re = re.compile(r'^[A-Za-z][A-Za-z\\-]*:')
# Each block: phabstatus on first line, then commit message, then separator.
for block in data.split('---PWR-COMMIT-BREAK---'):
    block = block.strip('\\n')
    if not block:
        continue
    lines = block.split('\\n')
    if not lines:
        continue
    status = lines[0].strip()
    desc = '\\n'.join(lines[1:])
    if status in TERMINAL:
        continue  # jf skips these on --stack; checking their tag is a false positive
    in_tags = False
    for raw in desc.split('\\n'):
        line = raw.rstrip()
        if re.match(r'^[ \\t]*Tags:', line):
            in_tags = True
            tail = line.split(':', 1)[1]
            if re.search(r'\\bpublish_when_ready\\b', tail):
                # Print first non-empty line of desc as title
                title = next((l for l in desc.split('\\n') if l.strip()), '<unknown>')
                print(title.strip())
                sys.exit(0)
        elif in_tags:
            if line.strip() == '':
                in_tags = False
            elif header_re.match(line):
                in_tags = False
            elif re.search(r'\\bpublish_when_ready\\b', line):
                title = next((l for l in desc.split('\\n') if l.strip()), '<unknown>')
                print(title.strip())
                sys.exit(0)
sys.exit(1)
" 2>/dev/null); then
                    log_enforcement "jf-submit-publish-tag" "jf submit" "blocked" "commit '$BAD_DESC' has publish_when_ready tag"
                    echo "BLOCKED: 'jf submit' — a commit in this submit set has 'Tags: publish_when_ready'."
                    echo ""
                    echo "Offending commit (title): $BAD_DESC"
                    echo "Scope checked: $REVSET (in $ACTIVE_REPO)"
                    echo ""
                    echo "Why: that tag triggers auto-publish on CI green even with --draft."
                    echo "This was the root cause of the 2026-05-01 D103341001 unintended publish."
                    echo ""
                    echo "Fix one of:"
                    echo "  1. Remove the tag from EVERY commit in the stack:"
                    echo "     sl metaedit                # interactive"
                    echo "     sl metaedit -r <hash> -m \"<msg without publish_when_ready>\""
                    echo "     (preserve the 'Differential Revision:' footer on each)"
                    echo "  2. Opt in for this submit only:"
                    echo "     ALLOW_PUBLISH_WHEN_READY=1 jf submit --draft --stack"
                    exit 1
                fi
            fi
            # If ACTIVE_REPO empty (no sl repo found near cwd) — silently
            # skip the tag check; the user isn't in a sl-managed repo, so
            # `jf submit` would fail for unrelated reasons anyway.
        fi
    fi

    # ── PREREQUISITE CHECKS: require reading cheatsheet first ────────────────

    # gdocs operations require gdocs cheatsheet — ANY Google Doc update triggers this,
    # not just routine/batch-update. Broad match: apply, create, edit, replace, batch-update,
    # content *, comments *, format-after-push, insert-*, update-*, delete-*, tab *.
    if echo "$TOOL_INPUT" | grep -qE 'gdocs (apply|create|edit|replace|batch-update|content|comments|format-after-push|insert|update|delete|tab) '; then
        if ! check_sentinel "gdocs" "gdocs/rules.md"; then
            log_enforcement "prereq-gdocs" "gdocs operation" "blocked" "cheatsheet not read"
            echo "BLOCKED: Read cheatsheets/gdocs/rules.md before ANY Google Doc update."
            echo "Rule: CLAUDE.md requires loading the gdocs cheatsheet before any doc mutation, not just routine/batch-update."
            exit 1
        fi
    fi

    # jf submit requires diff-common cheatsheet
    if echo "$TOOL_INPUT" | grep -qE 'jf submit'; then
        if ! check_sentinel "diff" "diff/common.md"; then
            log_enforcement "prereq-diff" "jf submit" "blocked" "diff cheatsheet not read"
            echo "BLOCKED: Read cheatsheets/diff/common.md before diff operations."
            echo "Rule: CLAUDE.md requires loading the diff cheatsheet before submitting."
            exit 1
        fi
    fi

    # Diff review requires diff-review cheatsheet (sentinel tracked but CHECK was missing)
    if echo "$TOOL_INPUT" | grep -qE 'meta phabricator\.diff (comments|raw-diff|metadata)'; then
        if ! check_sentinel "diff-review" "diff/review.md"; then
            log_enforcement "prereq-diff-review" "diff review" "blocked" "review cheatsheet not read"
            echo "BLOCKED: Read cheatsheets/diff/review.md before reviewing a diff."
            echo "Rule: CLAUDE.md requires loading the diff review cheatsheet before review operations."
            exit 1
        fi
    fi
fi

exit 0
