#!/usr/bin/env bash
# cron-drafts-push.sh — Push today's coach output to the routine gdoc tab `ai_coach`.
# Mobile-checkable surface. SCANNABILITY > completeness.
#
# CONSUMES:
#   ~/work/claude/projects/ai-coach-private/drafts/<date>-*.md       (coach ghost-writer DMs)
#   ~/work/claude/projects/ai-coach-private/drafts/posts/<date>-*.md (content factory posts)
#   ~/work/claude/projects/ai-coach-private/digests/LATEST.md        (to identify ★ priority)
#
# PUBLISHES (REPLACE semantics — tab always shows TODAY):
#   Daily Routine gdoc tab `ai_coach` (t.xspqkt7mm460) — DRAFTS ONLY
#   https://docs.google.com/document/d/102gEn1Ek4PyefvrOuSNBPNZghsus-rJ9LGbnhtO_vvY/edit?tab=t.xspqkt7mm460
#
# NOTE: Power-coach output lives in the SEPARATE tab `power_coach` (t.ggpze93ief26), published
# by cron-power-coach.sh itself (one cron, one tab — Denny 2026-06-17). This script only
# handles drafts.
#
# Layout (Denny 2026-06-17 feedback — scannable, dense, priorities marked):
#   1. ONE-LINE STATUS at top: N drafts (★N to ship today)
#   2. ★ PRIORITY DRAFTS first (the 🎯 one-move slug from coach digest), then the rest
#   3. Each draft: 1-line meta header (send-to · edit cost · purpose) + the artifact body
#      (preamble/why-this stripped — that's coaching not paste-ready content)
#
# Schedule: daily 08:10 PT (after coach 08:00, before brief 08:23).

set -eo pipefail

REPO_DIR="$HOME/work/claude"
PROJ_DIR="$REPO_DIR/projects/ai-coach-private"
DRAFTS_COACH="$PROJ_DIR/drafts"
DRAFTS_POSTS="$PROJ_DIR/drafts/posts"
DIGEST="$PROJ_DIR/digests/LATEST.md"
TODAY="$(date '+%Y-%m-%d')"
DOC_ID="102gEn1Ek4PyefvrOuSNBPNZghsus-rJ9LGbnhtO_vvY"
TAB_ID="t.xspqkt7mm460"
HISTORY_DIR="$REPO_DIR/projects/ai-coach-private/state/coach-drafts-history"
mkdir -p "$HISTORY_DIR"

# shellcheck disable=SC1091
source "$REPO_DIR/scripts/cron-alert.sh"

cron_log "drafts-push (today=$TODAY)"

# Identify the ★ priority draft slug = the one named in the digest's "## 🎯 The one move"
# section as `drafts/<slug>.md`. Fallback to first coach draft if digest reference is stale.
PRIORITY_SLUG=""
if [ -f "$DIGEST" ]; then
    PRIORITY_SLUG=$(grep -oE 'drafts/[0-9-]+-[a-z0-9-]+\.md' "$DIGEST" 2>/dev/null | head -1 | xargs -I{} basename {} .md 2>/dev/null || echo "")
fi

# Collect drafts — exclude `_no-candidates` placeholders (treated as zero, not 1)
coach_files=()
for f in "$DRAFTS_COACH/${TODAY}"-*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [[ "$base" == *"_no-candidates"* ]] && continue
    coach_files+=("$f")
done
post_files=()
for f in "$DRAFTS_POSTS/${TODAY}"-*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [[ "$base" == *"_no-candidates"* ]] && continue
    post_files+=("$f")
done
n_coach=${#coach_files[@]}
n_posts=${#post_files[@]}

# Priority-marker fallback: if digest's named priority isn't in today's files, mark the first
# coach draft (or first post if no coach drafts). Any draft beats no marker.
if [ -n "$PRIORITY_SLUG" ]; then
    priority_exists=0
    for f in "${coach_files[@]}" "${post_files[@]}"; do
        [ "$(basename "$f" .md)" = "$PRIORITY_SLUG" ] && { priority_exists=1; break; }
    done
    if [ "$priority_exists" = 0 ]; then
        if [ $n_coach -gt 0 ]; then
            PRIORITY_SLUG=$(basename "${coach_files[0]}" .md)
        elif [ $n_posts -gt 0 ]; then
            PRIORITY_SLUG=$(basename "${post_files[0]}" .md)
        else
            PRIORITY_SLUG=""
        fi
    fi
fi
n_priority=$([ -n "$PRIORITY_SLUG" ] && echo 1 || echo 0)

# Extract KEY MESSAGE from coach digest's 🎯 one move line (the must-ship-today action).
# This is what daily brief reads verbatim into the ✎ drafts line.
KEY_MESSAGE=""
if [ -f "$DIGEST" ]; then
    # Find "## 🎯 The one move" heading, take the next non-empty content line, strip trailing
    # link bracket if present (e.g. " — drafted: [slug](path)").
    KEY_MESSAGE=$(awk '
        /^## 🎯/ { found=1; next }
        found && /^## / { exit }
        found && /^[^[:space:]]/ { print; exit }
    ' "$DIGEST" 2>/dev/null | sed -E 's/[[:space:]]*\[h1-self-study\].*$//; s/[[:space:]]+$//' | head -c 300)
fi
[ -z "$KEY_MESSAGE" ] && KEY_MESSAGE="_No 🎯 one move from coach digest yet — see drafts below._"

# Extract one-line meta from each draft. Wrap grep in `|| true` so a missing pattern doesn't
# trigger pipefail (some drafts use plain `Send to:` line, not blockquote, and the H1 doc
# skeleton has no Send-to at all).
extract_sendto() {
    { grep -m1 -iE '^(>\s*\*\*Send to:?\*\*|Send to:?)' "$1" 2>/dev/null || true; } \
        | sed -E 's/^>\s*\*\*Send to:?\*\*//I; s/^Send to:?//I; s/^[[:space:]]*//' | head -1
}
extract_purpose() {
    { grep -m1 -iE '^>\s*\*\*(Why this draft|Why this framing|Purpose):?\*\*' "$1" 2>/dev/null || true; } \
        | sed -E 's/^>\s*\*\*[^*]*:?\*\*//I; s/^[[:space:]]*//' | head -1
}
extract_edit_estimate() {
    { grep -m1 -iE '^>\s*\*\*Edit estimate:?\*\*' "$1" 2>/dev/null || true; } \
        | sed -E 's/^>\s*\*\*Edit estimate:?\*\*//I; s/^[[:space:]]*//' | head -1
}

# Strip the blockquote preamble from a draft body so we paste just the artifact.
# Then demote draft-internal headings (per gdocs cheatsheet: H1 inside doc body competes with
# tab title; nest under the per-draft H3 slug). H1->H4, H2->H5, H3 stays as H4 to keep
# subordination. Drop --- horizontal rules (gdocs renders them as text clutter).
strip_preamble() {
    awk '
        /^[[:space:]]*$/ && !started { next }
        /^>/ && !started { next }
        /^---[[:space:]]*$/ && !started { next }
        /^#/ { started=1 }
        started { print }
    ' "$1" | sed -E \
        -e 's/^# /#### /' \
        -e 's/^## /##### /' \
        -e 's/^### /##### /' \
        -e '/^---[[:space:]]*$/d'
}

# Format a single draft block
emit_draft() {
    local file=$1
    local kind=$2  # "coach" | "post"
    local slug
    slug=$(basename "$file" .md)
    local marker=""
    if [ "$slug" = "$PRIORITY_SLUG" ]; then
        marker="★ "
    fi
    local sendto purpose est
    sendto=$(extract_sendto "$file")
    purpose=$(extract_purpose "$file")
    est=$(extract_edit_estimate "$file")

    echo
    echo "### ${marker}\`$slug\` <a id=\"$slug\"></a>"
    # Dense one-liner meta — pipe-separated, no blockquote.
    local meta=""
    [ -n "$sendto" ] && meta="**→** $sendto"
    [ -n "$est" ] && meta="$meta  **·** ⏱ $est"
    [ -n "$purpose" ] && meta="$meta  **·** $purpose"
    [ -n "$meta" ] && echo "$meta" && echo
    # Body — preamble stripped
    strip_preamble "$file"
    echo
}

# Build the output
TMP=$(mktemp).md
trap 'rm -f "$TMP"' EXIT

{
    # ── STATUS HEADER (no top H1 — tab title serves that role; per gdocs cheatsheet)
    echo "_**$TODAY** · rolling 7 days · auto-pushed daily after 08:00 coach run · Influence-coach output → \`1 Coach Influence\` tab._"
    echo
    # ── 🌟 KEY MESSAGE (surfaces verbatim in daily brief's ✎ drafts line) ───────
    echo "## 🌟 KEY MESSAGE — surface this in daily brief"
    echo
    echo "$KEY_MESSAGE"
    echo
    echo "**Status:** $n_coach coach draft$([ $n_coach -ne 1 ] && echo s), $n_posts post draft$([ $n_posts -ne 1 ] && echo s)$([ $n_priority -eq 1 ] && echo " · ★ 1 to ship today") · **Published:** $(date '+%H:%M %Z')"
    echo
    # ── QUICK JUMP INDEX ───────────────────────────────────────────────────────
    if [ $n_coach -gt 0 ] || [ $n_posts -gt 0 ]; then
        echo "**Jump:**"
        for f in "${coach_files[@]}"; do
            slug=$(basename "$f" .md)
            [ "$slug" = "$PRIORITY_SLUG" ] && echo "- ★ [$slug](#$slug) — ship today" || echo "- [$slug](#$slug)"
        done
        for f in "${post_files[@]}"; do
            slug=$(basename "$f" .md)
            echo "- [$slug](#$slug)"
        done
        echo
    fi

    # ── PRIORITY DRAFT FIRST (the ★ one) ───────────────────────────────────────
    if [ -n "$PRIORITY_SLUG" ]; then
        for f in "${coach_files[@]}" "${post_files[@]}"; do
            if [ "$(basename "$f" .md)" = "$PRIORITY_SLUG" ]; then
                emit_draft "$f" "coach"
                break
            fi
        done
    fi

    # ── OTHER COACH DRAFTS ─────────────────────────────────────────────────────
    for f in "${coach_files[@]}"; do
        slug=$(basename "$f" .md)
        [ "$slug" = "$PRIORITY_SLUG" ] && continue
        emit_draft "$f" "coach"
    done

    # ── POST DRAFTS ────────────────────────────────────────────────────────────
    if [ ${#post_files[@]} -gt 0 ]; then
        echo "---"
        echo
        echo "## 📤 Workplace post drafts"
        echo
        for f in "${post_files[@]}"; do
            slug=$(basename "$f" .md)
            [ "$slug" = "$PRIORITY_SLUG" ] && continue
            emit_draft "$f" "post"
        done
    fi

    # ── EMPTY-DAY FALLBACK ─────────────────────────────────────────────────────
    if [ $n_coach -eq 0 ] && [ $n_posts -eq 0 ]; then
        echo
        echo "_Quiet day — no drafts. Coach + content-factory produced nothing artifact-shaped._"
        echo "_Influence-coach output (if any) is in the \`Coach Influence\` tab._"
    fi

    # Rolling history REMOVED from active tab (Denny 2026-06-19: active stays thin).
    # Prior days' summaries now live in [Arc] Coach Drafts tab. See archive step below.
} > "$TMP"

# ── ARCHIVE STEP (active tab stays thin; prior day's content → [Arc] Coach Drafts) ────────
ARCHIVE_TAB_ID="t.xaamxsimx98t"
ARCHIVE_TMP=$(mktemp).md
prior_content=$(gdocs get "$DOC_ID" --tab-id "$TAB_ID" --markdown 2>/dev/null || true)
existing_archive=$(gdocs get "$DOC_ID" --tab-id "$ARCHIVE_TAB_ID" --markdown 2>/dev/null || true)
{
    echo "_**[Arc] Coach Drafts** — newest at top. Each entry = one daily drafts-push snapshot._"
    echo
    if [ -n "$prior_content" ]; then
        echo "## ${TODAY} — prior day snapshot (preserved before today's push)"
        echo
        echo "$prior_content"
        echo
    fi
    echo "$existing_archive" | awk '/^## /{found=1} found {print}'
} > "$ARCHIVE_TMP"
bash "$REPO_DIR/scripts/gdocs-safe-replace.sh" \
    "$DOC_ID" --tab-id "$ARCHIVE_TAB_ID" --from "$ARCHIVE_TMP" --full-replace-removes-comments \
    >> ~/logs/drafts-push.log 2>&1 \
    && cron_log "  archived prior content to [Arc] Coach Drafts" \
    || cron_log "  ⚠️  archive write failed (continuing — active push still attempted)"
rm -f "$ARCHIVE_TMP"

# ── Write today's slug-summary to history (consumed by tomorrow's rolling section) ──
# Compact form: ★ for priority, slug list per kind. Bodies stay in drafts/ folder only.
{
    [ $n_coach -gt 0 ] && {
        for f in "${coach_files[@]}"; do
            slug=$(basename "$f" .md)
            marker=$([ "$slug" = "$PRIORITY_SLUG" ] && echo "★ " || echo "- ")
            echo "${marker}\`coach/${slug}\`"
        done
    }
    [ $n_posts -gt 0 ] && {
        for f in "${post_files[@]}"; do
            slug=$(basename "$f" .md)
            marker=$([ "$slug" = "$PRIORITY_SLUG" ] && echo "★ " || echo "- ")
            echo "${marker}\`posts/${slug}\`"
        done
    }
    [ $n_coach -eq 0 ] && [ $n_posts -eq 0 ] && echo "_(quiet day — no drafts)_"
} > "$HISTORY_DIR/${TODAY}.md"

# GC: prune history files older than 14 days (keep a small buffer beyond the 7-day display window)
find "$HISTORY_DIR" -name '2*-*-*.md' -mtime +14 -delete 2>/dev/null || true

lines_total=$(wc -l < "$TMP")
cron_log "  prepared $lines_total lines (priority=${PRIORITY_SLUG:-none})"

# ── PREPEND-AND-TRIM (was full-replace; Denny 2026-06-22 comments on _2026-06-22
# and 2026-06-21 anchors — wiping daily orphaned his anchored comments).
# Active tab now keeps today + 6 prior day-blocks (KEEP_N=7); older still archived
# above to [Arc] Coach Drafts. Bumped 3→7 on 2026-06-24 after Denny re-pinged
# orphaned 06-21 anchors that aged out under the 3-day window — a week aligns
# with his actual review cadence. Today's block wrapped under H1 `_<DATE>` so
# the trim script (same prepend-and-trim shape as cron-routine-aggregator.sh)
# can split blocks deterministically.
KEEP_N="${DRAFTS_KEEP_N:-7}"
prior_active=$(gdocs get "$DOC_ID" --tab-id "$TAB_ID" --markdown 2>/dev/null || true)
COMBINED=$(mktemp).md
{
    echo "# _${TODAY}"
    echo
    cat "$TMP"
    echo
    if [ -n "$prior_active" ]; then
        # Drop today's own stale block if same-day re-run (idempotent), then
        # keep last (KEEP_N-1) prior day-blocks. Day-block delimiter is H1
        # `# _YYYY-MM-DD` from prior pushes; legacy content without that header
        # is treated as a single block.
        echo "$prior_active" | awk -v today="_${TODAY}" -v keep=$((KEEP_N-1)) '
            /^# _[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
                date=substr($2,2)
                if (date == substr(today,2)) { skip=1; n=0; next }
                skip=0; n++
                if (n > keep) exit
            }
            !skip { print }
        '
    fi
} > "$COMBINED"

bash "$REPO_DIR/scripts/gdocs-safe-replace.sh" \
    "$DOC_ID" --tab-id "$TAB_ID" --from "$COMBINED" --full-replace-removes-comments \
    >> ~/logs/drafts-push.log 2>&1 || {
    cron_alert "drafts-push" "gdocs-safe-replace failed — see ~/logs/drafts-push.log"
    rm -f "$COMBINED"
    exit 1
}
rm -f "$COMBINED"

# Cheatsheet QA pass — per cheatsheets/gdocs/rules.md meta-rule (verify post-replace).
# After 2026-06-22 switch to prepend-and-trim, day-block H1s `# _YYYY-MM-DD` are
# INTENTIONAL delimiters. Expect KEEP_N=7 H1s; warn only if outside [1, KEEP_N+1].
top_h1_count=$(meta google.docs structure --id "$DOC_ID" --tab-id "$TAB_ID" --no-truncate 2>/dev/null \
    | awk '/HEADING/ && /H1/ {print}' | wc -l)
if [ "$top_h1_count" -lt 1 ] || [ "$top_h1_count" -gt $((KEEP_N+1)) ]; then
    cron_log "  ⚠️  QA: $top_h1_count H1 heading(s) in tab body — expected 1..$((KEEP_N+1)) day-block H1s."
fi
cron_log "  QA: structural check done (h1=$top_h1_count, target=1..$((KEEP_N+1)))"

cron_log "drafts-push done (tab: 5 Coach Drafts)"
cron_alert_clear "drafts-push"
write_heartbeat "drafts-push"
