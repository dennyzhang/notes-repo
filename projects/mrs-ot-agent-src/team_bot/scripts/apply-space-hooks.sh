#!/bin/bash
# apply-space-hooks.sh — idempotently apply required PreToolUse hooks to a
# MyClaw space settings.json.
#
# bash+jq rewrite of the former apply-space-hooks.py. WHY .sh: the notes repo
# deny_files allowlist rejects .py on `sl push --to master`, so the .py had no
# clean notes->fbcode path and never reached trunk (reinstall-durability gap).
# As .sh it lives in notes team_bot/ alongside bootstrap.sh / setup-cron-jobs.sh
# and rides the normal weekly notes->fbcode sync to trunk. (2026-05-30, thread
# Q_8ELeVd7cU: "change it to sh so the notes repo can store it.")
#
# Usage: apply-space-hooks.sh <path/to/spaces/<SPACE_ID>/.claude/settings.json>
# PORTABLE: space id is derived from the path, not hardcoded. Idempotent: no-op
# if every hook's _detect marker is already present; backs up before mutate.
# Requires jq. Called by bootstrap.sh apply_space_hooks() on every reinstall.
# Tracker: T266536788
set -uo pipefail

settings="${1:-}"
[ -n "$settings" ] || { echo "Usage: $0 <path/to/settings.json>" >&2; exit 1; }
[ -f "$settings" ] || { echo "[apply-space-hooks] $settings not found - skipping" >&2; exit 0; }
# jq missing is ABNORMAL (it ships on every Meta devserver) — fail VISIBLY (exit
# non-zero) so bootstrap's "|| WARNING" fires and the operator sees that the
# enforcement hooks were NOT installed, instead of a silent no-op.
command -v jq >/dev/null 2>&1 || { echo "[apply-space-hooks] ERROR: jq not found — hooks NOT installed for this space. Install jq and re-run bootstrap." >&2; exit 3; }

space_id=$(printf '%s' "$settings" | sed -n 's#.*/spaces/\([^/]*\)/\.claude/settings\.json$#\1#p')
[ -n "$space_id" ] || { echo "[apply-space-hooks] cannot derive space id from $settings - skipping" >&2; exit 0; }

CMD_REPLY=$(cat <<'HOOK_EOF'
cmd=$(jq -r '.tool_input.command // empty'); case "$cmd" in *"google.chat.message send"*"spaces/__SPACE_ID__"*) case "$cmd" in *"--reply-in-thread"*) : ;; *"# new-topic"*) : ;; *) echo "BLOCKED: send to home space without --reply-in-thread. Fold into the relevant existing thread (--reply-in-thread=spaces/__SPACE_ID__/threads/<id>). If genuinely a NEW topic, append '# new-topic' to confirm. (feedback_fold-messages-into-threads)" >&2; exit 2 ;; esac ;; esac
HOOK_EOF
)
CMD_WEEKLY=$(cat <<'HOOK_EOF'
cmd=$(jq -r '.tool_input.command // empty'); prog=${cmd%% *}; case "$prog" in sqlite3|sqlite|grep|rg|egrep|fgrep|cat|head|tail|echo|jq|less|printf) exit 0 ;; esac; cmd_nc="${cmd%%--text *}"; cmd_nc="${cmd_nc%%--text=*}"; cmd_nc="${cmd_nc%%--message *}"; cmd_nc="${cmd_nc%% -m *}"; case "$cmd_nc" in *"jf submit"*|*"conf submit"*) case "$cmd_nc" in *"# ot-weekly-sync-submit-ok"*) : ;; *) d=$(cd "$HOME/fbsource" 2>/dev/null && sl log -r . -T '{desc}' 2>/dev/null); case "$d" in *"[OT bot weekly sync]"*) echo "BLOCKED: submit of an [OT bot weekly sync] commit. The 4x/day ot-notes-fbcode-commit cron is COMMIT-ONLY; only ot-notes-fbcode-sync-weekly (Monday) may submit -- it appends the escape token '# ot-weekly-sync-submit-ok'. (gotcha_notes-fbcode-sync-stray-submit-duplicate-weekly-diffs)" >&2; exit 2 ;; esac ;; esac ;; esac
HOOK_EOF
)
CMD_DCH=$(cat <<'HOOK_EOF'
cmd=$(jq -r '.tool_input.command // empty'); prog=${cmd%% *}; case "$prog" in sqlite3|sqlite|grep|rg|egrep|fgrep|cat|head|tail|echo|jq|less|printf) exit 0 ;; esac; cmd_nc="${cmd%%--text *}"; cmd_nc="${cmd_nc%%--text=*}"; cmd_nc="${cmd_nc%%--message *}"; cmd_nc="${cmd_nc%% -m *}"; cmd_q=$(printf '%s' "$cmd_nc" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g"); case "$cmd_q" in *"jf submit"*|*"conf submit"*) case "$cmd" in *"# diff-gate-override"*) exit 0 ;; esac; gate="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/scripts/quality-gate-precheck.sh"; if [ -x "$gate" ]; then out=$(timeout 15 "$gate" 2>&1); rc=$?; if [ "$rc" = "2" ]; then printf 'BLOCKED by diff quality gate (outcome-checked, not token):\n%s\nFix via sl metaedit, then re-submit. Conscious bypass: append # diff-gate-override\n' "$out" >&2; exit 2; fi; fi; case "$cmd" in *"# diff-cheatsheet-ok"*) : ;; *) echo "BLOCKED: jf/conf submit needs the diff cheatsheet. The script-gate (title<=72 / publish_when_ready / dup-fields / summary-shape) passed, but it cannot verify reviewers-set, sibling-sweep, owning-tests, or summary-is-why -- run cheatsheets/diff/common.md + the repo cheatsheet (fbcode.md/configerator.md/www.md) + area .llms/rules, fix every finding, THEN append '# diff-cheatsheet-ok'. Any message-altering op (fold/metaedit/amend -m) invalidates it -- re-run. (feedback_diff-cheatsheet-mandatory-every-amend; crons too, thread Q_8ELeVd7cU)" >&2; exit 2 ;; esac ;; esac
HOOK_EOF
)
CMD_GATE=$(cat <<'HOOK_EOF'
cmd=$(jq -r '.tool_input.command // empty'); prog=${cmd%% *}; case "$prog" in sqlite3|sqlite|grep|rg|egrep|fgrep|cat|head|tail|echo|jq|less|printf) exit 0 ;; esac; case "$cmd" in *--no-preserve-root*) echo "BLOCKED by ai-autonomy gate (root wipe): --no-preserve-root is never legitimate for the OT bot." >&2; exit 2 ;; esac; gate="$HOME/work/claude/state/ask-gate.sh"; [ -x "$gate" ] || exit 0; v=$("$gate" --kind Bash --target "$cmd" 2>/dev/null) || exit 0; case "$v" in *"force-push"*|*"landing code"*|*"destructive SQL"*|*"root wipe"*) echo "BLOCKED by ai-autonomy gate ($v): the OT bot must NEVER force-push, land, run destructive SQL, or --no-preserve-root (CLAUDE.md: never land / never modify review state; external surfaces read-only). Use 'jf submit' (no -m, no land) or a reversible equivalent. Override needs explicit operator confirmation. (ai-autonomy Layer-1: make catastrophic impossible). NOTE: rm -rf and sl revert are intentionally NOT blocked here -- the OT bot uses them legitimately." >&2; exit 2 ;; esac
HOOK_EOF
)
# ai-autonomy Layer-2 (2026-06-10): the deterministic ask-gate enforced as a hook.
# Blocks ONLY the catastrophic hard-floor classes the OT bot provably never does
# (force-push / land / destructive SQL / root-wipe). Deliberately FAIL-OPEN: if the
# gate symlink is missing or errors, the hook exits 0 (never bricks the live daemon).
# rm -rf and `revert` are EXCLUDED on purpose -- they are legitimate OT operations
# (temp cleanup, local-file revert), so blanket-blocking them would fail real crons.
# Source: ~/notes/users/dennyzhang/projects/ai-autonomy/ (README 3-layer design).

# NOTE (2026-06-06): a URL-placeholder send-hook was tried + REVERTED. A send-path
# content-scan can't distinguish a real render-bug ("<url>"/"###" in a posted link)
# from legitimately DISCUSSING those patterns — the hook blocked the very reply that
# explained it. URL validity (P-004) is therefore enforced at CRON-RENDER time (each
# cron validates its own rendered links before posting; see CLAUDE.md "URL Validity"),
# NOT as a blanket send-hook. Do not re-add a content-scan URL hook here.

# Diagram/image readability gate (2026-06-11): recurring "diagram too small" in md.
# Blocks an `sl commit`/`amend` IN THE NOTES REPO when a committed markdown embeds a
# too-small/thin image (lint-doc-images.sh: <900px / aspect >3:1). FAIL-OPEN (missing
# lint or non-notes cwd => exit 0); escape with '# img-gate-ok'. Operator principle:
# prose lints get skipped -> make it an executable gate. (feedback_diagrams-must-be-readable)
CMD_IMG=$(cat <<'HOOK_EOF'
cmd=$(jq -r '.tool_input.command // empty'); case "$cmd" in *"sl commit"*|*"sl amend"*) : ;; *) exit 0 ;; esac; case "$PWD/" in "$HOME/notes/"*) : ;; *) exit 0 ;; esac; case "$cmd" in *"# img-gate-ok"*) exit 0 ;; esac; lint="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/lint-doc-images.sh"; [ -x "$lint" ] || exit 0; mds=$(cd "$HOME/notes" && sl status 2>/dev/null | sed -n 's/^[MA] //p' | grep -E '[.]md$'); [ -z "$mds" ] && exit 0; out=$(cd "$HOME/notes" && printf '%s\n' "$mds" | xargs -r bash "$lint" 2>/dev/null); case "$out" in *TOO-SMALL*|*BROKEN*) echo "BLOCKED: diagram image gate -- this commit touches markdown with a too-small/thin diagram image. $out  Re-render bigger (graphviz rankdir=TB + dpi>=150; verify with 'file <img.png>'). Override: append '# img-gate-ok'. (feedback_diagrams-must-be-readable)" >&2; exit 2 ;; esac
HOOK_EOF
)

# Team-chat low-signal gate (2026-06-13): command-shape PreToolUse gate — blocks a
# DIRECT `meta google.chat.message send` to the OT TEAM space without the token
# '# ot-team-send-ok'. NOT a content scan (that was tried 2026-06-06 and reverted).
CMD_TEAMSEND=$(cat <<'HOOK_EOF'
cmd=$(jq -r '.tool_input.command // empty'); prog=${cmd%% *}; case "$prog" in sqlite3|sqlite|grep|rg|egrep|fgrep|cat|head|tail|echo|jq|less|printf) exit 0 ;; esac; case "$cmd" in *"google.chat.message send"*"spaces/AAQA2bZMw24"*) case "$cmd" in *"# ot-team-send-ok"*) : ;; *) echo "BLOCKED: direct send to the OT TEAM space. Team chat = SHARED OT incidents only (job DOWN / fleet-wide systemic / real escalation). Team-bound crons gate team-worthiness in code at render time and send from their script; a deliberate one-off escalation must append '# ot-team-send-ok'. (feedback_team-chat-noise-restraint)" >&2; exit 2 ;; esac ;; esac
HOOK_EOF
)

# Stop-hook: auto-commit uncommitted OT-agent tool/cron edits at end of turn (2026-06-14).
# WHY: the Edit tool writes the file but never commits; an uncommitted notes working-tree
# edit gets WIPED by a working-tree reset (restart/notes-op), silently reverting a "fix"
# (run-fleet-health.sh gate + this very team-send hook were both lost this way). Prose
# "remember to commit" failed — make it structural. Scoped to tools/cron-jobs/scripts;
# fail-open (never blocks turn end). Commits M/A tracked files only.
CMD_AUTOCOMMIT=$(cat <<'HOOK_EOF'
cd "$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src" 2>/dev/null || exit 0; d=$(sl status tools team_bot/cron-jobs team_bot/scripts 2>/dev/null | grep -E "^[MA] " | awk "{print \$2}"); [ -z "$d" ] && exit 0; bash team_bot/scripts/notes-sl-lock.sh sl commit $d -m "[auto] checkpoint OT-agent tool/cron edits — Stop-hook durability (uncommitted notes edits get wiped by working-tree resets)" >/dev/null 2>&1 || true; exit 0
HOOK_EOF
)

CMD_REPLY="${CMD_REPLY//__SPACE_ID__/$space_id}"

# idempotency: if all _detect markers already present, no-op (no backup)
all_present=1
for d in "reply-in-thread" "[OT bot weekly sync]" "diff-cheatsheet-ok" "ai-autonomy gate" "diagram image gate" "ot-team-send-ok" "OT-agent tool/cron edits"; do
  grep -qF "$d" "$settings" || all_present=0
done
if [ "$all_present" -eq 1 ]; then
  echo "[apply-space-hooks] all hooks already present for $space_id" >&2
  exit 0
fi

cp "$settings" "${settings%.json}.pre-hook-$$.json"
added=0
apply_hook() {  # $1=detect marker  $2=command
  local detect="$1" cmd="$2" tmp
  if grep -qF "$detect" "$settings"; then
    echo "[apply-space-hooks] already present: $detect" >&2
    return 0
  fi
  tmp=$(jq --arg c "$cmd" '.hooks = (.hooks // {}) | .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher":"Bash","hooks":[{"type":"command","command":$c}]}])' "$settings") \
    || { echo "[apply-space-hooks] jq failed for: $detect" >&2; return 1; }
  printf '%s\n' "$tmp" > "$settings"
  added=$((added+1))
  echo "[apply-space-hooks] applied: $detect" >&2
}

apply_hook "reply-in-thread"      "$CMD_REPLY"
apply_hook "[OT bot weekly sync]" "$CMD_WEEKLY"
apply_hook "diff-cheatsheet-ok"   "$CMD_DCH"
apply_hook "ai-autonomy gate"     "$CMD_GATE"
apply_hook "diagram image gate"   "$CMD_IMG"
apply_hook "ot-team-send-ok"      "$CMD_TEAMSEND"

# Stop hook (different event than PreToolUse → its own jq append, no matcher).
if grep -qF "OT-agent tool/cron edits" "$settings"; then
  echo "[apply-space-hooks] already present: stop-autocommit" >&2
else
  tmp=$(jq --arg c "$CMD_AUTOCOMMIT" '.hooks = (.hooks // {}) | .hooks.Stop = ((.hooks.Stop // []) + [{"hooks":[{"type":"command","command":$c}]}])' "$settings") \
    && { printf '%s\n' "$tmp" > "$settings"; added=$((added+1)); echo "[apply-space-hooks] applied: stop-autocommit" >&2; } \
    || echo "[apply-space-hooks] jq failed for: stop-autocommit" >&2
fi

echo "[apply-space-hooks] done: $added hook(s) applied for space $space_id" >&2
