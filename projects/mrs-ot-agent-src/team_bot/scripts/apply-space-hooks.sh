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
cmd=$(jq -r '.tool_input.command // empty'); prog=${cmd%% *}; case "$prog" in sqlite3|sqlite|grep|rg|egrep|fgrep|cat|head|tail|echo|jq|less|printf) exit 0 ;; esac; cmd_nc="${cmd%%--text *}"; cmd_nc="${cmd_nc%%--text=*}"; cmd_nc="${cmd_nc%%--message *}"; case "$cmd_nc" in *"jf submit"*|*"conf submit"*) case "$cmd_nc" in *"# ot-weekly-sync-submit-ok"*) : ;; *) d=$(cd "$HOME/fbsource" 2>/dev/null && sl log -r . -T '{desc}' 2>/dev/null); case "$d" in *"[OT bot weekly sync]"*) echo "BLOCKED: submit of an [OT bot weekly sync] commit. The 4x/day ot-notes-fbcode-commit cron is COMMIT-ONLY; only ot-notes-fbcode-sync-weekly (Monday) may submit -- it appends the escape token '# ot-weekly-sync-submit-ok'. (gotcha_notes-fbcode-sync-stray-submit-duplicate-weekly-diffs)" >&2; exit 2 ;; esac ;; esac ;; esac
HOOK_EOF
)
CMD_DCH=$(cat <<'HOOK_EOF'
cmd=$(jq -r '.tool_input.command // empty'); prog=${cmd%% *}; case "$prog" in sqlite3|sqlite|grep|rg|egrep|fgrep|cat|head|tail|echo|jq|less|printf) exit 0 ;; esac; cmd_nc="${cmd%%--text *}"; cmd_nc="${cmd_nc%%--text=*}"; cmd_nc="${cmd_nc%%--message *}"; case "$cmd_nc" in *"jf submit"*|*"conf submit"*) case "$cmd_nc" in *"# diff-cheatsheet-ok"*) : ;; *) echo "BLOCKED: jf/conf submit without the diff-cheatsheet gate. Quality is more than the summary -- run the FULL Pre-Submit Gate self-review against the CURRENT commit message: cheatsheets/diff/common.md + the repo-specific cheatsheet (fbcode.md/configerator.md/www.md) + area .llms/rules/<area>-conventions.md. Check title prefix; summary explains WHY (motivation/design decisions) NOT a file inventory (Phab already shows changed files); word cap; no dup fields; Task/Reviewers/Tags(publish_when_ready); unit tests for functional changes; <300 lines; evidence URL. Fix every finding, THEN re-run with '# diff-cheatsheet-ok' appended. Any message-altering op (fold/metaedit/amend -m) invalidates the gate -- re-run it. (feedback_diff-cheatsheet-mandatory-every-amend). Crons submitting diffs must also run the cheatsheet and append '# diff-cheatsheet-ok' (thread Q_8ELeVd7cU 2026-05-30)." >&2; exit 2 ;; esac ;; esac
HOOK_EOF
)

CMD_REPLY="${CMD_REPLY//__SPACE_ID__/$space_id}"

# idempotency: if all three _detect markers already present, no-op (no backup)
all_present=1
for d in "reply-in-thread" "[OT bot weekly sync]" "diff-cheatsheet-ok"; do
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

echo "[apply-space-hooks] done: $added hook(s) applied for space $space_id" >&2
