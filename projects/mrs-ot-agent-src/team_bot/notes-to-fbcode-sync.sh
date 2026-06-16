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
        # Accepted no-op: this script NEVER submits (commit/amend only); the
        # ot-notes-fbcode-commit cron passes --no-submit for clarity. Rejecting
        # it (old behavior) made the commit cron's script call exit 1 every run
        # → it then created a NEW commit each run instead of amending the weekly
        # one → duplicate sync diffs (2026-06-04 root cause, thread aenMMohDz0c).
        --no-submit) ;;
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
        # New-commit mode: working copy must be clean — OR every dirty file must
        # be content-identical to notes (in which case auto-revert: the change
        # is already preserved in notes, fbcode write was a stray duplicate).
        DIRTY_LIST=$(sl status "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>/dev/null | grep -E '^[MA]' | awk '{print $2}')
        if [ -n "$DIRTY_LIST" ]; then
            DIVERGENT_LIST=""
            IDENTICAL_LIST=""
            while IFS= read -r fbcode_path; do
                [ -z "$fbcode_path" ] && continue
                rel="${fbcode_path#fbcode/pe_mrs_ml/mrs_ot_agent/}"
                # Reverse .dot → .dot.txt mapping for notes lookup
                notes_rel="$rel"
                if [ "$rel" = "team_bot/architecture.dot" ]; then
                    notes_rel="team_bot/architecture.dot.txt"
                fi
                notes_src="$NOTES_SRC/$notes_rel"
                fbcode_abs="$HOME/fbsource/$fbcode_path"
                is_identical=0
                if [ -f "$notes_src" ]; then
                    if cmp -s "$notes_src" "$fbcode_abs"; then
                        is_identical=1
                    elif cmp -s <(awk 'BEGIN{ORS=""} {if(NR>1)print "\n"; print}' "$notes_src") \
                               <(awk 'BEGIN{ORS=""} {if(NR>1)print "\n"; print}' "$fbcode_abs"); then
                        # Tier-2 newline-normalized fallback: tolerate trailing-newline-only
                        # drift (heartbeat double-write / editor sentinel diff).
                        is_identical=1
                    elif [ "${fbcode_path##*.}" = "py" ] && python3 -c '
import sys, re, collections
def rt(p):
    s = open(p, encoding="utf-8", errors="replace").read()
    return collections.Counter(t for t in re.findall(r"[A-Za-z_]\w*|\d[\d.]*", s) if t not in ("import", "from"))
n = rt(sys.argv[1]); f = rt(sys.argv[2])
sys.exit(1 if any(f[t] > n[t] for t in f) else 0)
' "$notes_src" "$fbcode_abs" 2>/dev/null; then
                        # Tier-3 (.py only): fbcode has NO real-token (identifier/number)
                        # content beyond notes — the diff is pure `arc f`/Black reformat
                        # (line-wrap, import-split, quote-normalize, reorder) and/or notes
                        # is ahead of fbcode. No fbcode-unique logic → safe auto-revert
                        # (notes is SoT; the mirror copy re-applies notes anyway). Aborts
                        # only on genuine fbcode-only content. Closes the recurring arc-f-
                        # reformat sync abort (2026-06-10: 6 tools/*.py blocked the mirror).
                        is_identical=1
                    fi
                fi
                if [ "$is_identical" -eq 1 ]; then
                    IDENTICAL_LIST="${IDENTICAL_LIST}${fbcode_path}\n"
                else
                    DIVERGENT_LIST="${DIVERGENT_LIST}${fbcode_path}\n"
                fi
            done <<< "$DIRTY_LIST"

            if [ -n "$DIVERGENT_LIST" ]; then
                echo "ERROR: fbcode/pe_mrs_ml/mrs_ot_agent/ has uncommitted modifications that DIVERGE from notes (manual review required):" >&2
                printf "%b" "$DIVERGENT_LIST" >&2
                if [ -n "$IDENTICAL_LIST" ]; then
                    echo "(Note: also had identical-to-notes dirty files which would have auto-reverted:)" >&2
                    printf "%b" "$IDENTICAL_LIST" >&2
                fi
                echo "Resolve (notes is GROUND TRUTH; never cp/patch fbcode->notes, it clobbers notes-only content): (a) for each file, diff fbcode vs notes, MERGE only the fbcode-only real-new lines INTO notes (preserve notes-only lines), then run again; or (b) sl revert if the divergent fbcode write was a mistake. If unsure which fbcode-only content is real, escalate to operator with BOTH sides' line lists." >&2
                exit 1
            fi

            # All dirty files are content-identical to notes — auto-revert.
            echo "[notes-to-fbcode-sync] auto-recovery: $(printf "%b" "$IDENTICAL_LIST" | grep -c .) dirty file(s) match notes exactly; reverting (notes is SoT, content already preserved):" >&2
            printf "%b" "$IDENTICAL_LIST" >&2
            while IFS= read -r fbcode_path; do
                [ -z "$fbcode_path" ] && continue
                if ! sl revert --reason "intent - auto-revert; sync precondition recovery; content identical to notes (SoT)" "$fbcode_path" 2>&1 >&2; then
                    echo "ERROR: sl revert failed on $fbcode_path. Aborting." >&2
                    exit 1
                fi
            done <<< "$(printf "%b" "$IDENTICAL_LIST")"
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

    # Skip runtime state + sqlite caches: they mutate every cron tick, so
    # mirroring them produces PERPETUAL false drift (and blocks the gate). The
    # mirror's stated scope is doc/prompt only. (2026-06-04: root cause of the
    # 31-draft sync pileup — state/*.json + crons.db churn faked drift forever.)
    [[ "$rel" == state/* ]] && continue
    [[ "$rel" == *.db ]] && continue

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
    # See ot-cron-health-guard thread `8Nzx9nUrsOI` + operator directive in
    # thread `8Nzx9nUrsOI` 2026-05-18.
    sl add "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>/dev/null || true
    # Pre-format with arc f BEFORE the guard. sl commit runs arc f internally, so if
    # notes has compact-style Python that arc f expands to match committed fbcode, the
    # commit aborts with "no match under directory" (confirmed 2026-06-08: all 7 tool
    # files were semantically identical but Black-format-different; arc f inside sl commit
    # normalized them back to committed state). Running arc f explicitly here lets the
    # guard see the post-formatting state and skip cleanly on style-only differences.
    # BUG FIX (2026-06-08): `arc f <directory>` returns "No linters to run" — it only
    # works with individual file paths. Use find to format each .py file.
    find "fbcode/pe_mrs_ml/mrs_ot_agent/" -name "*.py" -type f -print0 2>/dev/null \
        | xargs -0 arc f 2>/dev/null || true
    # Guard against the no-op false-failure: when the copied files are byte-identical
    # to fbcode (no net change — the common case once things are in sync), there is
    # nothing to commit, and `sl commit <path>` aborts "no match under directory". The
    # old code treated that BENIGN no-op as a hard exit-1 FAILURE → recurring false cron
    # failures (e.g. 2026-06-07 06:15, and the manual --no-submit run). Only commit when
    # the path actually has staged/modified changes; otherwise skip cleanly.
    if [ -z "$(sl status "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>/dev/null | grep -E '^[MARC]')" ]; then
        echo "[notes-to-fbcode-sync] no net changes under the path (fbcode already in sync after arc f normalization); skipping commit." >&2
    elif ! sl commit -m "$COMMIT_MSG" "fbcode/pe_mrs_ml/mrs_ot_agent/" 2>&1 >&2; then
        echo "[ERROR] sl commit failed" >&2
        exit 1
    fi
fi

NEW_HASH=$(sl log -r . -T '{node|short}' 2>/dev/null)
echo >&2
echo "COMMIT_HASH=$NEW_HASH"
echo "[notes-to-fbcode-sync] done. $SYNC_COUNT file(s) synced. Commit: $NEW_HASH" >&2
