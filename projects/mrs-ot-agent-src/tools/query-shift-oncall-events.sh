#!/bin/bash
# query-shift-oncall-events.sh — Data-generate the OT shift-summary "Daily Timeline".
#
# For the mrs_online_training oncall, over a START→END window (default: most
# recent Tue 09:00 PT → now), emit a time-sorted, day-grouped event list with
# clickable identifiers (S###/A###/D###) and a one-line what-happened — the exact
# shape the ot-shift-summary gdoc "Daily Timeline" + "Critical alerts" sections
# need. Replaces the hand-typed laundry list (operator ask 2026-06; gdoc comments
# AAAB8p7d1wg "why major/critical alerts activities are missing?",
# WhmgQGD72MQ "S668272 — oncall got robocalled Wed night. why not captured?").
#
# ── THE PAGE / ROBOCALL SIGNAL (the hard part — SOLVED) ──────────────────────
# The queryable source of TRUE pages/robocalls is the Escalation Service
# notification ledger, exposed as:
#     meta oncall.notification list --oncall=<rot> --escalating
# Per its --help: "--escalating  Only show escalating notifications (critical
# alerts, SEVs, bananaphone calls, UBN tasks)". bananaphone == the robocall/phone
# page. Each row carries: source_type (alert|sev|bananaphone|multi_alert|task),
# source_id (resolvable short_id for alerts, S### for SEVs), urgency, status
# (in_progress|acked|finished|cancelled|suppressed|source_not_actionable),
# created_at, and a resolvable url. This is NOT a proxy — it is the actual record
# of notifications dispatched by Escalation Service (the OMH notifications page).
# Validated: reproduces S670887 (in-shift robocall, 2026-06-03) and S668272
# (2026-05-26 robocall) as escalating SEV notifications.
#
# Section semantics:
#   🚨 PAGED  — oncall.notification --escalating  (the page/robocall audit)
#   🔔 ALERT  — oncall.notification (all)         (major+critical alert firing
#                history in-window, with resolved/open via the `status` field)
#   🧯 SEV    — sevmanager.sev list --tags=mvai-online-training (OT SEVs in window)
#   🔴 OPEN   — monitoring.alert list --state-is=ACTIVE (currently-firing alerts)
#
# Resolved vs open:
#   - Alerts: notification `status` finished/acked == handled; in_progress == open.
#     monitoring.alert `state` ACTIVE == still firing now.
#   - SEVs:   `status` Closed/Mitigated == resolved; In Progress/Fix Ready == open.
#
# Known data limitation: AGG / centralized-alerting notifications carry a path
# source_id (no numeric A-id) and an empty source_title in the notification feed
# — they render as `[AGG]` with the resolvable per-notification url but no inline
# title. They are still surfaced (urgency/status/url present); the title is simply
# not in this feed. For full AGG detail the render can follow the url, or call
# `meta monitoring.alert metadata --alert-id=<source_id>`.
#
# Usage:
#   bash query-shift-oncall-events.sh [--start <ISO|epoch>] [--end <ISO|epoch>]
#                                     [--oncall NAME] [--json-only]
#
# Options:
#   --start <ISO|epoch>  Window start (default: most recent Tue 09:00 PT).
#   --end   <ISO|epoch>  Window end   (default: now).
#   --oncall NAME        Oncall rotation (default: mrs_online_training).
#   --json-only          Emit only JSONL events to stdout, no human summary.
#   -h|--help            Show usage.
#
# Output (default): human-readable, grouped by day, sorted by time; each line
#   "<HH:MM PT> <emoji> <ID> <what> → <url>". JSON mode: one compact object/line.
#
# Exit codes: 0 = events emitted, 1 = no events in window, 2 = usage/fetch error.

set -uo pipefail

# Resolvable-URL builders (sev_url / alert_url / diff_url), correct-by-construction.
# shellcheck source=lib-url.sh
source "$(dirname "$0")/lib-url.sh"

ONCALL="mrs_online_training"
JSON_ONLY=false
START_ARG=""
END_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --start)     START_ARG="$2"; shift 2 ;;
    --end)       END_ARG="$2";   shift 2 ;;
    --oncall)    ONCALL="$2";    shift 2 ;;
    --json-only) JSON_ONLY=true; shift ;;
    -h|--help)
      sed -n '2,52p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

log() { if [ "${JSON_ONLY}" = "false" ]; then echo "$@"; fi; }

# ── Window resolution (PT = -07:00; default most recent Tue 09:00 PT → now) ──
WINDOW=$(START_ARG="${START_ARG}" END_ARG="${END_ARG}" python3 -c "
import os, time
from datetime import datetime, timedelta, timezone
pt = timezone(timedelta(hours=-7))

def parse(v):
    if not v:
        return None
    v = v.strip()
    if v.isdigit():
        return datetime.fromtimestamp(int(v), tz=pt)
    for fmt in ('%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d'):
        try:
            return datetime.strptime(v, fmt).replace(tzinfo=pt)
        except ValueError:
            pass
    raise SystemExit(f'ERROR: cannot parse time: {v}')

s = parse(os.environ.get('START_ARG'))
e = parse(os.environ.get('END_ARG'))
now = datetime.now(pt)
if e is None:
    e = now
if s is None:
    # most recent Tuesday (weekday()==1) at 09:00 PT
    days = (now.weekday() - 1) % 7
    s = (now - timedelta(days=days)).replace(hour=9, minute=0, second=0, microsecond=0)
    # If today IS Tuesday but before 09:00, the line above lands in the FUTURE
    # (e.g. run Tue 06:00 → start Tue 09:00 today), which would drop the entire
    # in-progress shift. Step back a full week so the window still covers the
    # active shift. (codex review 2026-06-06)
    if s > now:
        s = s - timedelta(days=7)
print(int(s.timestamp()))
print(int(e.timestamp()))
print(s.strftime('%Y-%m-%d'))             # start date (for --date-after / --created-after)
print(s.strftime('%Y-%m-%d %H:%M %a'))
print(e.strftime('%Y-%m-%d %H:%M %a'))
") || { echo "${WINDOW}" >&2; exit 2; }

START_EPOCH=$(echo "${WINDOW}" | sed -n '1p')
END_EPOCH=$(echo "${WINDOW}"   | sed -n '2p')
START_DATE=$(echo "${WINDOW}"  | sed -n '3p')
START_HUMAN=$(echo "${WINDOW}" | sed -n '4p')
END_HUMAN=$(echo "${WINDOW}"   | sed -n '5p')

log "=== OT Shift Oncall Events ==="
log "Oncall: ${ONCALL}"
log "Window: ${START_HUMAN} PT  →  ${END_HUMAN} PT"
log "Epochs: ${START_EPOCH} → ${END_EPOCH}"
log ""

# Temp dir for the raw JSON pulls.
WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

# fetch_one <outfile> <meta args...>
#   Runs a meta CLI call, captures output, and validates it parses as a JSON
#   array. On CLI non-zero exit OR a non-array/empty/error-shaped body, writes
#   [] to <outfile> AND records the failure (so a fetch failure is NEVER
#   silently rendered as "verified zero" — codex review 2026-06-06). Returns
#   0 on a clean JSON array, 1 on any failure.
FETCH_FAILED=""
fetch_one() {
  local out="$1"; shift
  local raw rc
  raw=$(meta "$@" -o json 2>/dev/null); rc=$?
  if [ "${rc}" -ne 0 ] || ! printf '%s' "${raw}" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    sys.exit(0 if isinstance(d, list) else 1)   # must be an array; {status:error} → fail
except Exception:
    sys.exit(1)
" 2>/dev/null; then
    echo '[]' > "${out}"
    FETCH_FAILED="${FETCH_FAILED} $(basename "${out}")"
    return 1
  fi
  printf '%s' "${raw}" > "${out}"
  return 0
}

# ── 1. PAGED / ROBOCALLED — escalating notifications (the page record) ───────
# --escalating filters to critical alerts, SEVs, bananaphone (robocall), UBN.
# --date-after is inclusive; we re-filter to [START_EPOCH, END_EPOCH] in python.
fetch_one "${WORK}/paged.json" oncall.notification list --oncall="${ONCALL}" --escalating \
  --date-after="${START_DATE}" \
  --columns=id,source_type,source_id,source_title,status,urgency,created_at,url -l 300

# ── 2. ALERT history — ALL notifications (resolved/open via status) ──────────
fetch_one "${WORK}/alerts.json" oncall.notification list --oncall="${ONCALL}" \
  --source-type=alert --date-after="${START_DATE}" \
  --columns=id,source_type,source_id,source_title,status,urgency,created_at,url -l 500

# ── 3. OT SEVs in window — tagged mvai-online-training ──────────────────────
fetch_one "${WORK}/sevs.json" sevmanager.sev list --tags=mvai-online-training \
  --created-after="${START_DATE}" -l 100

# ── 4. Currently-OPEN alerts — monitoring.alert ACTIVE (snapshot, not in-window) ─
# Snapshot enrichment only; a failure here is tolerable (does NOT fail the run).
fetch_one "${WORK}/active.json" monitoring.alert list --oncall="${ONCALL}" \
  --state-is=ACTIVE --urgency-is=CRITICAL,MAJOR -l 200 || true

# Fetch-failure gate: if any of the THREE in-window page-record sources failed
# (paged/alerts/sevs), the timeline would be incomplete — surface it loudly and
# exit 2 (fetch error), NOT 1 (clean "no events"). Robocall-detection MUST never
# masquerade a CLI failure as "verified zero".
for f in paged.json alerts.json sevs.json; do
  case " ${FETCH_FAILED} " in
    *" ${f} "*)
      echo "ERROR: fetch failed for ${f} — timeline incomplete, refusing to report 'zero'." >&2
      echo "Failed sources:${FETCH_FAILED}" >&2
      exit 2 ;;
  esac
done

# ── Normalize → one JSONL event stream, then group/sort in python. ──────────
EVENTS=$(START_EPOCH="${START_EPOCH}" END_EPOCH="${END_EPOCH}" WORK="${WORK}" \
  ONCALL="${ONCALL}" python3 <<'PY'
import os, json, re
from datetime import datetime, timezone, timedelta

pt = timezone(timedelta(hours=-7))
s_ep = int(os.environ['START_EPOCH'])
e_ep = int(os.environ['END_EPOCH'])
work = os.environ['WORK']
B = "https://www.internalfb.com"

def load(name):
    try:
        raw = open(os.path.join(work, name)).read().strip()
        return json.loads(raw) if raw else []
    except Exception:
        return []

def iso_to_epoch(s):
    if not s:
        return 0
    for fmt in ('%Y-%m-%dT%H:%M:%S%z', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M:%S'):
        try:
            dt = datetime.strptime(s, fmt)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=pt)
            return int(dt.timestamp())
        except ValueError:
            pass
    return 0

def sev_url(sid):
    n = re.sub(r'^[Ss]', '', str(sid))
    return f"{B}/sevmanager/view/{n}" if n.isdigit() else ""

def alert_url(short_id):
    # short_id composite carries @ # $ → resolvable; bare numeric does NOT resolve.
    if not short_id:
        return ""
    if any(c in short_id for c in ('@', '#', '$')):
        return f"{B}/monitoring/alerts/?alert_instance={short_id}"
    return ""

def short_alert_id(short_id):
    # The numeric prefix before the first @ is the alert's display A-id seed.
    # AGG/centralized-alerting source_ids are paths (no numeric prefix) → no A-id;
    # caller falls back to the notification's own resolvable url.
    m = re.match(r'^(\d+)', short_id or '')
    return f"A{m.group(1)}" if m else "[AGG]"

events = []  # each: dict(epoch, kind, emoji, id_disp, url, urgency, status, text)

# 1. PAGED / ROBOCALLED (escalating notifications)
for n in load('paged.json'):
    ep = iso_to_epoch(n.get('created_at', ''))
    if not (s_ep <= ep <= e_ep):
        continue
    st = n.get('source_type', '')
    sid = n.get('source_id', '')
    title = (n.get('source_title') or '').strip()
    urg = n.get('urgency', '') or ('robocall' if st == 'bananaphone' else '')
    status = n.get('status', '')
    if st == 'sev':
        disp = sid if str(sid).startswith('S') else f"S{sid}"
        url = sev_url(sid)
        urg = urg or 'SEV'
    elif st in ('alert', 'multi_alert'):
        disp = short_alert_id(sid)
        url = alert_url(sid) or n.get('url', '')
    elif st == 'bananaphone':
        disp = "robocall"
        url = n.get('url', '')
        urg = 'robocall'
    else:
        disp = st
        url = n.get('url', '')
    events.append(dict(epoch=ep, kind='paged', emoji='🚨', id_disp=disp, url=url,
                       urgency=urg, status=status, source_type=st,
                       text=f"PAGED ({st}/{urg}) {title}"))

# 2. ALERT history (all alert notifications in window) — dedupe by (source_id, day)
seen = set()
for n in load('alerts.json'):
    ep = iso_to_epoch(n.get('created_at', ''))
    if not (s_ep <= ep <= e_ep):
        continue
    sid = n.get('source_id', '')
    urg = (n.get('urgency') or '').lower()
    if urg not in ('critical', 'major'):
        continue
    day = datetime.fromtimestamp(ep, pt).strftime('%Y-%m-%d')
    key = (sid, day)
    if key in seen:
        continue
    seen.add(key)
    title = (n.get('source_title') or '').strip()
    status = n.get('status', '')
    resolved = status in ('finished', 'acked', 'source_not_actionable', 'cancelled')
    events.append(dict(epoch=ep, kind='alert', emoji='🔔',
                       id_disp=short_alert_id(sid),
                       url=alert_url(sid) or n.get('url', ''),
                       urgency=urg, status=status, source_type='alert',
                       text=f"alert ({urg}, {'resolved' if resolved else 'open'}: {status}) {title}"))

# 3. OT SEVs in window (tagged)
for sv in load('sevs.json'):
    created = sv.get('created', '') or sv.get('time_started', '')
    ep = iso_to_epoch(created)
    if not (s_ep <= ep <= e_ep):
        continue
    num = sv.get('sev_number', '')
    status = sv.get('status', '')
    level = sv.get('level', '')
    title = (sv.get('title') or '').strip()
    resolved = status in ('Closed', 'Mitigated')
    events.append(dict(epoch=ep, kind='sev', emoji='🧯',
                       id_disp=num if str(num).startswith('S') else f"S{num}",
                       url=sv.get('url', '') or sev_url(num),
                       urgency=f"L{level}" if level else '', status=status,
                       source_type='sev',
                       text=f"SEV ({status}) {title}"))

# Sort all in-window events by time.
events.sort(key=lambda x: x['epoch'])

# 4. Currently-OPEN alerts (snapshot, no in-window time) — emit separately.
active = []
for a in load('active.json'):
    sid = a.get('alert_id', '')
    urg = (a.get('urgency') or '').lower()
    active.append(dict(id_disp=short_alert_id(sid), urgency=urg,
                       url=alert_url(sid),
                       text=(a.get('alert') or '').strip()))

# Emit JSONL: in-window events, then an "active snapshot" marker block.
out = {'events': events, 'active_now': active,
       'counts': {
           'paged': sum(1 for e in events if e['kind'] == 'paged'),
           'alerts': sum(1 for e in events if e['kind'] == 'alert'),
           'sevs': sum(1 for e in events if e['kind'] == 'sev'),
           'sevs_open': sum(1 for e in events if e['kind'] == 'sev' and e['status'] not in ('Closed', 'Mitigated')),
           'sevs_resolved': sum(1 for e in events if e['kind'] == 'sev' and e['status'] in ('Closed', 'Mitigated')),
           'active_now': len(active),
       }}
print(json.dumps(out))
PY
)

# ── JSON-only mode: stream events + active + counts as JSONL. ────────────────
if [ "${JSON_ONLY}" = "true" ]; then
  echo "${EVENTS}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for e in d['events']:
    print(json.dumps(e, separators=(',', ':')))
for a in d['active_now']:
    a = dict(a); a['kind'] = 'active_now'
    print(json.dumps(a, separators=(',', ':')))
print(json.dumps({'summary': d['counts']}, separators=(',', ':')))
"
  C=$(echo "${EVENTS}" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['counts']['paged']+d['counts']['alerts']+d['counts']['sevs'])")
  [ "${C}" -gt 0 ] && exit 0 || exit 1
fi

# ── Human-readable: grouped by day, sorted by time. ─────────────────────────
echo "${EVENTS}" | python3 -c "
import sys, json
from datetime import datetime, timezone, timedelta
pt = timezone(timedelta(hours=-7))
d = json.load(sys.stdin)
c = d['counts']

print('--- 🚨 ROBOCALL / PAGE AUDIT (escalating notifications) ---')
paged = [e for e in d['events'] if e['kind'] == 'paged']
if not paged:
    print('  (none — verified zero via oncall.notification --escalating)')
for e in paged:
    t = datetime.fromtimestamp(e['epoch'], pt).strftime('%a %m-%d %H:%M')
    print(f\"  {t} PT  {e['id_disp']:>10}  {e['text'][:90]}\")
    if e['url']:
        print(f\"             → {e['url']}\")
print()

print('--- 📅 DAILY TIMELINE (in-window events, by day) ---')
cur = None
for e in sorted(d['events'], key=lambda x: x['epoch']):
    day = datetime.fromtimestamp(e['epoch'], pt).strftime('%A %Y-%m-%d')
    if day != cur:
        cur = day
        print(f'  ── {day} ──')
    hm = datetime.fromtimestamp(e['epoch'], pt).strftime('%H:%M')
    print(f\"    {hm} {e['emoji']} {e['id_disp']:>10}  {e['text'][:88]}\")
    if e['url']:
        print(f\"               → {e['url']}\")
print()

print('--- 🔴 CURRENTLY-OPEN alerts (snapshot now, ACTIVE) ---')
if not d['active_now']:
    print('  (none active now)')
for a in d['active_now']:
    print(f\"  {a['id_disp']:>10} ({a['urgency']})  {a['text'][:80]}\")
    if a['url']:
        print(f\"             → {a['url']}\")
print()

print('--- COUNTS ---')
print(f\"  paged/robocalled : {c['paged']}\")
print(f\"  major+crit alerts: {c['alerts']}\")
print(f\"  OT SEVs in window: {c['sevs']}  (open {c['sevs_open']} / resolved {c['sevs_resolved']})\")
print(f\"  active alerts now: {c['active_now']}\")
"

# Machine summary line (self-report rule — render cites counts from DATA).
echo "${EVENTS}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(json.dumps({'summary': d['counts']}, separators=(',', ':')))
"

# Exit code: 0 if any in-window event, else 1.
TOTAL=$(echo "${EVENTS}" | python3 -c "import sys,json;d=json.load(sys.stdin);c=d['counts'];print(c['paged']+c['alerts']+c['sevs'])")
[ "${TOTAL}" -gt 0 ] && exit 0 || exit 1
