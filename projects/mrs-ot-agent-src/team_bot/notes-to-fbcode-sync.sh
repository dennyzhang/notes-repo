#!/usr/bin/env bash
# notes-to-fbcode-sync.sh — one-way mirror of notes prompts/docs to fbcode.
#
# Notes is canonical for cron prompts, docs, and configs (post-2026-05-15
# migration). This script keeps the fbcode mirror up to date so:
#   1. Devserver reinstalls bootstrapping from fbcode get current prompts.
#   2. Operators auditing fbcode see current state.
#
# Rolling-weekly-diff strategy (2026-05-16):
#   - 4× daily syncs do NOT each create a new diff.
#   - First drift of the week → new local commit (no jf submit yet).
#   - Subsequent drifts the same week → sl amend onto that commit.
#   - Monday-morning rollover (handled by cron) → jf submit --draft --publish-when-ready.
#   Rationale: reduces reviewer noise from ~28 diffs/week to 1.
#
# Manual dry-run:  bash <script> --dry-run
# Cron invocation: bash <script> --week=2026-W20 [--amend-commit=<7-char hash>]
#
# Exit codes:  0 = success (no-drift or commit/amend OK)
#              1 = error (abort, stderr has details)
#
# Stdout (on drift): COMMIT_HASH=<7-char hash>
# Stdout (no drift): [no drift]

set -uo pipefail

readonly NOTES_SRC="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src"
readonly FBCODE_DST="$HOME/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent"

DRY_RUN=0
WEEK=""
AMEND_COMMIT=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --week=*) WEEK="${arg#--week=}" ;;
        --amend-commit=*) AMEND_COMMIT="${arg#--amend-commit=}" ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

if [ ! -d "$NOTES_SRC" ]; then
    echo "ERROR: notes source missing: $NOTES_SRC" >&2
    exit 1
fi
if [ ! -d "$FBCODE_DST" ]; then
    echo "ERROR: fbcode destination missing: $FBCODE_DST" >&2
    exit 1
fi

echo "[notes-to-fbcode-sync] notes:         $NOTES_SRC" >&2
echo "[notes-to-fbcode-sync] fbcode:        $FBCODE_DST" >&2
echo "[notes-to-fbcode-sync] week:          ${WEEK:-(unset)}" >&2
echo "[notes-to-fbcode-sync] amend-commit:  ${AMEND_COMMIT:-(new commit)}" >&2
echo "[notes-to-fbcode-sync] dry-run:       $DRY_RUN" >&2
echo >&2

cd "$HOME/fbsource"

# --- Safety check / repo positioning ---
if [ "$DRY_RUN" -eq 0 ]; then
    if [ -n "$AMEND_COMMIT" ]; then
        # Amend mode: must be on the weekly commit OR working copy clean before switching.
        CURRENT_HASH=$(sl log -r . -T '{node|short}' 2>/dev/null || echo "")
        if [ "$CURRENT_HASH" != "$AMEND_COMMIT" ]; then
            DIRTY=$(sl status "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>/dev/null | grep -vE '^[?!]' | grep -v '^$' | wc -l)
            if [ "$DIRTY" -gt 0 ]; then
                echo "ERROR: fbcode/pe_mrs_ml/mrs_ot_agent/ has uncommitted changes and we are not on the weekly commit ($AMEND_COMMIT). Aborting." >&2
                sl status "fbcode/pe_mrs_ml/mrs_ot_agent/" >&2
                exit 1
            fi
            echo "[notes-to-fbcode-sync] switching to weekly commit $AMEND_COMMIT ..." >&2
            if ! sl goto "$AMEND_COMMIT" 2>&1 >&2; then
                echo "ERROR: sl goto $AMEND_COMMIT failed." >&2
                exit 1
            fi
        fi
    else
        # New-commit mode: working copy must be clean.
        DIRTY=$(sl status "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>/dev/null | grep -vE '^[?!]' | grep -v '^$' | wc -l)
        if [ "$DIRTY" -gt 0 ]; then
            echo "ERROR: fbcode/pe_mrs_ml/mrs_ot_agent/ has uncommitted modifications. Aborting." >&2
            sl status "fbcode/pe_mrs_ml/mrs_ot_agent/" >&2
            exit 1
        fi
    fi
fi

# --- File copy loop ---
PATHS_FILE=$(mktemp -t notes-sync-paths.XXXXXX)
trap "rm -f $PATHS_FILE" EXIT

SYNC_COUNT=0
while IFS= read -r src; do
    rel="${src#$NOTES_SRC/}"

    # Skip notes-only artifacts and patch-reject files
    [ "$rel" = "MIGRATION.md" ] && continue
    [[ "$rel" == *.rej ]] && continue

    # Map .dot.txt → .dot for fbcode (notes blocks .dot extension)
    fbcode_rel="$rel"
    if [ "$rel" = "team_bot/architecture.dot.txt" ]; then
        fbcode_rel="team_bot/architecture.dot"
    fi

    dst="$FBCODE_DST/$fbcode_rel"

    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        continue
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[WOULD-COPY] $rel" >&2
    else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "[COPIED   ] $rel" >&2
    fi
    echo "$fbcode_rel" >> "$PATHS_FILE"
    SYNC_COUNT=$((SYNC_COUNT + 1))
done < <(/usr/bin/find "$NOTES_SRC" -type f | sort)

echo >&2
if [ "$SYNC_COUNT" -eq 0 ]; then
    echo "[no drift]"
    exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[notes-to-fbcode-sync] dry-run: $SYNC_COUNT files would sync." >&2
    exit 0
fi

# --- Commit or amend ---
NOTES_REV=$(cd "$HOME/notes" && sl log -r . -T '{node|short}' 2>/dev/null || echo "unknown")
SYNCED_LIST=$(awk '{print "- " $0}' "$PATHS_FILE")
WEEK_LABEL="${WEEK:-$(date -u +%G-W%V)}"

if [ -n "$AMEND_COMMIT" ]; then
    echo "[notes-to-fbcode-sync] amending weekly commit $AMEND_COMMIT with $SYNC_COUNT new file(s)..." >&2
    # Same sl-add-before-mutate discipline as the commit path below. Untracked
    # files (newly synced) won't be picked up by sl amend without an explicit add.
    sl add "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>/dev/null || true
    if ! sl amend "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>&1 >&2; then
        echo "[ERROR] sl amend failed" >&2
        exit 1
    fi
else
    COMMIT_MSG="[OT bot weekly sync] notes->fbcode $WEEK_LABEL

Summary:
- **Why**: notes is canonical for OT-bot prompts/docs (post-2026-05-15 migration). This auto-sync keeps fbcode mirror current so devserver reinstalls bootstrapping from fbcode get fresh prompts.
- **Fix**: $SYNC_COUNT file(s) copied notes->fbcode. Pure mirror, no semantic change.
- **Scope**: doc/prompt only. Code paths (src/, tests/, BUCK, .llms/) untouched.

Synced files:
$SYNCED_LIST

Source: notes commit $NOTES_REV on user/dennyzhang bookmark.

Test Plan:
Verify \`diff -r <notes_src>/<path> <fbcode_dst>/<path>\` returns no output for each synced file.

Reviewers: mrs-ot-reliability

Tasks: T259215482

Tags: publish_when_ready"

    echo "[notes-to-fbcode-sync] creating weekly commit for $WEEK_LABEL ($SYNC_COUNT file(s))..." >&2
    # Ensure newly-copied files are tracked before commit. sl commit <path> silently
    # skips untracked files (? in sl status), causing 'no match under directory' aborts
    # when ALL changes happen to be new files. This was a recurring failure mode
    # (3 hits 2026-05-18: 06:15, 12:42, 13:38 PT) before this fix.
    # See ot-cron-health-watch thread `8Nzx9nUrsOI` + operator directive in
    # thread `8Nzx9nUrsOI` 2026-05-18.
    sl add "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>/dev/null || true
    if ! sl commit -m "$COMMIT_MSG" "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>&1 >&2; then
        echo "[ERROR] sl commit failed" >&2
        exit 1
    fi
fi

NEW_HASH=$(sl log -r . -T '{node|short}' 2>/dev/null)
echo >&2
echo "COMMIT_HASH=$NEW_HASH"
echo "[notes-to-fbcode-sync] done. $SYNC_COUNT file(s) synced. Commit: $NEW_HASH" >&2
