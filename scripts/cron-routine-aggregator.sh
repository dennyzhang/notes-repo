#!/usr/bin/env bash
# cron-routine-aggregator.sh — Pure-script aggregator: read each routine-doc tab's
# 🌟 KEY MESSAGE (or 🔑 Key msgs for Diff Review), distill, write to `0 [Agg] Routine` tab.
#
# WHY (Denny 2026-06-19): brief was reading 5+ tabs every morning — slow + duplicated work.
# This cron pre-distills so the brief reads ONE source-of-truth tab. Same architectural pattern
# as journal→consumers: many producers, one aggregation surface.
#
# CONSUMES (all in routine gdoc 102gEn1Ek4PyefvrOuSNBPNZghsus-rJ9LGbnhtO_vvY):
#   - `1 Coach Influence` (t.ggpze93ief26)  — 🌟 KEY MESSAGE section
#   - `2 Org Monitor`     (t.7p1pm5er8oet)  — 🌟 KEY MESSAGE section
#   - `3 AI Skill Monitor`(t.n3cgnazi5bxp)  — 🌟 KEY MESSAGE section
#   - `  Infra Reliability`(t.aqi2ky6jh9u4) — 🌟 KEY MESSAGE section (miner runs Mon + Thu)
#   - `4 Diff Review`     (t.3ikgn7q1biwc)  — 🔑 Key msgs section (top critical findings)
#   - `5 Coach Drafts`    (t.xspqkt7mm460)  — 🌟 KEY MESSAGE section
#
# PUBLISHES to:
#   `0 [Agg] Routine` tab (t.8z9ivhphd8p7) — mobile-checkable single surface for the brief
#
# Schedule: daily 08:15 PT — runs AFTER all sources are populated:
#   07:30 collaborator-map · 07:45 power-coach (Tue/Fri) · 07:50 analog-matcher
#   08:00 ai-coach · 08:10 drafts-push · 08:15 THIS · 08:23 daily-brief
#
# Crontab (registered in private_scripts/setup-claude.sh):
#   15 8 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 180 routine-aggregator \
#     ~/work/claude/scripts/cron-routine-aggregator.sh >> ~/logs/routine-aggregator.log 2>&1

set -eo pipefail

REPO_DIR="$HOME/work/claude"
TODAY="$(date '+%Y-%m-%d')"
DOC_ID="102gEn1Ek4PyefvrOuSNBPNZghsus-rJ9LGbnhtO_vvY"
AGG_TAB_ID="t.8z9ivhphd8p7"

# shellcheck disable=SC1091
source "$REPO_DIR/scripts/cron-alert.sh"

cron_log "routine-aggregator (today=$TODAY)"

# Extract the first non-empty content line following a heading marker from a tab.
# Args: <doc_id> <tab_id> <heading_regex>
extract_key_msg() {
    local doc=$1 tab=$2 marker=$3
    gdocs get "$doc" --tab-id "$tab" --markdown 2>/dev/null | awk -v marker="$marker" '
        $0 ~ marker { found=1; next }
        found && /^#/ { exit }
        found && /^[^[:space:]]/ {
            # Strip leading bold markers; emit the first ≤300 chars.
            sub(/^\*+/, "")
            sub(/\*+$/, "")
            print
            exit
        }
    ' | head -c 400
}

# Extract multiple bullet lines from a "🔑 Key msgs" block (Diff Review pattern).
extract_key_msgs_block() {
    local doc=$1 tab=$2
    gdocs get "$doc" --tab-id "$tab" --markdown 2>/dev/null | awk '
        /🔑 Key msgs/ { found=1; next }
        found && /^#/ { exit }
        found && /^[-*]/ { print; n++; if (n>=3) exit }
    '
}

cron_log "  reading 6 source tabs..."
COACH_INFLUENCE=$(extract_key_msg "$DOC_ID" "t.ggpze93ief26" "🌟 KEY MESSAGE" || true)
ORG_MONITOR=$(extract_key_msg "$DOC_ID" "t.7p1pm5er8oet" "🌟 KEY MESSAGE" || true)
AI_SKILL=$(extract_key_msg "$DOC_ID" "t.n3cgnazi5bxp" "🌟 KEY MESSAGE" || true)
COACH_DRAFTS=$(extract_key_msg "$DOC_ID" "t.xspqkt7mm460" "🌟 KEY MESSAGE" || true)
INFRA_RELIABILITY=$(extract_key_msg "$DOC_ID" "t.aqi2ky6jh9u4" "🌟 KEY MESSAGE" || true)
DIFF_REVIEW=$(extract_key_msgs_block "$DOC_ID" "t.3ikgn7q1biwc" || true)

# Fallback for empty sections — emit a clear "no signal today" marker.
[ -z "$COACH_INFLUENCE" ]   && COACH_INFLUENCE="_No KEY MESSAGE from Coach Influence today._"
[ -z "$ORG_MONITOR" ]       && ORG_MONITOR="_No KEY MESSAGE from Org Monitor today._"
[ -z "$AI_SKILL" ]          && AI_SKILL="_No KEY MESSAGE from AI Skill Monitor today._"
[ -z "$COACH_DRAFTS" ]      && COACH_DRAFTS="_No KEY MESSAGE from Coach Drafts today._"
[ -z "$INFRA_RELIABILITY" ] && INFRA_RELIABILITY="_No KEY MESSAGE from Infra Reliability today (miner runs Mon + Thu 09:17)._"
[ -z "$DIFF_REVIEW" ]       && DIFF_REVIEW="_No 🔑 Key msgs from Diff Review today._"

TMP=$(mktemp).md
EXPORT="$(mktemp).md"
COMBINED="$(mktemp).md"
FOOTER="$(mktemp).md"
trap 'rm -f "$TMP" "$EXPORT" "$COMBINED" "$FOOTER"' EXIT

{
    echo "_auto-aggregated $(date '+%H:%M %Z') from all routine-doc tabs · read by daily-brief 08:23 — drill into source tabs for full context._"
    echo
    echo "## 🚨 Today's top items (brief surfaces these)"
    echo
    echo "**⚔️ Coach Influence** · [tab](https://docs.google.com/document/d/${DOC_ID}/edit?tab=t.ggpze93ief26)"
    echo
    echo "$COACH_INFLUENCE"
    echo
    echo "**✎ Coach Drafts** · [tab](https://docs.google.com/document/d/${DOC_ID}/edit?tab=t.xspqkt7mm460)"
    echo
    echo "$COACH_DRAFTS"
    echo
    echo "**📡 Org Monitor** · [tab](https://docs.google.com/document/d/${DOC_ID}/edit?tab=t.7p1pm5er8oet)"
    echo
    echo "$ORG_MONITOR"
    echo
    echo "**🛠 AI Skill Monitor** · [tab](https://docs.google.com/document/d/${DOC_ID}/edit?tab=t.n3cgnazi5bxp)"
    echo
    echo "$AI_SKILL"
    echo
    echo "**🛡 Infra Reliability** · [tab](https://docs.google.com/document/d/${DOC_ID}/edit?tab=t.aqi2ky6jh9u4)"
    echo
    echo "$INFRA_RELIABILITY"
    echo
    echo "**🐛 Diff Review** · [tab](https://docs.google.com/document/d/${DOC_ID}/edit?tab=t.3ikgn7q1biwc)"
    echo
    echo "$DIFF_REVIEW"
    echo
} > "$TMP"

# Footer (How this works) — written once per push at the bottom, AFTER all retained
# day-blocks. Not part of $TMP / not part of any day-block; kept out of trim scope.
{
    echo "---"
    echo
    echo "## ⚙️ How this works"
    echo
    echo "Cron \`cron-routine-aggregator.sh\` runs daily 08:15 PT. Reads \`🌟 KEY MESSAGE\` from each routine-doc tab + \`🔑 Key msgs\` from Diff Review, prepends as a new day-block here (keeps last 5 days). Daily brief (08:23) reads only this tab. Schedule: 08:00 ai-coach → 08:10 drafts-push → 08:15 THIS → 08:23 brief."
} > "$FOOTER"

cron_log "  prepared $(wc -l < "$TMP") lines"

# ──────────────────────────────────────────────────────────────────────────────
# PREPEND-AND-TRIM (Denny review 2026-06-21 — was full-replace, wiped history):
#   1. Export existing tab content (markdown).
#   2. Split by H1 day header (`# YYYY-MM-DD`) — keep last 4 day-blocks.
#   3. Wrap today's TMP with `# $TODAY` header, prepend to retained history.
#   4. Push combined doc via gdocs-safe-replace (still safe — agg tab carries no
#      user comments by design; only the routine tab does).
# ──────────────────────────────────────────────────────────────────────────────
RETAIN_DAYS=4   # keep prior 4 days + today = 5 total day-blocks

if gdocs get "$DOC_ID" --tab-id "$AGG_TAB_ID" --markdown > "$EXPORT" 2>/dev/null; then
    cron_log "  exported existing tab ($(wc -l < "$EXPORT") lines) — trimming to last ${RETAIN_DAYS} day-blocks"
else
    : > "$EXPORT"
    cron_log "  no existing tab content — first-time write"
fi

{
    echo "# $TODAY"
    echo
    cat "$TMP"
    echo
    # Keep only prior day-blocks (H1 date headers). Skip today's date if the prior
    # run already wrote one (idempotency on same-day re-runs). Strip the trailing
    # footer ("## ⚙️ How this works") from the last block before emitting.
    python3 - "$EXPORT" "$RETAIN_DAYS" "$TODAY" <<'PYEOF'
import re, sys
path, retain, today = sys.argv[1], int(sys.argv[2]), sys.argv[3]
try:
    content = open(path).read()
except FileNotFoundError:
    sys.exit(0)
parts = re.split(r'(?m)^(?=# \d{4}-\d{2}-\d{2}\s*$)', content)
day_blocks = []
for p in parts:
    m = re.match(r'^# (\d{4}-\d{2}-\d{2})', p.strip())
    if not m:
        continue
    if m.group(1) == today:
        continue   # we are re-writing today's block; drop the stale one
    # Strip footer ("---" then "## ⚙️ How this works ...") if attached to this block.
    block = re.sub(r'(?ms)\n---\s*\n+## ⚙️ How this works.*$', '', p)
    day_blocks.append(block)
for blk in day_blocks[:retain]:
    sys.stdout.write(blk.rstrip() + "\n\n")
PYEOF
    # Always append the single footer at the very bottom of the doc.
    cat "$FOOTER"
} > "$COMBINED"

cron_log "  combined doc: $(wc -l < "$COMBINED") lines (today + up to ${RETAIN_DAYS} prior days)"

bash "$REPO_DIR/scripts/gdocs-safe-replace.sh" \
    "$DOC_ID" --tab-id "$AGG_TAB_ID" --from "$COMBINED" --full-replace-removes-comments \
    >> ~/logs/routine-aggregator.log 2>&1 || {
    cron_alert "routine-aggregator" "gdocs-safe-replace failed — see ~/logs/routine-aggregator.log"
    exit 1
}

cron_log "routine-aggregator done (tab: 0 [Agg] Routine, prepend+trim mode)"
cron_alert_clear "routine-aggregator"
write_heartbeat "routine-aggregator"
