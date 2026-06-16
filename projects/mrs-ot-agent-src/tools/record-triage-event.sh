#!/usr/bin/env bash
# record-triage-event.sh — write ONE row to the triage_events table, the MEASUREMENT
# SUBSTRATE that ot-metrics-rollup (precision/recall/lag), ot-triage-auditor, and the
# daily-brief / human-attention "AI-handling" stats all read from.
#
# RESTORED 2026-06-07 (cron audit, contract §5 "watch your own organs"): the write was
# silently dropped from ot-sev-monitor's prompt around 2026-05-07 (the last row's date),
# leaving every reader consuming a FROZEN 20-row table for a month — a green-but-empty
# organ degrading the whole measurement flywheel while every cron reported healthy. The
# readers were left orphaned (clear sign the removal was an accidental refactor drop).
#
# Shared by the sev/alert/post monitors (§14b: deterministic write in a script, not
# LLM-narrated SQL in the prompt; §14c: one writer, not three copies). Each monitor calls
# this once per triaged item, after its verdict.
#
# Usage:
#   record-triage-event.sh --sev-id <S###|A###|W###> --cron <cron_job_id> \
#     --signal "<one-line signal>" [--signal-class mrs_online_training] \
#     [--confidence 0.0-1.0] [--validator-outcome confirmed|discrepancy|unavailable] \
#     [--suggested-owner <unixname>] [--auto-tag-applied 0|1] [--auto-tag-stuck 0|1] \
#     [--final-status <status>] [--root-cause-area <area>] [--notification-text "<text>"] \
#     [--routed-to auto|human] [--root-cause-at "<YYYY-MM-DD HH:MM:SS>"]
#
# --root-cause-at records WHEN the root cause was identified (the moment the agent landed a
# confident verdict / matched a known P-row / R-rule). Combined with ts_notified (first-notified)
# this yields TIME-TO-ROOT-CAUSE — the eval metric #1 ("cheap recurring-issue debug": same
# failure ≥3× → root cause in ≤5 min via P-row lookup). Pass the literal time, or 'now' to stamp
# the current wall-clock. Read by `tools/time-to-root-cause.sh`. Backward-compatible: omit it and
# the column is left NULL (the metric simply has no datapoint for that row).
#
# --routed-to records the AUTONOMY decision for THIS incident (the escalation metric the
# eval scoreboard tracks): 'auto' = the bot handled it end-to-end itself (no human action
# needed — resolved / monitored / autonomously triaged in 1:1); 'human' = the bot could NOT
# resolve it and POPPED it to a human for action, posted to the TEAM myclaw space. Default
# 'auto'. Goal: human-escalation rate (human / total) trends DOWN to ~5% as the agent improves
# — read by `tools/escalation-rate.sh`.
set -uo pipefail
DB="$HOME/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db"

SEV_ID="" CRON="" SIGNAL="" SCLASS="mrs_online_training" CONF="" VOUT="" OWNER=""
ATAG="0" ASTUCK="0" FSTATUS="" RCAREA="" NTEXT="" CLASS="" CMIT="" UCONF="" RTO="auto" RCAT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sev-id) SEV_ID="$2"; shift 2 ;;
    --cron) CRON="$2"; shift 2 ;;
    --signal) SIGNAL="$2"; shift 2 ;;
    --signal-class) SCLASS="$2"; shift 2 ;;
    --confidence) CONF="$2"; shift 2 ;;
    --validator-outcome) VOUT="$2"; shift 2 ;;
    --suggested-owner) OWNER="$2"; shift 2 ;;
    --auto-tag-applied) ATAG="$2"; shift 2 ;;
    --auto-tag-stuck) ASTUCK="$2"; shift 2 ;;
    --final-status) FSTATUS="$2"; shift 2 ;;
    --root-cause-area) RCAREA="$2"; shift 2 ;;
    --notification-text) NTEXT="$2"; shift 2 ;;
    --class) CLASS="$2"; shift 2 ;;                  # diagnosis class (REAL_OT_FAILURE/UPSTREAM_INFRA/...)
    --code-mitigation) CMIT="$2"; shift 2 ;;         # task:T### | none:<reason> | (empty -> MISSING if code-rooted)
    --upstream-confirm) UCONF="$2"; shift 2 ;;        # ground-truth query/link confirming an UPSTREAM_INFRA root (P-017); (empty -> MISSING if class=UPSTREAM_INFRA)
    --routed-to) RTO="$2"; shift 2 ;;                 # auto (bot handled it) | human (popped to TEAM space for a human) — the escalation metric
    --root-cause-at) RCAT="$2"; shift 2 ;;            # 'now' or 'YYYY-MM-DD HH:MM:SS' — when RCA was identified; feeds time-to-root-cause (metric #1)
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$SEV_ID" && -n "$CRON" ]] || { echo "need --sev-id and --cron" >&2; exit 2; }

NOW=$(date '+%Y-%m-%d %H:%M:%S')   # match existing rows' format (no tz, no microseconds)
sqlesc() { printf '%s' "$1" | sed "s/'/''/g"; }   # SQL single-quote escape
[[ "$RCAT" == "now" || "$RCAT" == "NOW" ]] && RCAT="$NOW"   # 'now' -> wall-clock stamp

# CODE-MITIGATION GATE — deterministic enforcement layer (2026-06-11, operator "which layer
# to patch"). The monitors' in-prompt gate can be skipped under triage focus; this is the
# un-skippable code chokepoint every monitor already calls. A CODE-ROOTED verdict
# (class REAL_OT_FAILURE / UPSTREAM_INFRA) MUST carry a --code-mitigation decision
# (task:T### auto-filed, or none:<reason>). If absent -> record MISSING + WARN loudly so the
# gap is captured deterministically (ot-triage-auditor flags MISSING rows -> the "I lagged"
# detector). NON-FATAL: never break the substrate write. Backward-compatible: callers that
# pass no --class are unaffected (CMIT stays empty -> NULL).
if [[ -z "$CMIT" ]] && printf '%s' "$CLASS" | grep -qiE 'REAL_OT_FAILURE|UPSTREAM_INFRA'; then
  CMIT="MISSING"
  echo "WARN: code-rooted verdict (class=$CLASS, $SEV_ID) recorded WITHOUT --code-mitigation -> code_mitigation=MISSING. The Code-Mitigation Auto-Fix Gate was skipped: either file an [OT auto-fix] task and pass --code-mitigation task:T###, or pass --code-mitigation none:<reason>." >&2
fi
# UPSTREAM observability (2026-06-11, operator "for upstream infra improve observability —
# a query/log link that confirms it's the upstream issue. very valuable"). An UPSTREAM_INFRA
# verdict MUST carry a ground-truth confirm artifact (the P-017 decisive query/link: the
# upstream SEV, the ODS/canvas metric, the Scuba query). Missing -> record MISSING + WARN so
# "it's upstream" is never an unverifiable hand-wave. NON-FATAL; backward-compatible.
if [[ -z "$UCONF" ]] && printf '%s' "$CLASS" | grep -qiE 'UPSTREAM_INFRA'; then
  UCONF="MISSING"
  echo "WARN: UPSTREAM_INFRA verdict ($SEV_ID) recorded WITHOUT --upstream-confirm -> upstream_confirm=MISSING. Attribute the upstream root from GROUND TRUTH: pass a runnable query or resolvable link (upstream SEV / ODS-canvas metric / Scuba query) that confirms it (P-017 decisive metric)." >&2
fi
# Ensure the additive columns exist (idempotent; readers ignore unknown columns).
sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('triage_events') WHERE name='code_mitigation';" 2>/dev/null | grep -q 1 \
  || sqlite3 "$DB" "ALTER TABLE triage_events ADD COLUMN code_mitigation TEXT;" 2>/dev/null || true
sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('triage_events') WHERE name='upstream_confirm';" 2>/dev/null | grep -q 1 \
  || sqlite3 "$DB" "ALTER TABLE triage_events ADD COLUMN upstream_confirm TEXT;" 2>/dev/null || true
sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('triage_events') WHERE name='routed_to';" 2>/dev/null | grep -q 1 \
  || sqlite3 "$DB" "ALTER TABLE triage_events ADD COLUMN routed_to TEXT;" 2>/dev/null || true
sqlite3 "$DB" "SELECT 1 FROM pragma_table_info('triage_events') WHERE name='ts_root_cause';" 2>/dev/null | grep -q 1 \
  || sqlite3 "$DB" "ALTER TABLE triage_events ADD COLUMN ts_root_cause TEXT;" 2>/dev/null || true

sqlite3 "$DB" "INSERT INTO triage_events
  (sev_id, cron_job_id, signal, signal_class, confidence, auto_tag_applied,
   auto_tag_stuck, validator_outcome, suggested_owner, sev_final_status,
   sev_final_root_cause_area, notification_text, code_mitigation, upstream_confirm, routed_to, ts_root_cause, ts_created, ts_notified)
  VALUES (
   '$(sqlesc "$SEV_ID")', '$(sqlesc "$CRON")', '$(sqlesc "$SIGNAL")',
   '$(sqlesc "$SCLASS")', $([ -n "$CONF" ] && echo "$CONF" || echo NULL),
   ${ATAG:-0}, ${ASTUCK:-0},
   $([ -n "$VOUT" ] && echo "'$(sqlesc "$VOUT")'" || echo NULL),
   $([ -n "$OWNER" ] && echo "'$(sqlesc "$OWNER")'" || echo NULL),
   $([ -n "$FSTATUS" ] && echo "'$(sqlesc "$FSTATUS")'" || echo NULL),
   $([ -n "$RCAREA" ] && echo "'$(sqlesc "$RCAREA")'" || echo NULL),
   $([ -n "$NTEXT" ] && echo "'$(sqlesc "$NTEXT")'" || echo NULL),
   $([ -n "$CMIT" ] && echo "'$(sqlesc "$CMIT")'" || echo NULL),
   $([ -n "$UCONF" ] && echo "'$(sqlesc "$UCONF")'" || echo NULL),
   $([ -n "$RTO" ] && echo "'$(sqlesc "$RTO")'" || echo NULL),
   $([ -n "$RCAT" ] && echo "'$(sqlesc "$RCAT")'" || echo NULL),
   '$NOW', '$NOW');" \
  && echo "triage_events: recorded $SEV_ID ($CRON)" >&2
