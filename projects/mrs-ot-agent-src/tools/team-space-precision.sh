#!/bin/bash
# team-space-precision.sh — DECISIVE metric query for the team-chat delivery-leak
# issue (T274834361 / T275142534). Confirms the leak from ground-truth data, not
# narration, and doubles as the fix's acceptance test.
#
# CRON-vs-INTERACTIVE PARTITION (rewritten 2026-06-15, recurrence #3 of the
# "interactive dialogue mis-counted as a cron leak" miscount — flagged in
# ot-bot-volume-watch step-12 line 74 twice before, then a 3rd time on 2026-06-15
# when an audit run reported precision 60% by bucketing the interactive !ot-bot
# thread as cron noise; a later run reported 100% by masking a real cron leak into
# upstream). The split is now DETERMINISTIC, not LLM judgment:
#
#   • SIGNAL  — posts that LEGITIMATELY belong in the team space, matched by the
#     mechanical prefix allow-list (🩺 fleet-health / 🔴 / 🚨 [OT…] / [OT triage]).
#     Classified by PREFIX (some signal sources — e.g. fleet-health — run on a
#     different instance and have no job_run here; the shape is the allow-list).
#   • CRON NOISE — a NON-signal bot post whose content FINGERPRINT matches a
#     `delivered` cron `job_runs.raw_response` in-window. This is THIS lane's cron
#     leaking non-signal to the team space → IN-LANE, prompt-fixable, counts in
#     cron precision. (A leaked cron ⚠️ wears the same 🛟 prefix as an interactive
#     reply, so the prefix CANNOT discriminate it — only the job_run match can.)
#   • UPSTREAM LEAK — a NON-signal bot post with NO matching delivered cron
#     job_run (interactive operator↔bot dialogue, design-agent posts, cross-space).
#     Counted SEPARATELY as `upstream_leaks`; NEVER in the cron precision fraction
#     (folding it in is the exact miscount the operator flagged; T275122535).
#
# HEADLINE: cron_precision = cron_signal / (cron_signal + cron_noise). Interactive
# leaks are a separate `upstream_leaks` number, tracked upstream (myclaw-core).
#
# WHY content-prefix (not sender-id) for SIGNAL: bot cron posts render under
# Denny's sender id until the WIB live toggle propagates, so a sender-id filter
# mis-buckets cron posts. Machine posts carry deterministic prefixes.
#
# Source of truth: live GChat API for team posts; local sqlite job_runs for the
# cron-delivery fingerprint set (delivered!='skipped' rows are real cron sends).
#
# Usage: bash team-space-precision.sh [HOURS] [DB_PATH]   (default 24, default DB)
# Output: one JSON line to stdout (cron_precision + upstream_leaks + breakdown).
set -uo pipefail
HOURS="${1:-24}"
DB="${2:-/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db}"
TEAM_SPACE="spaces/AAQA2bZMw24"

RAW="$(meta google.chat.message list --space-id "${TEAM_SPACE}" --limit 250 -o json 2>/dev/null)"
[ -z "${RAW}" ] && { echo '{"error":"gchat_api_returned_empty","cron_precision":null}'; exit 1; }

# Delivered cron raw_responses in-window → the fingerprint set (one JSON array).
# delivered!='skipped' = the daemon actually sent the cron's final response.
DELIVERED="$(sqlite3 -json "${DB}" \
  "SELECT raw_response FROM job_runs \
   WHERE delivered IS NOT NULL AND delivered<>'skipped' \
   AND run_at > datetime('now','-${HOURS} hours');" 2>/dev/null)"
[ -z "${DELIVERED}" ] && DELIVERED='[]'

echo "${RAW}" | HOURS="${HOURS}" DELIVERED="${DELIVERED}" python3 -c '
import json, sys, os, re, time

hours = float(os.environ["HOURS"])
cutoff = time.time() - hours * 3600
msgs = json.load(sys.stdin)

# --- content fingerprint: alnum-only, lowercased, whitespace-collapsed prefix ---
def fp(text):
    s = re.sub(r"\[?🛟\s*MyClaw-OT\]?:?", " ", text)      # strip bot reply prefix
    s = re.sub(r"[^a-z0-9 ]", " ", s.lower())
    s = re.sub(r"\s+", " ", s).strip()
    return s

# Fingerprint set of delivered cron responses (skip bare HEARTBEAT_OK heads).
delivered = []
for row in json.loads(os.environ["DELIVERED"]):
    f = fp(row.get("raw_response") or "")
    f = f.replace("heartbeat ok", " ").strip()
    if len(f) >= 24:
        delivered.append(f)

def is_cron_delivery(body_fp):
    # body_fp produced by a cron iff its leading content appears in a delivered run
    key = body_fp[:40]
    return any(key and key in d for d in delivered)

# SIGNAL = legit team-space shapes (prefix allow-list; mirrors step-12).
SIGNAL = [
    re.compile(r"^\s*🩺\s*\*?OT fleet health"),
    re.compile(r"^\s*🚨\s*\[OT "),
    re.compile(r"^\s*\[OT triage\]"),
    re.compile(r"^\s*🚨\s*\[unrouted"),
    re.compile(r"^\s*🔴"),
]
# Upstream (NON-cron) prefix families — only used to LABEL an unmatched post.
UPSTREAM_LABEL = [
    ("interactive_myclaw_ot", re.compile(r"🛟\s*MyClaw-OT")),
    ("design_planning_agent", re.compile(r"^\s*🦆|^\s*🦦")),
    ("operator_brief_leak",   re.compile(r"^\s*(📋|🗓️)")),
]

def epoch(m):
    e = m.get("create_time_unix")
    if e:
        try: return float(e)
        except: pass
    return time.time()  # missing → assume in-window (conservative)

cron_signal = 0
cron_noise = 0
upstream_by = {k: 0 for k, _ in UPSTREAM_LABEL}
upstream_other = 0
human_or_unknown = 0
total_in_window = 0

for m in msgs:
    if epoch(m) < cutoff:
        continue
    total_in_window += 1
    txt = (m.get("text") or m.get("formatted_text") or "").strip()
    if any(p.search(txt) for p in SIGNAL):
        cron_signal += 1
        continue
    body = fp(txt)
    looks_machine = bool(re.match(r"^\s*([\[☀-➿\U0001F000-\U0001FAFF])", txt))
    if not looks_machine and not any(p.search(txt) for _, p in UPSTREAM_LABEL):
        human_or_unknown += 1            # human free-form → excluded
        continue
    if is_cron_delivery(body):
        cron_noise += 1                  # IN-LANE: a cron leaked non-signal to team
        continue
    labelled = False
    for k, p in UPSTREAM_LABEL:
        if p.search(txt):
            upstream_by[k] += 1
            labelled = True
            break
    if not labelled:
        upstream_other += 1              # machine post, no cron job_run → upstream

cron_posts = cron_signal + cron_noise
cron_precision = round(cron_signal / cron_posts, 3) if cron_posts else None
upstream_leaks = sum(upstream_by.values()) + upstream_other

out = {
    "window_hours": hours,
    "team_space": "spaces/AAQA2bZMw24",
    "msgs_in_window": total_in_window,
    "cron_posts": cron_posts,
    "cron_signal": cron_signal,
    "cron_noise": cron_noise,
    "cron_precision": cron_precision,                 # HEADLINE — in-lane only
    "upstream_leaks": upstream_leaks,                 # separate; tracked T275122535
    "upstream_by_source": {**upstream_by, "other": upstream_other},
    "human_or_unknown_excluded": human_or_unknown,
    "delivered_cron_fingerprints": len(delivered),
    "source": "gchat_api_live + job_runs_delivered_match",
}
print(json.dumps(out))
'
