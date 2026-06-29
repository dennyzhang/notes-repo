#!/bin/bash
# cron-token-usage-alert.sh — tiered token-cost signals feeding agent auto-optimization.
#
# Goal (per chat thread 2026-06-17 w/ Gaurav): generate EARLY signals well before any hard
# limit (the "speeding ticket"), so the agent can SELF-OPTIMIZE rather than wait for
# DevInfra enforcement. Soft tier writes to SIGNALS.md (agent-readable, no noise);
# hard tier escalates to ALERTS.md (P0 mailbox).
#
# Data source: `meta ai.usage summary -o json` (aggregated authoritative endpoint).
# Underlying Scuba table [infrastructure].claude_code_metrics requires PDR/AIR;
# the `meta ai.usage summary` wrapper exposes daily+policy data with no ACL.
# Mirrors https://www.internalfb.com/dev-insights/ai-usage-stats?metric=token_cost
#
# Tiered signals (calibrated to observed distribution: avg ~$1950, l7 peak ~$3174):
#   SOFT  ($2500): write to SIGNALS.md — agent reads at session start, can self-correct
#   WARN  ($3500): write to SIGNALS.md + PENDING-BRIEF.md (daily-brief picks it up at 08:23)
#   HARD  ($5000): write to ALERTS.md + PENDING-BRIEF.md (speeding ticket — P0 mailbox)
#
# Escalation flow: signals fire → agent self-corrects at session start OR daily-brief surfaces
# unresolved WARN/HARD to Denny via GChat. PENDING-BRIEF.md is archived by daily-brief after read.
# Plus trend conditions:
#   DoD jump >DELTA_PCT_THRESHOLD (30%) — soft signal
#   WoW jump >WOW_PCT_THRESHOLD (50%)   — soft signal (from l7_percent_change)
#   Any policy >=POLICY_PCT_THRESHOLD (80%) — hard alert (close to a real cap)
#
# Signals carry tool_breakdown + suggested action so the agent has something to act on.
# Per-condition sentinels prevent re-firing within a day (running every 2h).
#
# Crontab: every 2h, 9am-11pm PT. State at ~/work/claude/state/token-usage/.

set -uo pipefail

source "$(dirname "$0")/cron-alert.sh"

# Tunable thresholds (override via env)
SOFT_COST_THRESHOLD="${SOFT_COST_THRESHOLD:-2500}"
WARN_COST_THRESHOLD="${WARN_COST_THRESHOLD:-3500}"
HARD_COST_THRESHOLD="${HARD_COST_THRESHOLD:-5000}"
DELTA_PCT_THRESHOLD="${DELTA_PCT_THRESHOLD:-30}"
WOW_PCT_THRESHOLD="${WOW_PCT_THRESHOLD:-50}"
POLICY_PCT_THRESHOLD="${POLICY_PCT_THRESHOLD:-80}"

STATE_DIR="$CLAUDE_STATE_DIR/token-usage"
HISTORY_FILE="$STATE_DIR/history.jsonl"
SIGNALS_FILE="$STATE_DIR/SIGNALS.md"
PENDING_BRIEF_FILE="$STATE_DIR/PENDING-BRIEF.md"
SENTINEL_DIR="$STATE_DIR/sentinels"
mkdir -p "$STATE_DIR" "$SENTINEL_DIR"

TODAY="$(date +%Y-%m-%d)"
NOW="$(date '+%Y-%m-%d %H:%M')"

cron_log "fetching meta ai.usage summary"

JSON="$(meta ai.usage summary -o json 2>&1)"
if [ -z "$JSON" ] || ! echo "$JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
    cron_log "ERROR: meta ai.usage summary returned invalid JSON: $(echo "$JSON" | head -c 200)"
    exit 1
fi

# Append full snapshot to history (one line per run, preserves tool_breakdown for trend mining)
{
    printf '{"timestamp":"%s","data":' "$(date -Iseconds)"
    printf '%s' "$JSON"
    printf '}\n'
} >> "$HISTORY_FILE"

# Parse with Python — single pass returns all derived fields.
# Pass JSON via env var (heredoc redirects stdin so a pipe would be ignored).
PARSED="$(USAGE_JSON="$JSON" \
          POLICY_PCT_THRESHOLD="$POLICY_PCT_THRESHOLD" \
          python3 <<'PYEOF'
import json, os
d = json.loads(os.environ["USAGE_JSON"])
daily = d.get("l7_daily") or []
today = daily[-1] if daily else 0
yest  = daily[-2] if len(daily) >= 2 else 0
delta = ((today - yest) / yest * 100.0) if yest > 0 else 0.0
l7_cost   = d.get("l7_cost") or 0
wow       = d.get("l7_percent_change") or 0
mtd_total   = d.get("mtd_total", 0)
mtd_budget  = d.get("mtd_budget", 0)
mtd_percent = d.get("mtd_percent_used", 0)

# Top tool drivers (share-of-spend) — used for "what to act on" attribution
tools = sorted(d.get("tool_breakdown") or [], key=lambda t: t.get("share", 0), reverse=True)
top_tools = ";".join(f"{t['tool']}={t.get('share',0)}%" for t in tools[:3]) or "-"

# Policies near cap
threshold = int(os.environ.get("POLICY_PCT_THRESHOLD", "80"))
hot = []
for p in d.get("policies", []):
    pct = p.get("percent_used", 0)
    if pct >= threshold:
        hot.append(f"{p.get('name','?')}={pct}%")
hot_str = ";".join(hot) if hot else "-"

# Output: 9 space-separated tokens. top_tools/hot_str use ";" so no internal spaces.
print(f"{today:.2f} {yest:.2f} {delta:.1f} {l7_cost:.0f} {wow:.1f} {mtd_total} {mtd_budget} {mtd_percent} {top_tools} {hot_str}")
PYEOF
)"
read -r TODAY_COST YESTERDAY_COST DELTA_PCT L7_COST WOW_PCT MTD_TOTAL MTD_BUDGET MTD_PERCENT TOP_TOOLS POLICY_ALERTS <<<"$PARSED"

cron_log "today=\$${TODAY_COST}  yest=\$${YESTERDAY_COST}  dod=${DELTA_PCT}%  l7=\$${L7_COST}  wow=${WOW_PCT}%  mtd=\$${MTD_TOTAL}/\$${MTD_BUDGET} (${MTD_PERCENT}%)  top=${TOP_TOOLS}"

# Guard: empty l7_daily from API rate-limiting → skip cost-band checks (avoid silent miss).
# Trend signals can't compute either. Policy check still runs (independent field).
TODAY_INT_RAW="${TODAY_COST%.*}"
if [ "${TODAY_INT_RAW:-0}" = "0" ] && [ "${YESTERDAY_COST%.*}" = "0" ] && [ "${L7_COST%.*}" = "0" ]; then
    cron_log "l7_daily unavailable (likely API cooldown) — skipping cost-band + trend checks, will retry next run"
    SKIP_COST_CHECKS=1
else
    SKIP_COST_CHECKS=0
fi

# ─── Signal sinks ─────────────────────────────────────────────────────────
# fire_soft = agent-readable SIGNALS.md (no ALERTS noise)
# fire_hard = ALERTS.md (P0 mailbox)
already_fired() { [ -f "$SENTINEL_DIR/$1-${TODAY}" ]; }
mark_fired() { touch "$SENTINEL_DIR/$1-${TODAY}"; }

init_signals_file() {
    [ -f "$SIGNALS_FILE" ] && [ "$(head -1 "$SIGNALS_FILE" 2>/dev/null | grep -c "$TODAY")" != "0" ] && return
    {
        echo "# Token Usage Signals — ${TODAY}"
        echo ""
        echo "Soft signals for agent self-optimization. WARN+HARD escalate to next daily-brief."
        echo "Cleared daily by next-day's first signal write."
        echo ""
        echo "**Current**: today=\$${TODAY_COST}, yest=\$${YESTERDAY_COST}, l7=\$${L7_COST}, mtd=\$${MTD_TOTAL}/\$${MTD_BUDGET} (${MTD_PERCENT}%)"
    } > "$SIGNALS_FILE"
}

init_pending_brief() {
    [ -f "$PENDING_BRIEF_FILE" ] && return
    {
        echo "# Pending Token-Usage Signals for Next Daily Brief"
        echo ""
        echo "WARN+HARD signals queued here are picked up by cron-daily-brief.sh at 08:23 PT,"
        echo "surfaced in the brief, then this file is archived to PENDING-BRIEF-YYYY-MM-DD.md."
        echo ""
        echo "| Time | Tier | Condition | Message | Top Tools | Hint |"
        echo "|------|------|-----------|---------|-----------|------|"
    } > "$PENDING_BRIEF_FILE"
}

append_pending_brief() {
    local tier="$1" cond="$2" msg="$3" hint="$4"
    init_pending_brief
    printf '| %s | %s | %s | %s | %s | %s |\n' \
        "$NOW" "$tier" "$cond" "$msg" "${TOP_TOOLS}" "$hint" >> "$PENDING_BRIEF_FILE"
}

fire_soft() {
    local cond="$1" tier="$2" msg="$3" hint="$4"
    if already_fired "$cond"; then return; fi
    init_signals_file
    {
        echo ""
        echo "## ${NOW} [${tier}] ${cond}"
        echo "$msg"
        echo ""
        echo "**Top tools (share of l7 spend)**: ${TOP_TOOLS}"
        echo "**Hint**: ${hint}"
        echo "**Dashboard**: https://fburl.com/tokenusage"
    } >> "$SIGNALS_FILE"
    # WARN tier ALSO escalates to next morning's daily-brief; pure SOFT stays agent-local
    if [ "$tier" = "WARN" ]; then
        append_pending_brief "$tier" "$cond" "$msg" "$hint"
    fi
    mark_fired "$cond"
    cron_log "[signal:${tier}] ${cond} → SIGNALS.md$([ "$tier" = "WARN" ] && echo " + PENDING-BRIEF")"
}

fire_hard() {
    local cond="$1" msg="$2" hint="${3:-Open dashboard, identify top driver, throttle or kill it.}"
    if already_fired "$cond"; then return; fi
    cron_alert "token-usage" "$msg | top=${TOP_TOOLS} | https://fburl.com/tokenusage"
    append_pending_brief "HARD" "$cond" "$msg" "$hint"
    mark_fired "$cond"
    cron_log "[alert:hard] ${cond} → ALERTS.md + PENDING-BRIEF"
}

# Integer math helpers (bash can't compare floats)
TODAY_INT="${TODAY_COST%.*}"; TODAY_INT="${TODAY_INT:-0}"
DELTA_INT="${DELTA_PCT%.*}";  DELTA_INT="${DELTA_INT:-0}"
WOW_INT="${WOW_PCT%.*}";      WOW_INT="${WOW_INT:-0}"

# ─── Tier 1: SOFT ($2500+) — early signal ────────────────────────────────
if [ "$SKIP_COST_CHECKS" = "0" ] && [ "$TODAY_INT" -ge "$SOFT_COST_THRESHOLD" ] && [ "$TODAY_INT" -lt "$WARN_COST_THRESHOLD" ]; then
    fire_soft "cost-soft" "SOFT" \
        "Today's cost \$${TODAY_COST} crossed soft band (>=\$${SOFT_COST_THRESHOLD}). Plenty of room to the cap, but trend-watch." \
        "Background: nothing required. If trend continues, top-driver tool ($(echo "$TOP_TOOLS" | cut -d';' -f1)) is the lever."
fi

# ─── Tier 2: WARN ($3500+) — actionable signal ───────────────────────────
if [ "$SKIP_COST_CHECKS" = "0" ] && [ "$TODAY_INT" -ge "$WARN_COST_THRESHOLD" ] && [ "$TODAY_INT" -lt "$HARD_COST_THRESHOLD" ]; then
    fire_soft "cost-warn" "WARN" \
        "Today's cost \$${TODAY_COST} in warn band (>=\$${WARN_COST_THRESHOLD}, <\$${HARD_COST_THRESHOLD}). Above recent peak; investigate now." \
        "Open dashboard, check top-driver tool ($(echo "$TOP_TOOLS" | cut -d';' -f1)). Consider: prune verbose hooks, lower default model for that tool, reduce cron frequency on its consumers."
fi

# ─── Tier 3: HARD ($5000+) — speeding ticket ─────────────────────────────
if [ "$SKIP_COST_CHECKS" = "0" ] && [ "$TODAY_INT" -ge "$HARD_COST_THRESHOLD" ]; then
    fire_hard "cost-hard" \
        "Daily token cost \$${TODAY_COST} >= hard threshold \$${HARD_COST_THRESHOLD}"
fi

# ─── Trend: DoD jump (soft) ──────────────────────────────────────────────
if [ "$SKIP_COST_CHECKS" = "0" ] && [ "$DELTA_INT" -gt "$DELTA_PCT_THRESHOLD" ]; then
    fire_soft "trend-dod" "SOFT" \
        "Day-over-day cost up ${DELTA_PCT}% (>${DELTA_PCT_THRESHOLD}%): today=\$${TODAY_COST} vs yest=\$${YESTERDAY_COST}." \
        "Compare today's top tool vs yesterday — likely a new cron/hook/workflow is the cause."
fi

# ─── Trend: WoW jump (soft) ──────────────────────────────────────────────
if [ "$SKIP_COST_CHECKS" = "0" ] && [ "$WOW_INT" -gt "$WOW_PCT_THRESHOLD" ]; then
    fire_soft "trend-wow" "SOFT" \
        "Week-over-week cost up ${WOW_PCT}% (>${WOW_PCT_THRESHOLD}%): l7=\$${L7_COST}." \
        "Structural growth, not a one-off. Audit: any new agent/cron added this week?"
fi

# ─── Policy approaching cap (hard — close to a real enforcement) ─────────
if [ "$POLICY_ALERTS" != "-" ]; then
    fire_hard "policy" \
        "Policies near cap (>=${POLICY_PCT_THRESHOLD}%): ${POLICY_ALERTS}"
fi

write_heartbeat "token-usage-alert"
cron_log "done"
