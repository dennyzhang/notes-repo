#!/bin/bash
# commit-digest.sh — split working tree into SIGNAL/STATE buckets (+ an
# optional chore commit for untracking gitignored files) and commit each
# with a descriptive digest message.
#
# Produces up to 3 commits per run:
#   chore:  untrack N file(s) now covered by .gitignore   (if any)
#   signal: YYYY-MM-DD — N file(s) [areas]                (worth reviewing)
#   state:  YYYY-MM-DD — N auto-generated file(s) (skim only)
#
# Usage:
#   scripts/commit-digest.sh            # commit in buckets
#   scripts/commit-digest.sh --dry-run  # print messages, do not commit
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

cd "$(git rev-parse --show-toplevel)"

# Files considered auto-generated (match git-review.sh).
STATE_REGEX='^(HANDOFF|ALERTS|TASK-LOG|FOLLOWUPS|TASKS)\.md$'
STATE_REGEX+='|^context/(STATE|CONTEXT|HANDOFF|IMPACT|LOCAL-TASKS|CONTEXT-FAILURES)\.md$'
STATE_REGEX+='|^context/cache/'
STATE_REGEX+='|^context/myself/PATTERNS\.md$'
STATE_REGEX+='|^projects/.*/SIGNALS\.md$'
STATE_REGEX+='|^projects/_health-cache\.json$'
STATE_REGEX+='|^memory/MEMORY\.md$'
STATE_REGEX+='|\.db-(shm|wal)$'

DATE=$(date '+%Y-%m-%d')

# ── Phase A: chore commit for gitignored-but-tracked files ───────────────────
# `git add -A` would re-stage these because they're already tracked; the only
# way to make .gitignore actually apply is to commit an explicit removal.
tracked_ignored=$(git ls-files -ci --exclude-standard 2>/dev/null || true)
if [[ -n "$tracked_ignored" ]]; then
    n_ignored=$(printf '%s\n' "$tracked_ignored" | wc -l | tr -d ' ')
    chore_msg=$(printf 'chore: untrack %d file(s) now covered by .gitignore\n\nKept on disk, removed from git so `git add -A` stops restaging them.\n\n%s' \
        "$n_ignored" \
        "$(printf '%s\n' "$tracked_ignored" | sed 's/^/  /')")
    if $DRY_RUN; then
        echo "─── DRY RUN: chore commit (${n_ignored} untracking) ───"
        echo "$chore_msg"
        echo
    else
        # shellcheck disable=SC2086
        printf '%s\n' "$tracked_ignored" | xargs -d '\n' git rm --cached -- >/dev/null
        git commit -m "$chore_msg"
    fi
fi

# ── Phase B: enumerate real changes ──────────────────────────────────────────
MODIFIED=$(git diff --name-only HEAD 2>/dev/null || true)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null || true)

# Combine; strip empty lines; dedup
ALL_FILES=$(printf '%s\n%s\n' "$MODIFIED" "$UNTRACKED" | awk 'NF' | sort -u)

# Exclude anything already handled by the chore commit (tracked-ignored).
if [[ -n "${tracked_ignored:-}" ]]; then
    ALL_FILES=$(printf '%s\n' "$ALL_FILES" \
        | grep -Fxv -f <(printf '%s\n' "$tracked_ignored") || true)
fi

if [[ -z "$ALL_FILES" ]]; then
    if [[ -z "$tracked_ignored" ]]; then
        echo "commit-digest: no changes to commit"
    fi
    exit 0
fi

SIGNAL_FILES=()
STATE_FILES=()
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ "$f" =~ $STATE_REGEX ]]; then
        STATE_FILES+=("$f")
    else
        SIGNAL_FILES+=("$f")
    fi
done <<< "$ALL_FILES"

# Short hint from a file: first added line from diff, or first non-trivial
# line from the file itself if it's untracked.
file_hint() {
    local f="$1"
    local hint=""
    if git cat-file -e "HEAD:$f" 2>/dev/null; then
        hint=$(git diff -- "$f" 2>/dev/null \
            | grep -E '^\+[^+]' \
            | grep -vE '^\+[[:space:]]*$' \
            | grep -vE '^\+[[:space:]]*[{}()\[\]]+[[:space:]]*$' \
            | head -1 \
            | sed -E 's|^\+[[:space:]]*||; s/[[:space:]]+/ /g' \
            | cut -c1-70)
    fi
    if [[ -z "$hint" && -f "$f" ]]; then
        hint=$(grep -avE '^[[:space:]]*$' "$f" 2>/dev/null \
            | grep -avE '^[[:space:]]*[{}()\[\]]+[[:space:]]*$' \
            | grep -avE '^#!/' \
            | head -1 \
            | sed -E 's|^[[:space:]]*||; s/[[:space:]]+/ /g' \
            | cut -c1-70)
    fi
    [[ -z "$hint" ]] && hint="(binary/rename/delete)"
    printf '%s' "$hint"
}

file_stat() {
    local f="$1"
    # Modified tracked file
    local stat
    stat=$(git diff --numstat -- "$f" 2>/dev/null | awk '{printf "+%s -%s", $1, $2}')
    if [[ -n "$stat" ]]; then
        printf '%s' "$stat"
        return
    fi
    # Untracked new file → line count (text) or "new" (binary)
    if [[ -f "$f" ]]; then
        if file --mime "$f" 2>/dev/null | grep -q 'charset=binary'; then
            printf 'new binary'
        else
            local lines
            lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
            printf '+%s new' "${lines:-0}"
        fi
    else
        printf 'deleted'
    fi
}

build_signal_msg() {
    local n="${#SIGNAL_FILES[@]}"
    local areas
    areas=$(printf '%s\n' "${SIGNAL_FILES[@]}" \
        | awk -F/ '{print $1}' | sort -u | paste -sd, - | cut -c1-50)
    printf 'signal: %s — %d file(s) [%s]\n\n' "$DATE" "$n" "$areas"
    printf 'Files:\n'
    for f in "${SIGNAL_FILES[@]}"; do
        printf '  %-52s  %-12s  %s\n' "$f" "$(file_stat "$f")" "$(file_hint "$f")"
    done
}

build_state_msg() {
    local n="${#STATE_FILES[@]}"
    printf 'state: %s — %d auto-generated file(s) (skim only)\n\n' "$DATE" "$n"
    printf 'Auto-updated by cron/sessions. Not worth manual review on GitHub.\n\n'
    for f in "${STATE_FILES[@]}"; do
        printf '  %-52s  %s\n' "$f" "$(file_stat "$f")"
    done
}

commit_bucket() {
    local bucket_name="$1"
    local msg="$2"
    shift 2
    local files=("$@")
    (( ${#files[@]} == 0 )) && return 0

    if $DRY_RUN; then
        echo "─── DRY RUN: ${bucket_name} commit (${#files[@]} files) ───"
        echo "$msg"
        echo
        return 0
    fi

    git add -- "${files[@]}"
    if git diff --cached --quiet; then
        echo "commit-digest: ${bucket_name} — nothing to commit after staging"
        return 0
    fi
    git commit -m "$msg"
}

if (( ${#SIGNAL_FILES[@]} > 0 )); then
    signal_msg=$(build_signal_msg)
    commit_bucket "signal" "$signal_msg" "${SIGNAL_FILES[@]}"
fi

if (( ${#STATE_FILES[@]} > 0 )); then
    state_msg=$(build_state_msg)
    commit_bucket "state" "$state_msg" "${STATE_FILES[@]}"
fi
