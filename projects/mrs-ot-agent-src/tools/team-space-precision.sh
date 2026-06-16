#!/bin/bash
# team-space-precision.sh — DECISIVE metric query for the team-chat delivery-leak
# issue (T274834361). Confirms the leak from ground-truth data, not narration,
# and doubles as the fix's acceptance test: when D107579040's core consumer +
# the contains-HEARTBEAT_OK relaxation land, precision should jump past the bar.
#
# WHY content-prefix classification (not sender-id): bot cron posts currently
# render under Denny's sender id (100051448831249) because the WIB live toggle
# has not propagated, so a sender-id "bot vs human" filter mis-buckets cron posts.
# Machine posts carry deterministic prefixes; humans post free-form. We classify
# on the prefix, which is both decisive and robust to the dual-identity mess.
#
# Source of truth: live GChat API (the local `messages` table is an ingestion
# log — status='skipped' rows are not real sends; gotcha_messages-table-is-ingestion-log).
#
# Usage: bash team-space-precision.sh [HOURS]   (default 24)
# Output: one JSON line to stdout (precision + per-source noise breakdown).
set -uo pipefail
HOURS="${1:-24}"
TEAM_SPACE="spaces/AAQA2bZMw24"

RAW="$(meta google.chat.message list --space-id "${TEAM_SPACE}" --limit 250 -o json 2>/dev/null)"
[ -z "${RAW}" ] && { echo '{"error":"gchat_api_returned_empty","precision":null}'; exit 1; }

echo "${RAW}" | HOURS="${HOURS}" python3 -c '
import json, sys, os, re, time

hours = float(os.environ["HOURS"])
cutoff = time.time() - hours * 3600
msgs = json.load(sys.stdin)

# Deterministic mechanical allow-list (mirrors ot-bot-volume-watch SIGNAL set).
# SIGNAL = posts that LEGITIMATELY belong in the team space (shared OT incident signal).
SIGNAL = [
    re.compile(r"^\s*🩺\s*\*?OT fleet health"),   # fleet-health digest (failure-only, team-by-design)
    re.compile(r"^\s*🚨\s*\[OT "),                 # any 🚨 [OT …] escalation (SEV / PAGE / etc.) — generalized 2026-06-10 from literal "[OT SEV" after "🚨 [OT PAGE]" was miscounted NOISE (bracket-family whack-a-mole fix)
    re.compile(r"^\s*\[OT triage\]"),              # crisp-5-element incident triage VERDICT (CLAUDE.md report style; id+class+symptom) — real team signal (added 2026-06-10 after S673569 REAL_OT_FAILURE was miscounted NOISE)
    re.compile(r"^\s*🚨\s*\[unrouted"),            # alert-monitor unrouted PAGE
    re.compile(r"^\s*🔴"),                          # PAGE / hard escalation
]
# NOISE buckets — machine posts that should NOT be in the team space.
NOISE = [
    ("interactive_myclaw_ot", re.compile(r"🛟\s*MyClaw-OT")),  # operator<->bot dialogue (the dominant leak; core/cross_space.py)
    ("design_planning_agent", re.compile(r"^\s*🦆")),          # non-OT design/planning agent
    ("operator_brief_leak",   re.compile(r"^\s*(📋|🗓️)")),     # 1:1 briefs that leaked to team
]

def epoch(m):
    e = m.get("create_time_unix")
    if e:
        try: return float(e)
        except: pass
    return time.time()  # if missing, assume in-window (conservative)

signal = 0
noise_by = {k: 0 for k, _ in NOISE}
noise_other_bot = 0
human_or_unknown = 0
total_in_window = 0

for m in msgs:
    if epoch(m) < cutoff:
        continue
    total_in_window += 1
    txt = (m.get("text") or m.get("formatted_text") or "").strip()
    if any(p.search(txt) for p in SIGNAL):
        signal += 1
        continue
    bucketed = False
    for k, p in NOISE:
        if p.search(txt):
            noise_by[k] += 1
            bucketed = True
            break
    if bucketed:
        continue
    # Unclassified: machine post (starts with emoji/bracket) vs human free-form.
    if re.match(r"^\s*([\[☀-➿\U0001F000-\U0001FAFF])", txt):
        noise_other_bot += 1
    else:
        human_or_unknown += 1

noise_total = sum(noise_by.values()) + noise_other_bot
bot_posts = signal + noise_total          # precision denominator = machine posts only
precision = round(signal / bot_posts, 3) if bot_posts else None

out = {
    "window_hours": hours,
    "team_space": "spaces/AAQA2bZMw24",
    "msgs_in_window": total_in_window,
    "bot_posts": bot_posts,
    "signal": signal,
    "noise": noise_total,
    "precision": precision,
    "noise_by_source": {**noise_by, "other_bot": noise_other_bot},
    "human_or_unknown_excluded": human_or_unknown,
    "source": "gchat_api_live",
}
print(json.dumps(out))
'
