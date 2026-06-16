#!/usr/bin/env bash
# REVIVED 2026-06-13 (Denny: AI Playbook gdoc going stale; daily push restored). Deprecated 2026-06-01→2026-06-13.
# cron-ai-health.sh — Daily unified AI health dashboard.
#
# Aggregates all observability signals into one scannable AI-HEALTH.md.
# Answers "is the system healthy?" by checking one file instead of four.
#
# Schedule: Daily 6:15 AM (after ai-audit at 6 AM)
# Crontab entry:
#   15 6 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 300 ai-health ~/work/claude/scripts/cron-ai-health.sh >> ~/logs/ai-health.log 2>&1

# NOTE: pipefail intentionally OFF. This is a reporting script full of
# `var=$(... | grep X | wc -l)` patterns; grep returning 1 on no-match would
# otherwise abort the whole run under set -e (the bug that kept it dead while
# deprecated metrics dried to 0). set -e still guards genuine command failures.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
OUTPUT="$REPO_DIR/context/cache/AI-HEALTH.md"
RUNTIME_CSV="$HOME/logs/cron-runtime.csv"
AUTOLEARN_LOG="$REPO_DIR/state/autolearn-metrics.csv"

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/gdocs_lib.sh"
source "$SCRIPT_DIR/lib/cron-helpers.sh"

# Truncate stdin at a word boundary (max N chars, default 120).
# Avoids mid-word cuts that create incomplete cell text like "prior d".
truncate_at_word() {
    local max="${1:-120}"
    awk -v max="$max" '{ if(length>max) { for(i=NF;i>0;i--) { s=$1; for(j=2;j<=i;j++) s=s" "$j; if(length(s)<=max) { print s; exit } } } else print }'
}
# Auto-recover google-mux before any gdocs calls
ensure_gmux_healthy || echo "[WARN] google-mux unhealthy — gdocs calls may fail"

echo "$LOG_PREFIX === Harness Health Dashboard ==="

# ─── Load staleness monitoring disabled list ──────────────────────────────────
# Docs in this list are excluded from staleness alerts in the dashboard.
STALENESS_DISABLED_NAMES=()
if [ -f "$REPO_DIR/config/DAILY-DOCS.json" ]; then
    while IFS= read -r _dname; do
        [ -n "$_dname" ] && STALENESS_DISABLED_NAMES+=("$_dname")
    done < <(python3 -c "
import json
with open('$REPO_DIR/config/DAILY-DOCS.json') as f:
    cfg = json.load(f)
disabled_ids = set(cfg.get('staleness_monitoring_disabled', []))
for key, doc in cfg.get('docs', {}).items():
    if doc.get('id') in disabled_ids:
        print(doc.get('name', key))
" 2>/dev/null)
fi

seven_days_ago=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d')
fourteen_days_ago=$(date -d '14 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-14d '+%Y-%m-%d')

# ─── Signal 1-3: Fleet stats ─────────────────────────────────────────────────
fleet_total=0; fleet_pass=0; fleet_rate=0
prev_total=0; prev_pass=0; prev_fleet_rate=0
timeout_errors=0; transient_errors=0; other_errors=0; other_breakdown=""; error_learnings="(none)"
distinct_jobs=0
all_jobs=""; budget_warnings=0; budget_warning_jobs=""

# Count registered cron jobs (from crontab, excluding keepalive and comments)
registered_jobs=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep "cron_run" | grep -v "keepalive" | wc -l)

if [ -f "$RUNTIME_CSV" ]; then
    fleet_total=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" '$1 >= since && $2 != "keepalive" {c++} END {print c+0}')
    fleet_pass=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" '$1 >= since && $2 != "keepalive" && $3 == 0 {c++} END {print c+0}')
    timeout_errors=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" '$1 >= since && $2 != "keepalive" && $3 == 124 {c++} END {print c+0}')
    transient_errors=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" '$1 >= since && $2 != "keepalive" && $3 == 0 && $5 == 2 {c++} END {print c+0}')
    distinct_jobs=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" '$1 >= since && $2 != "keepalive" {j[$2]=1} END {for(k in j) n++; print n+0}')
    prev_total=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$fourteen_days_ago" -v until="$seven_days_ago" '$1 >= since && $1 < until && $2 != "keepalive" {c++} END {print c+0}')
    prev_pass=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$fourteen_days_ago" -v until="$seven_days_ago" '$1 >= since && $1 < until && $2 != "keepalive" && $3 == 0 {c++} END {print c+0}')

    # All jobs: pass rate, duration, budget stats
    all_jobs_raw=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" \
        '$1 >= since && $2 != "keepalive" {
            total[$2]++; if ($3 == 0) pass[$2]++
            dur[$2]+=$4; if ($4+0 > max[$2]+0) max[$2]=$4
        } END {
            for (j in total) {
                rate=int(pass[j]*100/total[j])
                avg=int(dur[j]/total[j])
                printf "%s\t%d\t%d\t%d\t%d\n", j, total[j], rate, avg, max[j]
            }
        }')

    # Detect jobs in crontab that never ran in 7 days (single pass)
    missing_jobs=""
    ran_jobs=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" '$1 >= since && $2 != "keepalive" {j[$2]=1} END {for(k in j) print k}')
    while IFS= read -r cron_job; do
        [ -z "$cron_job" ] && continue
        job_name=$(echo "$cron_job" | grep -oP 'cron_run \d+ \K\S+')
        [ -z "$job_name" ] && continue
        [ "$job_name" = "keepalive" ] && continue
        if ! echo "$ran_jobs" | grep -qx "$job_name"; then
            missing_jobs="${missing_jobs:+$missing_jobs, }$job_name"
        fi
    done < <(crontab -l 2>/dev/null | grep "cron_run" | grep -v "^#")

    # Job descriptions — shown in dashboard to distinguish similar-sounding jobs
    # (added 2026-04-06: people-gdoc-sync vs project-gdoc-sync were indistinguishable)
    declare -A job_descriptions
    job_descriptions["people-gdoc-sync"]="Sync people profiles (1:1 prep, communication style) → People Context Doc"
    job_descriptions["project-gdoc-sync"]="Sync project state (tasks, goals, data sources) → Project Context Doc"
    job_descriptions["people-refresh"]="Re-fetch people profiles from calendar/GChat activity"
    job_descriptions["project-tier-assign"]="Assign priority tiers to projects based on activity + goals"
    job_descriptions["nightly-routine"]="Generate daily routine doc (coaching, actions, meetings)"
    job_descriptions["area-monitor"]="Scan EM/TL area for SEVs, diffs, peer activity"
    job_descriptions["ot-support-triage"]="Auto-triage OT support cases, generate debug reports"
    job_descriptions["ai-health"]="Generate AI Health Dashboard (cron fleet, metrics)"
    job_descriptions["ai-audit"]="Audit harness health: fleet, context, experiments"
    job_descriptions["autolearn-corrections"]="Extract learnings from session corrections → AUTO-LEARNINGS.md"
    job_descriptions["morning-gchat"]="Send daily error summary to the briefing GChat space"
    job_descriptions["daily-housekeeping"]="Prune stale files, check repo size, enforce budgets"
    job_descriptions["daily-progress"]="Generate daily progress summary for work tracking"
    job_descriptions["knowledge-distiller"]="Distill research into reusable knowledge entries"
    job_descriptions["self-improve"]="Run self-improvement prompts, apply learnings"
    job_descriptions["audit-agent"]="Audit cron fleet health, flag anomalies"
    job_descriptions["diff-autolearn"]="Auto-extract learnings from landed diffs"
    job_descriptions["keepalive"]="Health probe — keeps MyClaw daemon alive"
    job_descriptions["meeting-prep"]="Prepare meeting briefs from calendar + people context"
    job_descriptions["weekly-report"]="Generate weekly status report across all projects"
    job_descriptions["context-gc"]="Garbage-collect stale context files, free disk space"
    job_descriptions["gdoc-comments-critical"]="Process critical Google Doc comments: classify, act, reply"
    job_descriptions["context-expire-weekly"]="Dump portable cross-AI context snapshot → PORTABLE-CONTEXT.md (weekly: Sunday 11 PM)"
    job_descriptions["ai-infra-reliability-miner"]="Monthly: mine SEVs/wikis/Workplace for AI-infra reliability learnings → PATH-TO-EXPERT.md + Domain Prep gdoc"

    # Build timeout lookup and all-jobs table with duration stats
    declare -A job_timeouts
    while IFS= read -r cron_entry; do
        [ -z "$cron_entry" ] && continue
        t_timeout=$(echo "$cron_entry" | grep -oP 'cron_run \K\d+')
        t_name=$(echo "$cron_entry" | grep -oP 'cron_run \d+ \K\S+')
        [ -n "$t_name" ] && [ -n "$t_timeout" ] && job_timeouts[$t_name]=$t_timeout
    done < <(crontab -l 2>/dev/null | grep "cron_run" | grep -v "^#")

    budget_warnings=0
    declare -a bw_names=() bw_maxes=() bw_timeouts=() bw_pcts=() bw_avgs=()
    all_jobs=""
    while IFS=$'\t' read -r jname jruns jrate javg jmax; do
        [ -z "$jname" ] && continue
        jtimeout=${job_timeouts[$jname]:-0}
        budget_pct=0
        if [ "$jtimeout" -gt 0 ]; then
            budget_pct=$((jmax * 100 / jtimeout))
            if [ "$budget_pct" -ge 80 ]; then
                budget_warnings=$((budget_warnings + 1))
                budget_warning_jobs="${budget_warning_jobs:+$budget_warning_jobs, }${jname} (${budget_pct}%)"
                bw_names+=("$jname"); bw_maxes+=("$jmax"); bw_timeouts+=("$jtimeout")
                bw_pcts+=("$budget_pct"); bw_avgs+=("$javg")
            fi
        fi
        jstatus="GREEN"
        [ "$jrate" -lt 90 ] && jstatus="YELLOW"
        [ "$jrate" -lt 50 ] && jstatus="RED"
        [ "$budget_pct" -ge 80 ] && [ "$jstatus" = "GREEN" ] && jstatus="YELLOW"
        # If last run failed, force RED regardless of 7d aggregate
        last_exit=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v job="$jname" '$2 == job {code=$3} END {print code+0}')
        [ "$last_exit" -ne 0 ] 2>/dev/null && jstatus="RED"
        dur_info="${javg}s avg, ${jmax}/${jtimeout}s max"
        # Detail column: explain what's wrong for non-GREEN jobs (no redundant pass rate — separate column)
        jdetail=""
        if [ "$jstatus" != "GREEN" ]; then
            [ "$budget_pct" -ge 80 ] && jdetail="duration ${budget_pct}% of timeout"
            # Get last error: exit code + error snippet from log
            last_err=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" -v job="$jname" '$1 >= since && $2 == job && $3 != 0 {code=$3} END {if(code) print "exit " code}')
            if [ -n "$last_err" ]; then
                # Pull REAL error from job log — exclude cron-alert wrapper summaries
                # (those just echo "2 attempts failed: attempt1=exit" which hides the root cause)
                log_file="$HOME/logs/${jname}.log"
                err_msg=""
                if [ -f "$log_file" ]; then
                    err_msg=$(grep -i "ERROR\|FAIL\|exception\|Traceback\|killed\|OOM\|timeout\|TIMEOUT\|No such file\|Permission denied\|not found" "$log_file" 2>/dev/null \
                        | grep -viE "\[cron_run\]|\[diagnose\]|\[cron-alert\]|Alert written to ALERTS\.md|attempts failed:" \
                        | tail -1 \
                        | sed 's/^[0-9-]* [0-9:]* //' \
                        | sed 's/^\[[^]]*\] //' \
                        | sed 's/|/;/g' \
                        | awk '{ if(length>120) { for(i=NF;i>0;i--) { s=$1; for(j=2;j<=i;j++) s=s" "$j; if(length(s)<=120) { print s; exit } } } else print }' \
                        || true)
                fi
                if [ -n "$err_msg" ]; then
                    jdetail="${jdetail:+$jdetail; }${last_err}: ${err_msg}"
                else
                    jdetail="${jdetail:+$jdetail; }${last_err} (see ~/logs/${jname}.log)"
                fi
            fi
        fi
        # Last run info: ✓ only if exit=0, ✗ if failed — use exit_code variable (not $3 which is empty in END block)
        last_run_info=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v job="$jname" '$2 == job {date=$1; exit_code=$3} END {if(date) printf "%s %s", (exit_code==0?"✓":"✗"), date}')
        # For GREEN jobs, show description so similar-sounding jobs are distinguishable
        jdesc="${job_descriptions[$jname]:-}"
        if [ "$jstatus" = "GREEN" ] && [ -n "$jdesc" ] && [ -z "$jdetail" ]; then
            jdetail="$jdesc"
        fi
        last_run_detail="${last_run_info:-—}"
        [ -n "$jdetail" ] && last_run_detail="${last_run_detail} — ${jdetail}"
        pass_dur="${jrate}% (${javg}s avg)"
        all_jobs="${all_jobs}| ${jname} | ${jstatus} | ${jruns} | ${last_run_detail} | ${pass_dur} |\n"
    done < <(echo "$all_jobs_raw" | sort)

    # Add missing jobs (in crontab but never ran)
    # PLAYBOOK RULE 13: specific name + purpose + root cause
    # PLAYBOOK RULE 20: weekly/monthly jobs show PENDING (YELLOW) instead of RED
    #   before their first scheduled occurrence, if their heartbeat is still fresh.
    declare -A _miss_dow _miss_hour _miss_dom
    while IFS= read -r _mce; do
        [ -z "$_mce" ] && continue
        _mjn=$(echo "$_mce" | grep -oP 'cron_run \d+ \K\S+')
        [ -z "$_mjn" ] && continue
        _miss_dow[$_mjn]=$(echo "$_mce" | awk '{print $5}')
        _miss_hour[$_mjn]=$(echo "$_mce" | awk '{print $2}')
        _miss_dom[$_mjn]=$(echo "$_mce" | awk '{print $3}')
    done < <(crontab -l 2>/dev/null | grep "cron_run" | grep -v "^#")

    for jname in "${!job_timeouts[@]}"; do
        [ "$jname" = "keepalive" ] && continue
        if ! echo "$all_jobs_raw" | grep -q "^${jname}	"; then
            jtimeout=${job_timeouts[$jname]}
            jdesc="${job_descriptions[$jname]:-}"
            _jdow=${_miss_dow[$jname]:-"*"}
            _jhour=${_miss_hour[$jname]:-"0"}
            _jdom=${_miss_dom[$jname]:-"*"}
            _jperiodic=false
            [ "$_jdow" != "*" ] || [ "$_jdom" != "*" ] && _jperiodic=true

            # Check heartbeat freshness
            _jhb="$HEARTBEAT_DIR/cron-heartbeat-${jname}"
            _jhb_fresh=false
            _jhb_last=""
            if [ -f "$_jhb" ]; then
                _jhb_ts=$(cat "$_jhb" 2>/dev/null | grep -oE '^[0-9]+$' | head -1 || echo "0")
                if [ "${_jhb_ts:-0}" -gt 0 ]; then
                    _jhb_age=$(( $(date +%s) - _jhb_ts ))
                    _jhb_thresh=172800
                    $_jperiodic && _jhb_thresh=691200
                    [ "$_jhb_age" -lt "$_jhb_thresh" ] && _jhb_fresh=true
                    _jhb_last=$(date -d "@${_jhb_ts}" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
                fi
            fi

            if $_jperiodic && $_jhb_fresh; then
                # RULE 20: periodic job with fresh heartbeat → PENDING (YELLOW)
                _dow_names=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
                if echo "$_jdow" | grep -qE '^[0-6]$'; then
                    _dow_label="${_dow_names[$_jdow]}"
                elif [ "$_jdow" = "1-5" ]; then
                    _dow_label="Mon-Fri"
                else
                    _dow_label="$_jdow"
                fi
                jdetail="${jdesc:+$jdesc — }PENDING — next run: ${_dow_label} ${_jhour}:00 (last: ${_jhb_last})"
                all_jobs="${all_jobs}| ${jname} | YELLOW | 0 | ${jdetail} | — (${jtimeout}s limit) |\n"
            else
                # Root-cause diagnosis: why isn't this job running?
                jscript="$SCRIPT_DIR/cron-${jname}.sh"
                [ ! -f "$jscript" ] && jscript="$SCRIPT_DIR/${jname}.sh"
                if [ ! -f "$jscript" ]; then
                    jroot="script missing: cron-${jname}.sh / ${jname}.sh"
                elif [ -f "$HOME/logs/${jname}.log" ]; then
                    jroot=$(grep -i "ERROR\|FAIL\|permission denied\|not found\|killed" "$HOME/logs/${jname}.log" 2>/dev/null \
                        | tail -1 | sed 's/^[0-9-]* [0-9:]* //' | sed 's/^\[.*\] //' | sed 's/|/;/g' | head -c 60 || true)
                    [ -z "$jroot" ] && jroot="registered but 0 runs in 7d"
                else
                    jroot="no log file — may never have started"
                fi
                jdetail="${jdesc:+$jdesc — }${jroot}"
                all_jobs="${all_jobs}| ${jname} | RED | 0 | ${jdetail} | — (${jtimeout}s limit) |\n"
            fi
        fi
    done

    # ─── Write FOLLOWUPS.md entries for budget-warning jobs ──────────────
    FOLLOWUPS_FILE="$REPO_DIR/FOLLOWUPS.md"
    if [ "$budget_warnings" -gt 0 ] && [ -f "$FOLLOWUPS_FILE" ]; then
        check_after=$(date -d '+7 days' '+%Y-%m-%d' 2>/dev/null || date -v+7d '+%Y-%m-%d')
        for i in "${!bw_names[@]}"; do
            bw_name="${bw_names[$i]}"
            bw_max="${bw_maxes[$i]}"
            bw_timeout="${bw_timeouts[$i]}"
            bw_pct="${bw_pcts[$i]}"
            bw_avg="${bw_avgs[$i]}"
            # Determine recommended action
            if [ "$bw_pct" -ge 95 ]; then
                bw_action="increase timeout"
            elif [ "$bw_pct" -ge 90 ]; then
                bw_action="split or increase timeout"
            else
                bw_action="optimize runtime"
            fi
            # Emit a remediation PROPOSAL when timeout-saturated (>=95%). ai-health
            # only writes intent to the queue; cron-remediator's gate validates +
            # applies it deterministically (intent->validate->apply). See
            # cron/remediation-gate-design.md.
            if [ "$bw_pct" -ge 95 ]; then
                _rq="$REPO_DIR/state/remediation/queue"; mkdir -p "$_rq"
                _new=$(( bw_timeout * 2 )); [ "$_new" -gt 3600 ] && _new=3600
                if [ "$_new" -gt "$bw_timeout" ] && [ ! -f "$_rq/timeout-${bw_name}.json" ]; then
                    printf '{"id":"timeout-%s","job":"%s","change_type":"timeout_bump","from":{"timeout":%s},"to":{"timeout":%s},"reason":"budget %s%% (%ss max / %ss)","proposed_by":"ai-health"}\n' \
                        "$bw_name" "$bw_name" "$bw_timeout" "$_new" "$bw_pct" "$bw_max" "$bw_timeout" > "$_rq/timeout-${bw_name}.json"
                    echo "$LOG_PREFIX   [propose] timeout_bump ${bw_name}: ${bw_timeout}->${_new}"
                fi
            fi
            # Skip if already tracked
            if ! grep -q "budget warning: ${bw_name}" "$FOLLOWUPS_FILE" 2>/dev/null; then
                entry="| ${TODAY} | ${check_after} | [infra] Cron budget warning: ${bw_name} — ${bw_avg}s avg, ${bw_max}s max / ${bw_timeout}s timeout (${bw_pct}%). Action: ${bw_action}. (Goal 2) | pending |"
                # Insert after first separator in Active section
                sed -i "0,/^|-------|-------------|------|--------|$/{/^|-------|-------------|------|--------|$/a\\
${entry}
}" "$FOLLOWUPS_FILE"
                echo "$LOG_PREFIX   FOLLOWUP added: ${bw_name} (${bw_pct}% of ${bw_timeout}s → ${bw_action})"
            fi
        done
    fi

    # Sort by status severity (RED first, then YELLOW, then GREEN)
    all_jobs=$(echo -e "$all_jobs" | grep "^|" | awk -F'|' '{
        s=$3; gsub(/ /,"",s)
        if (s=="RED") p=1; else if (s=="YELLOW") p=2; else if (s=="GREEN") p=4; else p=3
        print p"|"$0
    }' | sort -t'|' -k1,1n | cut -d'|' -f2-)

    [ "$fleet_total" -gt 0 ] && fleet_rate=$((fleet_pass * 100 / fleet_total))
    total_fail=$((fleet_total - fleet_pass))
    other_errors=$((total_fail - timeout_errors))
    [ "$other_errors" -lt 0 ] && other_errors=0
    # Break down non-timeout errors by exit code category, sorted by frequency, top 3
    if [ "$other_errors" -gt 0 ]; then
        other_breakdown=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" \
            '$1 >= since && $2 != "keepalive" && $3 != 0 && $3 != 124 {
                c = $3+0
                if (c == 1) name = "script-error"
                else if (c == 2) name = "usage-error"
                else if (c == 126) name = "permission"
                else if (c == 127) name = "cmd-not-found"
                else if (c == 137) name = "killed"
                else if (c == 139) name = "segfault"
                else name = "exit-" c
                count[name]++
            }
            END {
                n = 0
                for (k in count) { n++; cnt[n] = count[k]; nm[n] = k }
                for (i = 1; i <= n; i++)
                    for (j = i + 1; j <= n; j++)
                        if (cnt[j]+0 > cnt[i]+0) {
                            tc = cnt[i]; cnt[i] = cnt[j]; cnt[j] = tc
                            tn = nm[i]; nm[i] = nm[j]; nm[j] = tn
                        }
                s = ""
                top = (n < 3) ? n : 3
                for (i = 1; i <= top; i++) {
                    if (s != "") s = s ", "
                    s = s cnt[i] " " nm[i]
                }
                if (s != "") print s
            }')
    fi
    [ "$prev_total" -gt 0 ] && prev_fleet_rate=$((prev_pass * 100 / prev_total))

    # Individual error breakdown for Errors row detail — always show top 5 failing jobs
    error_detail=""
    if [ "$total_fail" -gt 0 ]; then
        error_detail=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" \
            '$1 >= since && $2 != "keepalive" && $3 != 0 {
                key=$2" (exit "$3")"
                count[key]++
            }
            END {
                n=0; for (k in count) {n++; print count[k] "\t" k}
            }' | sort -rn | head -5 | awk '{printf "%s×%d, ", $2, $1}' | sed 's/, $//')
    fi

    # ─── Error prevention learnings ──────────────────────────────────────────
    # Auto-generate prevention insights from error patterns
    error_learnings=""
    if [ "$timeout_errors" -gt 0 ]; then
        timeout_jobs=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" '$1 >= since && $2 != "keepalive" && $3 == 124 {print $2}' | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s(%d) ", $2, $1}')
        error_learnings="${error_learnings}Timeouts: ${timeout_jobs}— check if timeout limits need increase (autolearn experiments address this); "
    fi
    if [ "$other_errors" -gt 0 ]; then
        other_jobs=$(tail -n +2 "$RUNTIME_CSV" | awk -F, -v since="$seven_days_ago" '$1 >= since && $2 != "keepalive" && $3 != 0 && $3 != 124 {print $2}' | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s(%d) ", $2, $1}')
        error_learnings="${error_learnings}Script errors: ${other_jobs}— review logs for pipefail/grep traps; "
    fi
    if [ "$transient_errors" -gt 0 ]; then
        error_learnings="${error_learnings}Transient: recovered on retry (no action needed)"
    fi
    error_learnings="${error_learnings:-(none)}"
fi

# Week-over-week trend
if [ "$prev_total" -eq 0 ]; then
    fleet_trend="N/A (no prev week data)"
    fleet_delta=0
else
    fleet_delta=$((fleet_rate - prev_fleet_rate))
    fleet_trend="flat"
    [ "$fleet_delta" -gt 2 ] && fleet_trend="UP +${fleet_delta}%"
    [ "$fleet_delta" -lt -2 ] && fleet_trend="DOWN ${fleet_delta}%"
    fleet_trend="${fleet_trend} (this: ${fleet_rate}%, prev: ${prev_fleet_rate}%)"
fi

# ─── Signal 4: AI Audit Score (with dimension breakdown) ────────────────────
audit_score="UNKNOWN"
audit_dims=""
audit_file="$REPO_DIR/context/cache/AI-AUDIT-REPORT.md"
if [ -f "$audit_file" ]; then
    audit_score=$(grep "Fleet Health" "$audit_file" | head -1 | grep -oE 'GREEN|YELLOW|RED' || echo "UNKNOWN")
    # Extract non-GREEN dimensions for quick visibility
    audit_dims=$(grep -E "^\| .* \| (YELLOW|RED) \|" "$audit_file" 2>/dev/null | awk -F'|' '{gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$4); if ($4 != "") printf "%s: %s; ", $2, $4}' | sed 's/; $//' | head -c 300 || true)
fi

# ─── Signal 5: Active Alerts (with names) ──────────────────────────────────
active_alerts=0
alert_names=""
if [ -f "$REPO_DIR/ALERTS.md" ]; then
    active_alerts=$(grep -c "^\- \*\*" "$REPO_DIR/ALERTS.md" 2>/dev/null) || active_alerts=0
    alert_names=$(grep "^\- \*\*" "$REPO_DIR/ALERTS.md" 2>/dev/null | grep -oP '\[cron:[^\]]+\]' | tr -d '[]' | sed 's/cron://g' | paste -sd ", " - || true)
fi

# ─── Signal 6: Routine Effectiveness (with per-dimension gap analysis) ─────
routine_score="N/A"
routine_file="$REPO_DIR/context/cache/ROUTINE-EFFECTIVENESS.md"
if [ -f "$routine_file" ]; then
    routine_score=$(tail -1 "$routine_file" | grep -oE '[0-9]+' | tail -1 || echo "N/A")
fi

# Per-dimension gap analysis (PLAYBOOK RULE 5)
# When routine_score < 75, identify failing dimensions and map to rules
routine_gap_analysis=""
routine_dims_file="$REPO_DIR/context/cache/state/ROUTINE-DIMENSIONS.json"
if [ -f "$routine_dims_file" ] && [ "$routine_score" != "N/A" ] && [ "$routine_score" -lt 75 ] 2>/dev/null; then
    routine_gap_analysis=$(python3 -c "
import json, sys

# Dimension-to-rule mapping: which protocol rule governs each dimension
DIM_RULES = {
    'date_correctness': ('PROTOCOL-ROUTINE date handling', 'Fix LLM prompt date injection or JSON date field'),
    'actions': ('PROTOCOL-ROUTINE Actions section', 'Ensure RIGHT NOW + DEEP WORK priorities in action list'),
    'goal_references': ('PROTOCOL-ROUTINE Goal alignment', 'Reference Goal 1-4 in action items and coaching'),
    'ic7_score': ('PROTOCOL-ROUTINE Coaching > IC7', 'Add IC7 SCORE row to coaching section'),
    'coaching': ('PROTOCOL-ROUTINE Coaching section', 'Generate 2+ coaching insights per digest'),
    'meetings': ('PROTOCOL-ROUTINE Meetings section', 'Include prep notes for all calendar meetings'),
    'cache_fields': ('PROTOCOL-ROUTINE Cache section', 'Populate daily_digest_summary, comms_tips, meeting_actions, stale_tasks'),
    'evidence_links': ('PROTOCOL-ROUTINE Evidence links', 'Include 3+ D/T artifact links in output'),
    'word_count': ('PROTOCOL-ROUTINE Output format', 'Keep digest output between 200-2000 words'),
}

with open('$routine_dims_file') as f:
    data = json.load(f)

dims = data.get('dimensions', {})
rows = []
for dim_key, dim_val in sorted(dims.items(), key=lambda x: x[1].get('earned', 0)):
    earned = dim_val.get('earned', 0)
    max_pts = dim_val.get('max', 0)
    # A dimension is failing if earned < max (not at full score)
    if earned < max_pts:
        rule, fix = DIM_RULES.get(dim_key, ('(unmapped)', 'Review generation code'))
        detail = dim_val.get('detail', '')
        rows.append(f'| {dim_key} | {earned}/{max_pts} | {rule} | {fix} | {detail} |')

if rows:
    for r in rows:
        print(r)
" 2>/dev/null || true)
fi

# ─── Signal 7: Heartbeat Freshness (frequency-aware, deduplicated) ────────
stale_heartbeats=0
total_heartbeats=0
stale_hb_names=""
declare -A seen_hb
# Build frequency lookup: weekly/monthly jobs get 8-day threshold, daily gets 2-day
declare -A hb_threshold
while IFS= read -r cron_entry; do
    [ -z "$cron_entry" ] && continue
    jn=$(echo "$cron_entry" | grep -oP 'cron_run \d+ \K\S+')
    [ -z "$jn" ] && continue
    dow=$(echo "$cron_entry" | awk '{print $5}')
    dom=$(echo "$cron_entry" | awk '{print $3}')
    if [ "$dom" != "*" ] && [ "$dow" = "*" ]; then
        hb_threshold[$jn]=3456000  # monthly (day-of-month pinned): 40 days
    elif [ "$dow" != "*" ] || [ "$dom" != "*" ]; then
        hb_threshold[$jn]=691200   # weekly: 8 days
    else
        hb_threshold[$jn]=172800   # daily: 2 days
    fi
done < <(crontab -l 2>/dev/null | grep "cron_run" | grep -v "^#")

for hb in $HEARTBEAT_DIR/cron-heartbeat-* /tmp/cron-heartbeat-*; do
    [ -f "$hb" ] || continue
    job_name=$(basename "$hb" | sed 's/cron-heartbeat-//')
    [ -n "${seen_hb[$job_name]:-}" ] && continue
    seen_hb[$job_name]=1
    total_heartbeats=$((total_heartbeats + 1))
    hb_ts=$(cat "$hb" 2>/dev/null | grep -oE '^[0-9]+$' | head -1 || echo "0")
    [ -z "$hb_ts" ] && hb_ts=0
    [ "$hb_ts" -eq 0 ] && continue  # skip corrupt/empty heartbeat files
    hb_age=$(( $(date +%s) - hb_ts ))
    threshold=${hb_threshold[$job_name]:-172800}
    if [ "$hb_age" -gt "$threshold" ]; then
        stale_heartbeats=$((stale_heartbeats + 1))
        hb_days=$((hb_age / 86400))
        hb_last_updated=$(date -d "@${hb_ts}" '+%Y-%m-%d' 2>/dev/null || echo "unknown")
        stale_hb_names="${stale_hb_names:+$stale_hb_names, }${job_name}: ${hb_last_updated} (${hb_days}d ago)"
    fi
done

# ─── Signal 8: Context Freshness ────────────────────────────────────────────
stale_profiles=0
total_profiles=0
if [ -d "$REPO_DIR/context/people" ]; then
    total_profiles=$(find "$REPO_DIR/context/people" -name "*.md" ! -name "README.md" ! -name "TEMPLATE.md" ! -name "IC7-WATCHLIST.md" | wc -l)
    stale_profiles=$(find "$REPO_DIR/context/people" -name "*.md" ! -name "README.md" ! -name "TEMPLATE.md" ! -name "IC7-WATCHLIST.md" -mtime +14 | wc -l)
    stale_profile_names=$(
        _now=$(date +%s)
        find "$REPO_DIR/context/people" -name "*.md" ! -name "README.md" ! -name "TEMPLATE.md" ! -name "IC7-WATCHLIST.md" -mtime +14 -printf '%T@ %f\n' 2>/dev/null \
        | sort -t' ' -k2 \
        | while read mtime fname; do
            name="${fname%.md}"
            mtime_int="${mtime%.*}"
            days_ago=$(( (_now - mtime_int) / 86400 ))
            last_updated=$(date -d "@${mtime_int}" '+%Y-%m-%d' 2>/dev/null || echo "unknown")
            echo "${name}: ${last_updated} (${days_ago}d ago)"
        done \
        | paste -sd ", " - 2>/dev/null || true
    )
fi

stale_cache=0
stale_cache_names=""
for output in MEETING-PREP-TODAY.md OT-SUPPORT-TRIAGE.md AREA-MONITOR.md GCHAT-COPILOT-METRICS.json; do
    f="$REPO_DIR/context/cache/$output"
    [ "$output" = "GCHAT-COPILOT-METRICS.json" ] && f="$REPO_DIR/context/cache/state/$output"
    if [ -f "$f" ]; then
        age=$(( ($(date +%s) - $(stat -c %Y "$f")) / 86400 ))
        if [ "$age" -gt 3 ]; then
            stale_cache=$((stale_cache + 1))
            cache_last_updated=$(date -d "@$(stat -c %Y "$f")" '+%Y-%m-%d' 2>/dev/null || echo "unknown")
            stale_cache_names="${stale_cache_names:+$stale_cache_names, }${output}: ${cache_last_updated} (${age}d ago)"
        fi
    else
        stale_cache=$((stale_cache + 1))
        stale_cache_names="${stale_cache_names:+$stale_cache_names, }${output} (missing)"
    fi
done

oversized_cs=0
oversized_cs_names=""
while IFS= read -r cs; do
    [ -z "$cs" ] && continue
    lines=$(wc -l < "$cs")
    if [ "$lines" -gt 500 ]; then
        oversized_cs=$((oversized_cs + 1))
        cs_rel=$(basename "$cs")
        oversized_cs_names="${oversized_cs_names:+$oversized_cs_names, }${cs_rel} (${lines}L)"
    fi
done < <(find "$REPO_DIR/cheatsheets" -name "*.md" 2>/dev/null)

# ─── Signal 9: Autolearn Rules ──────────────────────────────────────────────
autolearn_week=0
autolearn_ch_detail=""
if [ -f "$AUTOLEARN_LOG" ]; then
    autolearn_week=$(tail -n +1 "$AUTOLEARN_LOG" | awk -F, -v since="$seven_days_ago" '$1 >= since' | wc -l)
    # Only show channels that produced rules (skip zeros)
    autolearn_ch_detail=$(tail -n +1 "$AUTOLEARN_LOG" | awk -F, -v since="$seven_days_ago" '
        $1 >= since { ch[$2]++ }
        END { s=""; for (c in ch) { if (s!="") s=s" "; s=s c":"ch[c] } print s }')
fi
autolearn_rules=$(grep -rc "autolearn" "$REPO_DIR/cheatsheets/" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
# Prepend doc-comments to breakdown (tracked in AUTOLEARN-CHANGELOG, not autolearn-metrics.csv)
if [ -f "$REPO_DIR/context/cache/AUTOLEARN-CHANGELOG.md" ]; then
    gdoc_learnings=$(grep "^|" "$REPO_DIR/context/cache/AUTOLEARN-CHANGELOG.md" | grep -v "^| #\|^|---" | awk -F'|' '{gsub(/ /,"",$3)} $3>=seven_days_ago' seven_days_ago="$seven_days_ago" | grep -i "comment\|gdoc\|doc" | wc -l | xargs)
    [ "${gdoc_learnings:-0}" -gt 0 ] && autolearn_ch_detail="doc-comments:${gdoc_learnings}${autolearn_ch_detail:+ ${autolearn_ch_detail}}"
fi

# ─── Signal 10: Self-Improve Experiments ─────────────────────────────────────
active_experiments=0
applied_experiments=0
unsafe_experiments=0
experiments_file="$REPO_DIR/context/cache/CRON-EXPERIMENTS.md"
if [ -f "$experiments_file" ]; then
    active_experiments=$(grep -c "Status.*: ACTIVE$" "$experiments_file" 2>/dev/null) || active_experiments=0
    applied_experiments=$(grep -c "Status.*APPLIED" "$experiments_file" 2>/dev/null) || applied_experiments=0
    unsafe_experiments=$(python3 -c "
import re
try:
    content = open('$experiments_file').read()
    count = 0
    for block in re.split(r'(?=### EXP-)', content):
        if not block.startswith('### EXP-'):
            continue
        is_unsafe = bool(re.search(r'Type.*UNSAFE', block))
        is_resolved = bool(re.search(r'Status.*(?:RESOLVED|APPLIED|COMPLETED)', block))
        if is_unsafe and not is_resolved:
            count += 1
    print(count)
except Exception:
    print(0)
" 2>/dev/null) || unsafe_experiments=0
fi

# ─── Signal 11: Correction Rate Trend ────────────────────────────────────────
correction_avg="N/A"
correction_trend=""
count_corr=0
METRICS_FILE="$REPO_DIR/context/cache/state/CLAUDE-SESSION-METRICS.md"
if [ -f "$METRICS_FILE" ]; then
    corrections_data=$(tail -20 "$METRICS_FILE" | grep "^|" | grep -v "Date\|---" | awk -F'|' '{gsub(/ /,"",$4); if ($4 ~ /^[0-9]+$/) print $4}')
    if [ -n "$corrections_data" ]; then
        total_corr=0; count_corr=0
        first_half=0; first_count=0; second_half=0; second_count=0
        for c in $corrections_data; do
            total_corr=$((total_corr + c))
            count_corr=$((count_corr + 1))
        done
        [ "$count_corr" -gt 0 ] && correction_avg="$(echo "scale=1; $total_corr / $count_corr" | bc 2>/dev/null || echo "$((total_corr / count_corr))")"
        # Compute trend: compare first half vs second half
        if [ "$count_corr" -ge 4 ]; then
            mid=$((count_corr / 2))
            i=0
            for c in $corrections_data; do
                i=$((i + 1))
                if [ "$i" -le "$mid" ]; then
                    first_half=$((first_half + c)); first_count=$((first_count + 1))
                else
                    second_half=$((second_half + c)); second_count=$((second_count + 1))
                fi
            done
            if [ "$first_count" -gt 0 ] && [ "$second_count" -gt 0 ]; then
                first_avg_10=$((first_half * 10 / first_count))
                second_avg_10=$((second_half * 10 / second_count))
                first_avg_str="$(echo "scale=1; $first_half / $first_count" | bc 2>/dev/null || echo "$((first_half / first_count))")"
                second_avg_str="$(echo "scale=1; $second_half / $second_count" | bc 2>/dev/null || echo "$((second_half / second_count))")"
                if [ "$second_avg_10" -lt "$first_avg_10" ]; then
                    correction_trend=" (improving: ${first_avg_str} → ${second_avg_str})"
                elif [ "$second_avg_10" -gt "$first_avg_10" ]; then
                    correction_trend=" (worsening: ${first_avg_str} → ${second_avg_str})"
                else
                    correction_trend=" (stable)"
                fi
            fi
        fi
    fi
fi

# ─── Signal 12: Error Pattern Fix Effectiveness ────────────────────────────
fix_effectiveness=""
error_db="$REPO_DIR/context/cache/ERROR-PATTERNS.json"
if [ -f "$error_db" ]; then
    fix_effectiveness=$(python3 -c "
import json
with open('$error_db') as f:
    db = json.load(f)
stats = db.get('fix_stats', {})
for cat, s in sorted(stats.items()):
    rate = int(s['successes'] / s['attempts'] * 100) if s['attempts'] > 0 else 0
    if rate >= 70:
        action = 'working'
    elif rate >= 30:
        action = 'review fix logic'
    else:
        action = 'add/rewrite handler in cron_diagnose_and_fix()'
    print(f'| {cat} | {s[\"attempts\"]} | {s[\"successes\"]} | {rate}% | {action} |')
" 2>/dev/null || true)
fi

# ─── Shadow mode: cross-check Python signal port (observe-only) ──────────
# Migration in progress (started 2026-04-20): private_scripts/lib/ai_health_signals.py
# is validated against bash signal blocks above. Wrapped in `|| true`.
{
    S4_AUDIT_FILE="$audit_file" \
    B4_SCORE="${audit_score:-UNKNOWN}" \
    B4_DIMS="${audit_dims:-}" \
    S5_ALERTS_MD="$REPO_DIR/ALERTS.md" \
    B5_ACTIVE="${active_alerts:-0}" \
    B5_NAMES="${alert_names:-}" \
    S6_ROUTINE_FILE="$routine_file" \
    S6_DIMS_FILE="$routine_dims_file" \
    B6_SCORE="${routine_score:-N/A}" \
    B6_GAP="${routine_gap_analysis:-}" \
    S7_HB_DIR="$HEARTBEAT_DIR" \
    S7_CRONTAB="$(crontab -l 2>/dev/null)" \
    B7_STALE="${stale_heartbeats:-0}" \
    B7_TOTAL="${total_heartbeats:-0}" \
    B7_NAMES="${stale_hb_names:-}" \
    S8_REPO_DIR="$REPO_DIR" \
    S8_CHEATSHEETS_DIR="$REPO_DIR/cheatsheets" \
    B8_STALE_CACHE="${stale_cache:-0}" \
    B8_STALE_CACHE_NAMES="${stale_cache_names:-}" \
    B8_OVERSIZED_CS="${oversized_cs:-0}" \
    B8_OVERSIZED_CS_NAMES="${oversized_cs_names:-}" \
    B8_STALE_PROFILES="${stale_profiles:-0}" \
    B8_TOTAL_PROFILES="${total_profiles:-0}" \
    B8_STALE_PROFILE_NAMES="${stale_profile_names:-}" \
    S9_METRICS_CSV="$AUTOLEARN_LOG" \
    S9_CHEATSHEETS_DIR="$REPO_DIR/cheatsheets" \
    S9_CHANGELOG_MD="$REPO_DIR/context/cache/AUTOLEARN-CHANGELOG.md" \
    S9_SINCE="$seven_days_ago" \
    B9_WEEK="${autolearn_week:-0}" \
    B9_DETAIL="${autolearn_ch_detail:-}" \
    B9_TOTAL="${autolearn_rules:-0}" \
    S10_EXP_FILE="$experiments_file" \
    B10_ACTIVE="${active_experiments:-0}" \
    B10_APPLIED="${applied_experiments:-0}" \
    B10_UNSAFE="${unsafe_experiments:-0}" \
    S11_METRICS_FILE="$METRICS_FILE" \
    B11_AVG="${correction_avg:-N/A}" \
    B11_TREND="${correction_trend:-}" \
    B11_COUNT="${count_corr:-0}" \
    S12_ERROR_DB="$error_db" \
    B12_ROWS="${fix_effectiveness:-}" \
    S13_RUNTIME_CSV="$RUNTIME_CSV" \
    S13_SINCE="$seven_days_ago" \
    S13_PREV_SINCE="$fourteen_days_ago" \
    S13_PREV_UNTIL="$seven_days_ago" \
    B13_TOTAL="${fleet_total:-0}" \
    B13_PASS="${fleet_pass:-0}" \
    B13_TIMEOUT="${timeout_errors:-0}" \
    B13_TRANSIENT="${transient_errors:-0}" \
    B13_DISTINCT="${distinct_jobs:-0}" \
    B13_PREV_TOTAL="${prev_total:-0}" \
    B13_PREV_PASS="${prev_pass:-0}" \
    B13_RATE="${fleet_rate:-0}" \
    B13_PREV_RATE="${prev_fleet_rate:-0}" \
    B13_OTHER="${other_breakdown:-}" \
    B13_ERR="${error_detail:-}" \
    B13_JOBS="${all_jobs_raw:-}" \
    python3 "$HOME/work/claude/private_scripts/lib/ai_health_signals_shadow.py" 2>&1 | sed "s/^/$LOG_PREFIX /"
} || true

# ─── Signal 13: Tab Content Freshness ──────────────────────────────────────
# Verify actual date-stamped content exists in regularly-updated gdoc tabs.
# Catches silent push failures where cron runs green but content never appears.
tab_content_status="GREEN"
tab_content_detail=""
# Per-tab expected_update_frequency_hours (PLAYBOOK RULE 3):
#   25h  = daily tab (absorbs ±1h cron scheduling drift)
#   48h  = tab updated ~daily but OK if a day late
#   168h = weekly / on-demand tab
# Post-merge (2026-06-01): area monitor is now tabs in the unified routine doc.
# Dead tabs removed: GChat Intelligence + Signal-to-Opportunity (feeders deprecated 2026-05-30).
content_checks_list=(
    "routine|t.0|Routine > Routine|25"
    "routine|t.7p1pm5er8oet|Routine > Org Monitor|25"
    "routine|t.n3cgnazi5bxp|Routine > AI Skill Monitor|25"
    "ai_playbook|t.0|AI Playbook > Health|25"
)
tc_today=$(TZ=America/Los_Angeles date +%Y-%m-%d)
tc_missing="" tc_ok=0 tc_checked=0
for tc_entry in "${content_checks_list[@]}"; do
    IFS='|' read -r tc_doc_key tc_tab_id tc_display tc_freq_hours <<< "$tc_entry"
    tc_checked=$((tc_checked + 1))
    tc_doc_id="$(get_doc_id "$tc_doc_key" 2>/dev/null)" || continue
    [ -z "$tc_doc_id" ] && continue
    # Build search dates from expected_update_frequency_hours (PLAYBOOK RULE 3)
    tc_days=$(( (tc_freq_hours + 23) / 24 ))  # ceiling division: hours → days
    tc_search_dates=""
    for ((d=0; d<tc_days; d++)); do
        tc_d=$(TZ=America/Los_Angeles date -d "$d days ago" +%Y-%m-%d 2>/dev/null \
            || TZ=America/Los_Angeles date -v-${d}d +%Y-%m-%d 2>/dev/null)
        tc_search_dates="${tc_search_dates:+$tc_search_dates }$tc_d"
    done
    # Use 30s timeout (large docs like routine need more than 15s)
    tc_raw=$(timeout 30 meta google.docs structure --id "$tc_doc_id" --tab-id "$tc_tab_id" 2>/dev/null || true)
    tc_found=""
    for tc_check_date in $tc_search_dates; do
        [ -n "$tc_raw" ] && tc_found=$(echo "$tc_raw" | grep -o "$tc_check_date" | head -1 || true)
        [ -n "$tc_found" ] && break
    done
    # Fallback: if structure check timed out/empty, check Drive API modified time
    if [ -z "$tc_raw" ]; then
        tc_modified=$(google-mux api call GET "https://www.googleapis.com/drive/v3/files/${tc_doc_id}?fields=modifiedTime" < /dev/null 2>/dev/null \
            | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('modifiedTime','')[:10])" 2>/dev/null || true)
        for tc_check_date in $tc_search_dates; do
            [ "$tc_modified" = "$tc_check_date" ] && tc_found="$tc_check_date" && break
        done
    fi
    if [ -n "$tc_found" ]; then
        tc_ok=$((tc_ok + 1))
    else
        tc_missing="${tc_missing:+$tc_missing, }${tc_display} (expected every ${tc_freq_hours}h, no date in last ${tc_days}d)"
    fi
done
if [ -n "$tc_missing" ]; then
    tab_content_status="RED"
    tab_content_detail="${tc_ok}/${tc_checked} OK — missing: ${tc_missing}"
    # Fire ALERTS.md alert so dashboard RED surfaces as an actionable alert,
    # not just a status cell. Past bug: Signal-to-Opportunity went stale 2 days
    # and Tab Content Freshness went RED, but no alert ever fired because this
    # signal wasn't wired into cron_alert.
    cron_alert "stale-tab-content" "Tab content freshness: ${tc_missing}"
else
    tab_content_detail="${tc_ok}/${tc_checked} tabs have expected date content"
    cron_alert_clear "stale-tab-content"
fi

# ─── Signal 14: AI Impact Metrics ──────────────────────────────────────────
# Tracks authentic outcomes: diffs, opportunities, comments, meetings.
# All metrics are evidence-backed — every number links to an artifact.

impact_file="$REPO_DIR/context/IMPACT.md"
prev_week=$(date -d '14 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-14d '+%Y-%m-%d' 2>/dev/null || echo "2000-01-01")

# 1. Diffs landed (AI-assisted) — entries tagged [AI] in IMPACT.md
ai_diffs_total=0; ai_diffs_evidence=""
if [ -f "$impact_file" ]; then
    ai_diffs_total=$(grep -c "\[AI\]" "$impact_file" 2>/dev/null || echo 0)
    # Latest evidence: last [AI] entry, extract D-number or first 40 chars
    ai_diffs_evidence=$(grep "\[AI\]" "$impact_file" 2>/dev/null | tail -1 | sed 's/^- \*\*//;s/\*\*.*//' | head -c 40 || true)
fi
# All diffs in IMPACT.md (AI-assisted + human)
all_diffs_total=$(grep -cP "^\- \*\*D\d+" "$impact_file" 2>/dev/null || echo 0)

# NOTE: "Opportunities surfaced" metric retired 2026-06-01 — both feeders
# (Signal-to-Opportunity tab + gchat-copilot state) deprecated 2026-05-30.

# 2b. GChat inbound reply drafted — mentions + DMs that received a drafted response
# Parses COPILOT_RESULT lines in gchat-copilot log: "X mentions, Y opportunities, Z DMs, ..."
# Log rotates daily, so "today" is the full in-log window; 7d total aggregates from state.
gchat_inbound_today=0
gchat_inbound_week=0
gchat_inbound_total=0
gchat_log="$HOME/logs/gchat-copilot.log"
gchat_inbound_state="$REPO_DIR/context/cache/state/GCHAT-INBOUND-HISTORY.json"
if [ -f "$gchat_log" ]; then
    # Sum mentions + DMs across COPILOT_RESULT lines in current log (today)
    gchat_inbound_today=$(grep "COPILOT_RESULT:" "$gchat_log" 2>/dev/null \
        | sed -n 's/.*COPILOT_RESULT: \([0-9]*\) mentions.* \([0-9]*\) DMs.*/\1 \2/p' \
        | awk '{m+=$1; d+=$2} END {print (m+d)+0}')
fi
# Persist daily count; aggregate 7d and all-time from history
if command -v python3 >/dev/null; then
    read gchat_inbound_week gchat_inbound_total < <(python3 - <<PYEOF 2>/dev/null || echo "0 0"
import json, os
from datetime import date, timedelta
state_file = "$gchat_inbound_state"
today = "$TODAY"
today_count = int("${gchat_inbound_today:-0}")
try:
    history = json.load(open(state_file))
except Exception:
    history = {}
history[today] = today_count
cutoff = (date.fromisoformat(today) - timedelta(days=30)).isoformat()
history = {d: c for d, c in history.items() if d >= cutoff}
os.makedirs(os.path.dirname(state_file), exist_ok=True)
json.dump(history, open(state_file, "w"), indent=2, sort_keys=True)
seven_days_ago = (date.fromisoformat(today) - timedelta(days=7)).isoformat()
week = sum(c for d, c in history.items() if d >= seven_days_ago)
total = sum(history.values())
print(f"{week} {total}")
PYEOF
)
fi

# 3. gdoc auto-replied — count processed comment IDs + recent from log
comments_total=0; comments_week=0
processed_cache="$HOME/work/claude/state/gdoc-comments-processed.json"
# Fallback to /tmp if persistent path doesn't exist
[ ! -f "$processed_cache" ] && processed_cache="/tmp/gdoc-comments-processed.json"
if [ -f "$processed_cache" ]; then
    comments_total=$(python3 -c "
import json
with open('$processed_cache') as f:
    d = json.load(f)
print(sum(len(v) for v in d.values()))
" 2>/dev/null || echo 0)
fi
# Count recent [Claude] replies from gdoc-comments log (fallback replies + LLM replies)
if [ -f "$HOME/logs/gdoc-comments-critical.log" ]; then
    comments_week=$(awk -v since="$seven_days_ago" '/^[0-9]/ && $1 >= since && /comment.*processed|reply.*success|"id":/' "$HOME/logs/gdoc-comments-critical.log" 2>/dev/null | wc -l | tr -d ' ')
fi

# 4. Meetings prepped by AI — count from meeting-prep logs
meetings_week=0
if [ -f "$HOME/logs/meeting-prep.log" ]; then
    meetings_week=$(awk -v since="$seven_days_ago" '$0 ~ /^[0-9]/ && $1 >= since && /Meeting prep:/ && !/skipped/' "$HOME/logs/meeting-prep.log" 2>/dev/null | wc -l | tr -d ' ')
fi

# 5. Knowledge distiller outcomes — files distilled, tokens recovered
distill_total=0; distill_week=0; distill_tokens=0
if [ -f "$HOME/logs/knowledge-distiller.log" ]; then
    distill_total=$(grep -c "✓ Distilled:" "$HOME/logs/knowledge-distiller.log" 2>/dev/null || echo 0)
    distill_week=$(awk -v since="$seven_days_ago" '$0 ~ /^[0-9]/ && $1 >= since && /✓ Distilled:/' "$HOME/logs/knowledge-distiller.log" 2>/dev/null | wc -l | tr -d ' ')
    # Total tokens recovered (sum of reductions)
    distill_tokens=$(grep "tokens recovered" "$HOME/logs/knowledge-distiller.log" 2>/dev/null \
        | awk -F',' '{for(i=1;i<=NF;i++) if($i ~ /tokens recovered/) {gsub(/[^0-9-]/,"",$i); sum+=$i}} END{print sum+0}' 2>/dev/null || echo 0)
fi

# 6. Week-over-week trend for fleet pass rate (reuse existing data)
wow_direction="—"
wow_detail=""
if [ -f "$AI_HEALTH_HISTORY" ]; then
    wow_detail=$(python3 -c "
import json
history = json.load(open('$AI_HEALTH_HISTORY'))
rates = [(e['date'], e.get('fleet_rate', 0)) for e in sorted(history, key=lambda x: x['date'], reverse=True)]
if len(rates) >= 2:
    curr, prev = rates[0][1], rates[1][1]
    if curr > prev: print(f'UP +{curr-prev}% (this: {curr}%, prev: {prev}%)')
    elif curr < prev: print(f'DOWN {curr-prev}% (this: {curr}%, prev: {prev}%)')
    else: print(f'FLAT ({curr}%)')
else:
    print('—')
" 2>/dev/null || echo "—")
fi

# ─── Compute Overall Health ─────────────────────────────────────────────────
health="GREEN"
health_reasons=""

# RED conditions
if [ "$fleet_rate" -lt 90 ]; then
    health="RED"; health_reasons="fleet ${fleet_rate}%"
fi
if [ "$active_alerts" -gt 2 ]; then
    health="RED"; health_reasons="${health_reasons:+$health_reasons; }${active_alerts} alerts"
fi

# YELLOW conditions (only if not already RED)
if [ "$health" != "RED" ]; then
    if [ "$fleet_rate" -ge 90 ] && [ "$fleet_rate" -lt 95 ]; then
        health="YELLOW"; health_reasons="${health_reasons:+$health_reasons; }fleet ${fleet_rate}%"
    fi
    if [ "$active_alerts" -gt 0 ]; then
        health="YELLOW"; health_reasons="${health_reasons:+$health_reasons; }${active_alerts} alert(s)"
    fi
    if [ "$stale_heartbeats" -gt 2 ]; then
        health="YELLOW"; health_reasons="${health_reasons:+$health_reasons; }${stale_heartbeats} stale heartbeats"
    fi
    if [ "$stale_cache" -gt 1 ]; then
        health="YELLOW"; health_reasons="${health_reasons:+$health_reasons; }${stale_cache} stale outputs"
    fi
    if [ "$oversized_cs" -gt 0 ]; then
        health="YELLOW"; health_reasons="${health_reasons:+$health_reasons; }${oversized_cs} oversized cheatsheets"
    fi
    if [ -n "$missing_jobs" ]; then
        health="YELLOW"; health_reasons="${health_reasons:+$health_reasons; }jobs not running: $missing_jobs"
    fi
fi
[ -z "$health_reasons" ] && health_reasons="all signals healthy"

# ─── Build Action Required List (ordered by severity) ────────────────────────
# PLAYBOOK RULE 24: Only items genuinely blocked on Denny belong here.
# Decision gate: "If Denny never reads this, will the situation worsen due to HIS inaction?"
# Auto-resolved events and premature observations are routed to Health Signals instead.

# Patterns that indicate an event auto-resolved (not blocked on Denny)
AUTO_RESOLVED_PATTERNS="daemon restart|daemon restarted|auto.retry|auto-retry|recovered on retry|self-resolved|self-healed|auth refresh|auth token refresh|token refresh|successfully restarted|gmux restart|restarted successfully"

# Check if an alert line describes an auto-resolved event
is_auto_resolved_alert() {
    echo "$1" | grep -qiE "$AUTO_RESOLVED_PATTERNS"
}

# Check if GChat zero-message alert is premature (working hours not yet ended)
is_premature_gchat_zero_msg() {
    local line="$1"
    echo "$line" | grep -qi "zero inbound\|0 inbound\|Zero.*message" || return 1
    local current_hour
    current_hour=$(TZ=America/Los_Angeles date +%H)
    [ "$current_hour" -lt 19 ] && return 0
    return 1
}

# Accumulator for events filtered from Action Required → Health Signals
health_signal_filtered=""

actions=""
action_rows=""
# P0: things that are broken
if [ "$fleet_rate" -lt 95 ]; then
    action_rows="${action_rows}| P0 | Fleet pass rate ${fleet_rate}% | below 95% target — check failing jobs below |\n"
fi
if [ "$active_alerts" -gt 0 ]; then
    # Dedupe alerts by (source, first 60 chars of message) — avoids 4 identical
    # rows when the same alert fires hourly (e.g. gchat-copilot "Zero inbound").
    # Preserve first-seen order so newest-at-top stays; append "(xN)" when N>1.
    # One row per alert with error detail from logs.
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Source tag is the FIRST [foo] after the date, not only [cron:*] — the
        # old extractor missed [gchat-copilot] and left job blank → "alert".
        job=$(echo "$line" | grep -oP '\*\* \[\K[^\]]+' | head -1 | sed 's/^cron://' 2>/dev/null || true)
        job_short="$job"
        reason=$(echo "$line" | sed 's/.*\] //' | truncate_at_word 120)
        # grep returns 1 if no match → mask under set -eo pipefail
        dup_count=$(echo "$line" | grep -oP '\(x\K[0-9]+' 2>/dev/null | head -1 || true)
        # Pull actual error from log if reason is generic
        if echo "$reason" | grep -q "exit=1\|no retryable\|fix ineffective"; then
            log_file="$HOME/logs/${job_short}.log"
            if [ -f "$log_file" ]; then
                err_detail=$(grep -i "ERROR\|FAIL\|exception\|timeout\|TIMEOUT" "$log_file" 2>/dev/null \
                    | grep -v "cron-alert\|Alert written to ALERTS\|cron_run\|retry FAIL\|Skipping heartbeat" \
                    | tail -1 | sed 's/^[0-9-]* [0-9:]* //' | sed 's/^\[.*\] //' | truncate_at_word 120 || true)
                [ -n "$err_detail" ] && reason="${err_detail}"
            fi
        fi
        [ -n "$dup_count" ] && reason="${reason} (x${dup_count})"

        # PLAYBOOK RULE 24: filter non-actionable alerts
        _r24_filtered=false
        _r24_reason=""
        if is_auto_resolved_alert "$line $reason"; then
            _r24_filtered=true
            _r24_reason="auto-resolved"
        elif is_premature_gchat_zero_msg "$line"; then
            _r24_filtered=true
            _r24_reason="non-blocking: working hours not ended"
        fi

        if $_r24_filtered; then
            health_signal_filtered="${health_signal_filtered}| ${job:-system} | GREEN | ${reason} (${_r24_reason}) |\n"
            echo "$LOG_PREFIX   RULE 24: filtered from Action Required → Health Signals: ${job:-alert} (${_r24_reason})"
        else
            action_rows="${action_rows}| P0 | ${job:-alert} | ${reason} |\n"
        fi
    done < <(
        grep "^\- \*\*" "$REPO_DIR/ALERTS.md" 2>/dev/null \
        | awk '{
            # Strip leading "- **YYYY-MM-DD HH:MM** " timestamp for grouping key
            key = $0;
            sub(/^- \*\*[0-9-]+ [0-9:]+\*\* /, "", key);
            # Further normalize: keep first 80 chars of [source] + message
            key = substr(key, 1, 80);
            if (!(key in idx)) {
                idx[key] = order++;
                first[idx[key]] = $0;
            }
            count[idx[key]]++;
        }
        END {
            for (i = 0; i < order; i++) {
                if (count[i] > 1) {
                    # Tag line with multiplier marker for downstream parse
                    printf "%s (x%d)\n", first[i], count[i];
                } else {
                    print first[i];
                }
            }
        }' \
        | head -4
    )
fi
if [ -n "${missing_jobs:-}" ]; then
    # PLAYBOOK RULE 13: one row per missing job with name + purpose
    while IFS= read -r _mj; do
        _mj=$(echo "$_mj" | xargs)
        [ -z "$_mj" ] && continue
        _mj_desc="${job_descriptions[$_mj]:-unknown purpose}"
        action_rows="${action_rows}| P0 | ${_mj} not running | ${_mj_desc} |\n"
    done < <(echo "$missing_jobs" | tr ',' '\n')
fi
# P1: things that need attention
if [ "$unsafe_experiments" -gt 0 ]; then
    # Inline experiment details instead of linking to local file
    unsafe_detail=""
    if [ -f "$experiments_file" ]; then
        unsafe_detail=$(python3 -c "
with open('$experiments_file') as f:
    content = f.read()
lines = content.split('\n')
results = []
i = 0
while i < len(lines):
    if lines[i].startswith('### EXP-'):
        exp_name = lines[i].replace('### ', '')
        # Scan ahead for UNSAFE and Change
        j = i + 1
        is_unsafe = False
        change = ''
        while j < len(lines) and not lines[j].startswith('### '):
            if 'UNSAFE' in lines[j] and 'Type' in lines[j]:
                is_unsafe = True
            if 'Status' in lines[j] and any(s in lines[j] for s in ('RESOLVED', 'APPLIED', 'COMPLETED')):
                is_unsafe = False  # skip resolved/applied experiments
            if '**Change**' in lines[j]:
                change = lines[j].split('**Change**:')[-1].strip()[:80]
            j += 1
        if is_unsafe and change:
            results.append(f'{exp_name}: {change}')
        i = j
    else:
        i += 1
print('; '.join(results[:3]) if results else '')
" 2>/dev/null || true)
    fi
    action_rows="${action_rows}| P1 | UNSAFE experiment(s) | ${unsafe_detail:-no detail available} |\n"
fi
if [ "$stale_cache" -gt 0 ]; then
    action_rows="${action_rows}| P1 | Stale cache | ${stale_cache_names} |\n"
fi
# P2: maintenance
if [ "$stale_heartbeats" -gt 0 ]; then
    action_rows="${action_rows}| P2 | Stale heartbeat(s) | ${stale_hb_names} |\n"
fi
if [ "$oversized_cs" -gt 0 ]; then
    action_rows="${action_rows}| P2 | Oversized cheatsheet(s) | ${oversized_cs_names} |\n"
fi

# ─── Shadow mode: cross-check Python port (observe-only) ───────────────────
# Migration in progress (started 2026-04-20): private_scripts/lib/ai_health.py runs
# alongside bash. Diffs are logged to ~/logs/ai-health-shadow-diff.log.
# Promotion criterion: 7 consecutive days clean → cut bash sections at lines
# 849-1040 and call the Python module directly.
# This block is wrapped in `|| true` and CANNOT fail the parent script.
{
    _jd_json="{}"
    if [ "${#job_descriptions[@]}" -gt 0 ]; then
        _jd_json=$(
            for _k in "${!job_descriptions[@]}"; do
                printf '%s\t%s\n' "$_k" "${job_descriptions[$_k]}"
            done | python3 -c "
import json, sys
out = {}
for line in sys.stdin:
    if '\t' in line:
        k, v = line.rstrip('\n').split('\t', 1)
        out[k] = v
print(json.dumps(out))
" 2>/dev/null || echo "{}"
        )
    fi

    S_FLEET="$fleet_rate" \
    S_ALERTS="$active_alerts" \
    S_HB="$stale_heartbeats" \
    S_CACHE="$stale_cache" \
    S_CS="$oversized_cs" \
    S_MJ="$missing_jobs" \
    S_EXP="${unsafe_experiments:-0}" \
    S_CACHE_N="$stale_cache_names" \
    S_HB_N="$stale_hb_names" \
    S_CS_N="$oversized_cs_names" \
    S_ALERTS_MD="$REPO_DIR/ALERTS.md" \
    S_EXP_F="$experiments_file" \
    S_LOGS="$HOME/logs" \
    S_JD="$_jd_json" \
    B_HEALTH="$health" \
    B_REASONS="$health_reasons" \
    B_ACTIONS="$action_rows" \
    B_FILTERED="$health_signal_filtered" \
    python3 "$HOME/work/claude/private_scripts/lib/ai_health_shadow.py" 2>&1 | sed "s/^/$LOG_PREFIX /"
} || true

# ─── Compute deltas from previous dashboard ──────────────────────────────────
prev_health=""
prev_fleet_rate_dash=""
prev_autolearn_total=""
delta_section=""
if [ -f "$OUTPUT" ]; then
    prev_health=$(grep "^\\*\\*Overall:" "$OUTPUT" | grep -oE 'GREEN|YELLOW|RED' | head -1 || true)
    prev_fleet_rate_dash=$(grep "Pass rate" "$OUTPUT" | grep -oE '[0-9]+%' | head -1 | tr -d '%' || true)
    prev_autolearn_total=$(grep "Autolearn total" "$OUTPUT" | grep -oE '[0-9]+' | head -1 || true)

    deltas=""
    if [ -n "$prev_health" ] && [ "$prev_health" != "$health" ]; then
        deltas="${deltas}Health: ${prev_health} → ${health}. "
    fi
    if [ -n "$prev_fleet_rate_dash" ] && [ "$prev_fleet_rate_dash" != "$fleet_rate" ]; then
        deltas="${deltas}Fleet: ${prev_fleet_rate_dash}% → ${fleet_rate}%. "
    fi
    if [ -n "$prev_autolearn_total" ] && [ "$prev_autolearn_total" != "$autolearn_rules" ]; then
        new_rules=$((autolearn_rules - prev_autolearn_total))
        [ "$new_rules" -gt 0 ] && deltas="${deltas}Autolearn: +${new_rules} rules. "
    fi
    [ -n "$deltas" ] && delta_section="**Changes since last run:** ${deltas}"
fi

# ─── Load prior days history ────────────────────────────────────────────────
AI_HEALTH_HISTORY="$REPO_DIR/context/cache/state/AI-HEALTH-HISTORY.json"
prior_days_section=""
if [ -f "$AI_HEALTH_HISTORY" ]; then
    prior_days_section=$(python3 -c "
import json, sys
try:
    history = json.load(open('$AI_HEALTH_HISTORY'))
    today = '$TODAY'
    lines = []
    for entry in sorted(history, key=lambda x: x.get('date',''), reverse=True):
        if entry.get('date') == today:
            continue
        d = entry.get('date','?')
        h = entry.get('health','?')
        r = entry.get('fleet_rate','?')
        summary = entry.get('summary','')
        lines.append(f\"## {d}\")
        lines.append(f\"Fleet: {h} | Pass rate: {r}% | {summary}\")
        lines.append('')
    print('\n'.join(lines[:21]))  # Max 7 prior days (3 lines each)
except Exception as e:
    pass
" 2>/dev/null || true)
fi

# ─── PLAYBOOK RULE 19: skip Purpose preamble if already present ────────────
_purpose_preamble="**Purpose:** Daily health snapshot of Denny's AI automation fleet — surfaces what's broken, what's working, and what to act on first.

**Pipeline:** cron-ai-health.sh (daily 10:10 AM PT) → AI-HEALTH.md → AI Playbook gdoc. Structure: Action Required (P0-first) > AI Impact > Health Signals > Cron Fleet > Prior Days.

**Source:** cron-runtime.csv, AI-HEALTH-HISTORY.json, AUTO-LEARNINGS.md, ALERTS.md."
if [ -f "$OUTPUT" ] && [ "$(grep -c 'Purpose:' "$OUTPUT" 2>/dev/null)" -ge 1 ]; then
    echo "$LOG_PREFIX   PLAYBOOK RULE 19: Purpose preamble already in doc, skipping insertion"
    _purpose_preamble=""
fi

# Dashboard link — doc-top item (updated idempotently by the push's
# ensure_doc_top_header_item). Read latest Collab Files URL from publish state.
_dashboard_line=""
_dashboard_url="$(cat "$REPO_DIR/state/cron-dashboard-url.txt" 2>/dev/null || true)"
[ -n "$_dashboard_url" ] && _dashboard_line="**Dashboard:** $_dashboard_url"

# ── AI Impact week-over-week (operator 2026-06-14: track impact GROWTH) ──────
# Snapshot today's cumulative metrics, compare to the row ~7 days ago. First
# week shows "—" (no prior); real deltas appear once 2 snapshots exist.
AI_IMPACT_HIST="$REPO_DIR/state/ai-impact-history.csv"
[ -f "$AI_IMPACT_HIST" ] || echo "date,diffs_total,comments_total,distill_total,fleet_rate" > "$AI_IMPACT_HIST"
grep -v "^${TODAY}," "$AI_IMPACT_HIST" > "$AI_IMPACT_HIST.tmp" 2>/dev/null && mv "$AI_IMPACT_HIST.tmp" "$AI_IMPACT_HIST"
echo "${TODAY},${ai_diffs_total:-0},${comments_total:-0},${distill_total:-0},${fleet_rate:-0}" >> "$AI_IMPACT_HIST"
wow_diffs="—"; wow_comments="—"; wow_distill="—"; wow_pass="—"
_ref_date=$(date -d "${TODAY} -7 days" +%Y-%m-%d 2>/dev/null || true)
if [ -n "$_ref_date" ]; then
    _prior=$(awk -F, -v d="$_ref_date" '$1!="date" && $1<=d {row=$0} END{print row}' "$AI_IMPACT_HIST")
    if [ -n "$_prior" ]; then
        wow_diffs="+$(( ${ai_diffs_total:-0} - $(echo "$_prior"|cut -d, -f2) ))"
        wow_comments="+$(( ${comments_total:-0} - $(echo "$_prior"|cut -d, -f3) ))"
        wow_distill="+$(( ${distill_total:-0} - $(echo "$_prior"|cut -d, -f4) ))"
        wow_pass="$(( ${fleet_rate:-0} - $(echo "$_prior"|cut -d, -f5) ))pp"
    fi
fi

# ── The 2 verdicts this report exists to answer (operator 2026-06-14) ────────
# Goal 1: are all (required = all) jobs healthy?  Goal 2: is AI impact growing?
# Verdict on Goal 1: count only ACTUAL failures (RED). Never-run-but-scheduled
# jobs are noted separately, not called "failing" (avoids false alarms on new jobs).
_red_names_raw=$(echo -e "${all_jobs:-}" | awk -F'|' '/\| RED \|/{gsub(/^ +| +$/,"",$2); printf "%s ", $2}')
# Filter to jobs STILL in the crontab — drop removed jobs (e.g. ot-alert-investigator)
# that linger in the 7d fleet history. Same fix as the dashboard.
_cron_jobs=$(crontab -l 2>/dev/null | grep -oE 'cron_run [0-9]+ [a-z0-9-]+' | awk '{print $3}')
_red_names=""
for _j in $_red_names_raw; do echo "$_cron_jobs" | grep -qx "$_j" && _red_names="${_red_names}${_j} "; done
_red_names=$(echo "$_red_names" | xargs)
_red_jobs=$(echo "$_red_names" | wc -w | tr -d ' ')
if [ "${_red_jobs:-0}" -eq 0 ]; then
    verdict_jobs="✅ all jobs healthy${missing_jobs:+ (note: not yet run — ${missing_jobs})}"
else
    verdict_jobs="❌ ${_red_jobs} failing: ${_red_names}"
fi
# Verdict on Goal 2: growing/flat/declining from WoW. When not growing, the loop
# can't auto-grow a business metric — so it carries a PROPOSAL instead.
verdict_impact="— baseline (WoW in ~7d)"
if [ "$wow_diffs" != "—" ]; then
    _impact_delta=$(( ${wow_diffs#+} + ${wow_comments#+} + ${wow_distill#+} ))
    if [ "$_impact_delta" -gt 0 ]; then
        verdict_impact="📈 growing (+${_impact_delta} artifacts WoW)"
    else
        verdict_impact="📉 not growing (${_impact_delta} WoW) — propose: review automation coverage / add a new automated output"
    fi
fi

# ─── Write Dashboard ────────────────────────────────────────────────────────
cat > "$OUTPUT" << EOF
# AI Playbook — $TODAY

*Generated: $(date '+%Y-%m-%d %H:%M:%S')$([ -f "$RUNTIME_CSV" ] && echo " | Harness tracking since $(head -2 "$RUNTIME_CSV" | tail -1 | cut -d, -f1 | cut -d' ' -f1)")*

${_purpose_preamble}

${_dashboard_line}

**Overall: Required jobs ${verdict_jobs} · AI impact ${verdict_impact}** ($health$([ -n "$health_reasons" ] && echo " — $health_reasons"))
$([ -n "$delta_section" ] && echo "$delta_section")

$(if [ -n "$action_rows" ]; then
    # operator 2026-06-14 (5pQ): split into what NEEDS DENNY vs what the system
    # already auto-handles, so "Action Required" is only human-owned items.
    _AUTO='timeout|budget|unicode|repo-size|repo still|disk-cleanup|disk usage|stale heartbeat|stale cache|stale tab|cmd-not-found|recovered on retry'
    _rows=$(echo -e "$action_rows" | awk 'NF' | sort -t '|' -k2,2 -s)
    _needs=$(echo "$_rows" | grep -ivE "$_AUTO" || true)
    _auto=$(echo "$_rows" | grep -iE "$_AUTO" || true)
    _nc=$(echo "$_needs" | grep -c "^|" || echo 0)
    echo "## Action Required (${_nc})"
    echo ""
    echo "| Priority | Issue | Error/Context |"
    echo "|----------|-------|--------------|"
    if [ -n "$_needs" ]; then echo "$_needs"; else echo "| — | Nothing needs you | all current issues are auto-handled |"; fi
    echo ""
    if [ -n "$_auto" ]; then
        echo "## Auto-handled ($(echo "$_auto" | grep -c "^|"), no action)"
        echo ""
        echo "| Priority | Issue | Status |"
        echo "|----------|-------|--------|"
        echo "$_auto"
    fi
else
    echo "_No action items — all systems nominal._"
    echo ""
fi)

## AI Impact

What AI automation actually produced — every number links to an artifact.

| # | Metric | 7d | All Time | WoW | Evidence |
|---|--------|----|----------|-----|----------|
| 1 | Diffs auto-created (no prompts) | — | ${ai_diffs_total} | ${wow_diffs} | IMPACT.md (${all_diffs_total} total) |
| 2 | Inbound reply drafted (mentions+DMs) | ${gchat_inbound_week} (today: ${gchat_inbound_today}) | ${gchat_inbound_total} | — | GCHAT-INBOUND-HISTORY — 0 when no inbound arrived |
| 3 | gdoc auto-replied | ${comments_week} | ${comments_total} | ${wow_comments} | gdoc-comments cron |
| 4 | Meetings prepped | ${meetings_week} | — | — | meeting-prep cron |
| 5 | Knowledge distilled | ${distill_week} | ${distill_total} files (${distill_tokens} tokens) | ${wow_distill} | knowledge-distiller cron |
| 6 | Autonomous AI pass rate | ${fleet_trend:-—} | ${wow_detail:-—} | ${wow_pass} | cron-runtime.csv |

## Health Signals

| Signal | Status | Value |
|--------|--------|-------|
$(
{
    # ── Fleet signals ────────────────────────────────────────────────────────
    pass_status=$([ "$fleet_rate" -ge 95 ] && echo "GREEN" || ([ "$fleet_rate" -ge 90 ] && echo "YELLOW" || echo "RED"))
    echo "| Pass rate (7d) | ${pass_status} | ${fleet_rate}% (${fleet_pass}/${fleet_total}) |"

    alert_status=$([ "$active_alerts" -eq 0 ] && echo "GREEN" || ([ "$active_alerts" -le 2 ] && echo "YELLOW" || echo "RED"))
    echo "| Alerts | ${alert_status} | ${active_alerts}$([ -n "$alert_names" ] && echo " — $alert_names") |"

    err_status=$([ "$timeout_errors" -gt 5 ] && echo "YELLOW" || echo "GREEN")
    other_label="${other_errors} other"
    [ -n "$other_breakdown" ] && other_label="${other_errors} other (${other_breakdown})"
    err_detail="${total_fail} failed (${timeout_errors} timeout, ${other_label}) + ${transient_errors} recovered on retry"
    [ -n "${error_detail:-}" ] && err_detail="${err_detail} — ${error_detail}"
    echo "| Errors (7d) | ${err_status} | ${err_detail} |"

    dur_status=$([ "$budget_warnings" -eq 0 ] && echo "GREEN" || echo "YELLOW")
    if [ "$budget_warnings" -eq 0 ]; then
        dur_detail="all jobs within budget"
    else
        dur_detail=""
        for i in "${!bw_names[@]}"; do
            [ -n "$dur_detail" ] && dur_detail="${dur_detail}; "
            bw_rec="optimize"
            [ "${bw_pcts[$i]}" -ge 95 ] && bw_rec="increase"
            [ "${bw_pcts[$i]}" -ge 90 ] && [ "${bw_pcts[$i]}" -lt 95 ] && bw_rec="split/increase"
            dur_detail="${dur_detail}${bw_names[$i]}: ${bw_maxes[$i]}s/${bw_timeouts[$i]}s (${bw_pcts[$i]}%) → ${bw_rec}"
        done
    fi
    echo "| Duration budget | ${dur_status} | ${dur_detail} |"

    echo "| AI audit | $audit_score | $([ -n "$audit_dims" ] && echo "$audit_dims" || echo "all dimensions GREEN") |"

    wow_status=$([ "$prev_total" -eq 0 ] && echo "N/A" || ([ "$fleet_delta" -lt -5 ] && echo "RED" || ([ "$fleet_delta" -lt 0 ] && echo "YELLOW" || echo "GREEN")))
    echo "| Week-over-week | ${wow_status} | ${fleet_trend} |"

    echo "| Prevention | — | ${error_learnings} |"

    # ── Operational signals ──────────────────────────────────────────────────
    hb_status=$([ "$stale_heartbeats" -eq 0 ] && echo "GREEN" || echo "YELLOW")
    echo "| Heartbeats | ${hb_status} | $((total_heartbeats - stale_heartbeats))/${total_heartbeats} fresh$([ -n "$stale_hb_names" ] && echo " — stale: $stale_hb_names") |"

    routine_status=$([ "${routine_score}" != "N/A" ] && ([ "$routine_score" -ge 65 ] && echo "GREEN" || echo "YELLOW") || echo "N/A")
    routine_gap=$( [ "${routine_score}" != "N/A" ] && echo "$((100 - routine_score))" || echo "N/A")
    echo "| Routine score | ${routine_status} | ${routine_score}/100 (gap: ${routine_gap}pts — LLM self-eval on nightly digest) |"

    corr_status=$([ "$correction_avg" != "N/A" ] && echo "TRACKING" || echo "N/A")
    echo "| Corrections | ${corr_status} | ${correction_avg}/session (${count_corr} sessions)${correction_trend} |"

    token_budget_kb=""
    token_limit_kb=""
    if [ -f "$REPO_DIR/scripts/token-budget.sh" ]; then
        token_raw=$(bash "$REPO_DIR/scripts/token-budget.sh" --check 2>&1 | grep -oP 'Context files: \K\d+' || echo "0")
        token_budget_kb=$((token_raw / 1024))
        token_limit_kb=40
    fi
    echo "| Context size | TRACKING | ${token_budget_kb:-?}k (limit: ${token_limit_kb:-?}k) |"

    cache_status=$([ "$stale_cache" -eq 0 ] && echo "GREEN" || echo "YELLOW")
    echo "| Pipeline outputs | ${cache_status} | $([ "$stale_cache" -eq 0 ] && echo "all fresh (meeting-prep, ot-triage, area-monitor)" || echo "${stale_cache} stale: ${stale_cache_names}") |"

    cs_status=$([ "$oversized_cs" -eq 0 ] && echo "GREEN" || echo "YELLOW")
    echo "| Cheatsheets | ${cs_status} | $([ "$oversized_cs" -eq 0 ] && echo "all under 500 lines" || echo "${oversized_cs} over 500L: ${oversized_cs_names}") |"

    echo "| Tab content freshness | ${tab_content_status} | ${tab_content_detail} |"

    gchat_metrics="$REPO_DIR/context/cache/state/GCHAT-COPILOT-METRICS.json"
    if [ -f "$gchat_metrics" ]; then
        gchat_info=$(python3 -c "
import json, time
with open('$gchat_metrics') as f:
    m = json.load(f)
last = m.get('last_run', '')
mentions = m.get('mentions', 0)
opps = m.get('opportunities', 0)
dms = m.get('dms', 0)
flags = m.get('outbound_flags', 0)
total = m.get('total', 0)
status = m.get('status', 'unknown')
stage_errors = m.get('stage_errors', 0)
from datetime import datetime
try:
    ts = datetime.strptime(last, '%Y-%m-%dT%H:%M:%SZ')
    age_min = int((datetime.utcnow() - ts).total_seconds() / 60)
except:
    age_min = 9999
if age_min > 30:
    health = 'YELLOW'
elif stage_errors > 0:
    health = 'YELLOW'
else:
    health = 'GREEN'
detail = f'{total} items (last run: {mentions}m {opps}o {dms}d {flags}f, {age_min}min ago'
if stage_errors > 0:
    detail += f', {stage_errors} stage errors'
detail += ')'
print(f'{health}|{detail}')
" 2>/dev/null || echo "YELLOW|metrics unreadable")
        gchat_status=$(echo "$gchat_info" | cut -d'|' -f1)
        gchat_detail=$(echo "$gchat_info" | cut -d'|' -f2-)
        echo "| GChat Intelligence | ${gchat_status} | ${gchat_detail} |"
    else
        echo "| GChat Intelligence | RED | no metrics file — copilot may not be running |"
    fi

    # PLAYBOOK RULE 24: surface filtered events as green health signals
    if [ -n "${health_signal_filtered:-}" ]; then
        echo -e "$health_signal_filtered" | awk 'NF'
    fi
} | awk -F'|' '{
    s=$3; gsub(/ /,"",s)
    if (s=="RED") p=1; else if (s=="YELLOW") p=2; else if (s=="GREEN") p=4; else p=3
    print p"|"$0
}' | sort -t'|' -k1,1n | cut -d'|' -f2-
)

$(if [ -n "$routine_gap_analysis" ]; then
    echo "## Gap Analysis — Routine Score ${routine_score}/100 (PLAYBOOK RULE 5)"
    echo ""
    echo "Dimensions below target — each maps to a generation rule with a specific fix."
    echo ""
    echo "| Dimension | Score | Rule | Fix Needed | Detail |"
    echo "|-----------|-------|------|------------|--------|"
    echo "$routine_gap_analysis"
    echo ""
fi)

## Cron Fleet (7d)

${registered_jobs} registered, ${distinct_jobs} ran, ${fleet_total} runs in 7 days$([ -n "${missing_jobs:-}" ] && echo " — **NOT RUNNING: ${missing_jobs}**")

| Job | Status | Runs | Last Run (Detail) | Pass Rate (Duration) |
|-----|--------|------|-------------------|----------------------|
${all_jobs:-| (no data) | — | — | — | — |}

---

${prior_days_section}
EOF

# ─── Shadow mode: snapshot OUTPUT before any lint mutation ──────────────────
# Migration in progress (started 2026-04-20): private_scripts/lib/ai_health_lints.py
# is validated against the bash lints (lines 1331-1458). The snapshot lets
# Python apply its lints to the SAME pre-lint state, so we can diff outcomes.
cp -f "$OUTPUT" "$OUTPUT.shadow-orig" 2>/dev/null || true

# ─── Pre-push lint: no data-col-widths or width:100% in output ──────────────
# data-col-widths causes Google Docs tables to stretch to full width, breaking
# compact column widths set by apply_compact_widths(). width:100% has the same
# effect. This lint prevents regression — if any template or code path
# re-introduces these patterns, the cron job fails loudly + alerts ALERTS.md.
lint_fail=""
if grep -qc 'data-col-widths' "$OUTPUT" 2>/dev/null; then
    lint_fail="data-col-widths found in $OUTPUT — tables will not be compact"
fi
if grep -qP 'width:\s*100%' "$OUTPUT" 2>/dev/null; then
    lint_fail="${lint_fail:+$lint_fail; }width:100% found in $OUTPUT — tables will not be compact"
fi
if [ -n "$lint_fail" ]; then
    echo "$LOG_PREFIX [ERROR] $lint_fail"
    cron_alert "ai-health" "Pre-push HTML lint failed: $lint_fail"
    exit 1
fi

# ─── Pre-push lint: no <th> tags in HTML generators ────────────────────────────
# <th> causes Google Docs to inherit bold to all cells in the column.
# Use <td><b>...</b></td> for header cells instead.
# Match only string-literal emissions of <th> — skip prose references in
# docstrings/comments like "avoid <th>, use <td><b>" which aren't emitted HTML.
th_usage=""
for html_gen in "$HOME/work/claude/private_scripts/md-to-html.py" "$HOME/work/claude/private_scripts/ai-health-push.py" "$SCRIPT_DIR/generate-ai-health-html.sh"; do
    [ -f "$html_gen" ] || continue
    if grep -qP "['\"\`]<th[\s>]" "$html_gen" 2>/dev/null; then
        th_usage="${th_usage:+$th_usage; }$(basename "$html_gen") uses <th>"
    fi
done
if [ -n "$th_usage" ]; then
    echo "$LOG_PREFIX [ERROR] Pre-push lint: <th> tags found — use <td><b> instead: $th_usage"
    cron_alert "ai-health" "Pre-push lint: <th> found in HTML generators: $th_usage"
    exit 1
fi

# ─── Pre-push lint: Cron Fleet table must have exactly 5 columns per row ──────
# PLAYBOOK RULE 18: schema is Job | Status | Runs | Last Run (Detail) | Pass Rate (Duration)
# Markdown row "| A | B | C | D | E |" has NF-2 content columns when split by |
bad_col_rows=$(awk '/^#+ Cron Fleet/,/^---/' "$OUTPUT" | grep "^|" | grep -v "^|---" | awk -F'|' 'NF-2 != 5 {print NR": "NF-2" cols: "$0}')
if [ -n "$bad_col_rows" ]; then
    echo "$LOG_PREFIX [ERROR] Cron Fleet table rows with wrong column count (expected 5):"
    echo "$bad_col_rows" | head -5
    exit 1
fi

# ─── Pre-push lint (PLAYBOOK RULE 19): no all-placeholder AI Impact rows ─────
# A metric row whose BOTH data columns (7d AND All Time) are bare "—"/empty is
# pure sparseness — an uninstrumented metric taking up a row. Don't ship it;
# instrument the metric or drop the row. (Denny gdoc comment 2026-05-30.)
sparse_impact_rows=$(awk '/^## AI Impact/,/^## Health/' "$OUTPUT" | grep "^|" | grep -vE "^\| # |^\|---" | awk -F'|' '{
    d7=$4; allt=$5
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",d7); gsub(/^[[:space:]]+|[[:space:]]+$/,"",allt)
    if ((d7=="" || d7=="—" || d7=="-") && (allt=="" || allt=="—" || allt=="-")) {
        name=$3; gsub(/^[[:space:]]+|[[:space:]]+$/,"",name); print name
    }
}')
if [ -n "$sparse_impact_rows" ]; then
    echo "$LOG_PREFIX [ERROR] PLAYBOOK RULE 19: all-placeholder AI Impact row(s) (7d AND All Time both empty/—): $sparse_impact_rows"
    cron_alert "ai-health" "AI Impact all-placeholder row(s): $sparse_impact_rows — instrument or drop"
    exit 1
fi

# ─── Pre-push warning (PLAYBOOK RULE 13): 0% pass rate → non-empty detail ───
# Note: used to `exit 1` here, which caused the dashboard to silently skip push
# every morning from 2026-04-15 onwards when a weekly/unscheduled job still had
# no detail text. Warn only — dashboard content is more valuable than perfection.
# Matches new top-level heading "## Cron Fleet (7d)" AND legacy "### Cron Fleet".
zero_rate_no_detail=$(awk '/^#+ Cron Fleet/,/^---/' "$OUTPUT" | grep "^|" | grep -v "^| Job\|^|---" | awk -F'|' '{
    last_run_detail=$5; pass_rate_dur=$6
    gsub(/[[:space:]]/,"",pass_rate_dur)
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",last_run_detail)
    # pass rate is embedded like "0% (Xs avg)" or "—"
    split(pass_rate_dur, pr, "%")
    rate=pr[1]
    if ((rate == "0" || rate == "—") && (last_run_detail == "" || last_run_detail == "—")) {
        name=$2; gsub(/[[:space:]]/,"",name); print name
    }
}')
if [ -n "$zero_rate_no_detail" ]; then
    echo "$LOG_PREFIX [WARN] PLAYBOOK RULE 13: rows with pass_rate=0 have empty detail: $zero_rate_no_detail (not blocking push)"
fi

# ─── Pre-push lint: PLAYBOOK RULE 24 — reject non-actionable Action Required rows ──
# Scan Action Required rows for patterns that should have been filtered upstream.
# If any slip through (e.g., new code path bypasses the gate), warn + log to ALERTS.md.
_r24_violations=""
if [ -f "$OUTPUT" ]; then
    _r24_violations=$(awk '/^## Action Required/,/^## [^A]/' "$OUTPUT" \
        | grep "^|" | grep -v "^| Priority\|^|---" \
        | grep -iE "daemon restart|auto.retry|recovered on retry|self-resolved|self-healed|auth refresh|token refresh|restarted successfully|Zero inbound.*working hours" \
        | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}' || true)
fi
if [ -n "$_r24_violations" ]; then
    echo "$LOG_PREFIX [WARN] PLAYBOOK RULE 24: non-actionable rows in Action Required (removing):"
    echo "$_r24_violations" | head -5
    # Remove violating rows from output and log
    python3 -c "
import re
violations = '''$_r24_violations'''.strip().split('\n')
lines = open('$OUTPUT').readlines()
filtered = []
removed = []
for line in lines:
    skip = False
    for v in violations:
        if v.strip() and v.strip() in line:
            skip = True
            removed.append(v.strip())
            break
    if not skip:
        filtered.append(line)
open('$OUTPUT', 'w').writelines(filtered)
for r in removed:
    print(f'removed: {r}')
" 2>/dev/null || true
    # Log to ALERTS.md
    for _v in $(echo "$_r24_violations" | head -3); do
        echo "$LOG_PREFIX   RULE 24 lint: non-actionable row rejected: $_v"
    done
fi

# ─── Prune staleness-alert rows for disabled docs before push ────────────────
if [ ${#STALENESS_DISABLED_NAMES[@]} -gt 0 ]; then
    _pruned=0
    for _dname in "${STALENESS_DISABLED_NAMES[@]}"; do
        # Remove rows that are staleness alerts referencing the disabled doc name
        _before=$(wc -l < "$OUTPUT")
        python3 -c "
import re, sys
lines = open('$OUTPUT').readlines()
filtered = []
for line in lines:
    # Match staleness-alert rows: contain both 'stale' (case-insensitive) and the doc name
    if 'stale' in line.lower() and '$_dname' in line:
        continue
    filtered.append(line)
open('$OUTPUT', 'w').writelines(filtered)
print(len(lines) - len(filtered))
" 2>/dev/null
        _after=$(wc -l < "$OUTPUT")
        _pruned=$((_pruned + _before - _after))
    done
    [ "$_pruned" -gt 0 ] && echo "$LOG_PREFIX   Pruned $_pruned staleness rows for disabled docs: ${STALENESS_DISABLED_NAMES[*]}"
fi

echo "$LOG_PREFIX Dashboard written to $OUTPUT"
echo "$LOG_PREFIX Health: $health — $health_reasons"

# ─── Shadow mode: lints comparator (observe-only) ────────────────────────────
# Validates private_scripts/lib/ai_health_lints.py against the bash lints above.
# Wrapped in `|| true` and CANNOT fail the parent script.
{
    if [ -f "$OUTPUT.shadow-orig" ]; then
        _disabled_joined=""
        if [ ${#STALENESS_DISABLED_NAMES[@]} -gt 0 ]; then
            _disabled_joined=$(IFS=':'; echo "${STALENESS_DISABLED_NAMES[*]}")
        fi
        python3 "$HOME/work/claude/private_scripts/lib/ai_health_lints_shadow.py" \
            --orig "$OUTPUT.shadow-orig" \
            --bash-final "$OUTPUT" \
            --html-gen "$HOME/work/claude/private_scripts/md-to-html.py,$HOME/work/claude/private_scripts/ai-health-push.py,$SCRIPT_DIR/generate-ai-health-html.sh" \
            --disabled-names "$_disabled_joined" 2>&1 | sed "s/^/$LOG_PREFIX /"
        rm -f "$OUTPUT.shadow-orig"
    fi
} || true

# ─── Save today's summary to history ─────────────────────────────────────────
python3 -c "
import json, datetime
history_file = '$AI_HEALTH_HISTORY'
today = '$TODAY'
fleet_rate = int('${fleet_rate:-0}')
health = '${health:-UNKNOWN}'
health_reasons = '${health_reasons:-}'
# Build one-line summary
action_count_str = '${action_rows:-}'
import re
n_actions = len([l for l in action_count_str.split('\n') if l.strip().startswith('|') and '----' not in l])
summary = f'{n_actions} action items' if n_actions > 0 else 'no actions'
today_entry = {'date': today, 'health': health, 'fleet_rate': fleet_rate, 'summary': summary, 'generated_at': datetime.datetime.utcnow().isoformat()}
try:
    history = json.load(open(history_file))
except:
    history = []
# Replace today's entry if exists, keep last 14 days
history = [h for h in history if h.get('date') != today]
history.append(today_entry)
cutoff = (datetime.date.today() - datetime.timedelta(days=14)).isoformat()
history = [h for h in history if h.get('date','') >= cutoff]
history.sort(key=lambda x: x.get('date',''), reverse=True)
import os; os.makedirs(os.path.dirname(history_file), exist_ok=True)
json.dump(history, open(history_file,'w'), indent=2)
print(f'History saved: {len(history)} entries')
" 2>/dev/null && echo "$LOG_PREFIX History updated" || echo "$LOG_PREFIX [WARN] History save failed"

# ─── Google Doc update ────────────────────────────────────────────────────────
GDOC_ID="$(get_doc_id ai_playbook)"

# Address open comments BEFORE adding the new day's content (operator rule 2026-06-14)
gdoc_address_comments_first "$GDOC_ID"

# Tier 3: capture pre-push revision so validation failures can tell humans
# which revision to restore via File → Version history.
gdocs_capture_prepush_revision "$GDOC_ID" "ai_health" || true

write_heartbeat "ai-health"
echo "$LOG_PREFIX === AI Health Done ==="

# ─── Auto-push (accumulating — prior dates preserved) ────────────────────────
# push.py strategy:
#   NEW day  → prepend today's full section at index 1 (prior days stay below)
#   SAME day → update existing cells in-place via batch-update + find-replace
# Either way, doc comments are preserved (no gdocs replace on main tab).
if command -v gdocs &>/dev/null; then
    # Pre-push: capture live column widths — preserves any manual width
    # adjustments made since last run (PLAYBOOK RULE 18).
    TABLE_FORMAT_SNAPSHOT="${CLAUDE_STATE_DIR:-$HOME/work/claude/state}/ai-playbook-cron-table-format-snapshot.json"
    echo "$LOG_PREFIX   Pre-push: capturing live column widths..."
    gdocs_capture_table_format_snapshot "$GDOC_ID" "t.0" "$TABLE_FORMAT_SNAPSHOT" || true

    python3 "$HOME/work/claude/private_scripts/ai-health-push.py" "$OUTPUT" 2>&1 && \
        echo "$LOG_PREFIX Auto-pushed (comments preserved)" && \
        tab_freshness_mark "ai-playbook-health" || \
        echo "$LOG_PREFIX [WARN] Comment-preserving push failed"

    # Restore table format from the pre-push snapshot (includes manual
    # width changes). Falls back to config-driven widths on first run.
    # Re-captures snapshot after apply and asserts non-equal-width columns.
    if ! restore_table_format "$GDOC_ID" "t.0" "$TABLE_FORMAT_SNAPSHOT" "ai_playbook"; then
        echo "$LOG_PREFIX   [WARN] Column widths may be equal — retrying after gmux restart"
        pkill -9 -f "google-mux daemon" 2>/dev/null || true
        rm -f /tmp/gmux-${USER}*.sock 2>/dev/null || true
        sleep 3
        restore_table_format "$GDOC_ID" "t.0" "$TABLE_FORMAT_SNAPSHOT" "ai_playbook" || \
            echo "$LOG_PREFIX   [WARN] Column widths still equal after retry"
    fi

    # Set 11pt body font on all tables + clean empty lines
    echo "$LOG_PREFIX   Formatting tables (11pt body font, cleanup empty lines)..."
    structure=$(timeout 30 gdocs content get-structure "$GDOC_ID" --tab-id "t.0" 2>/dev/null || true)
    if [ -n "$structure" ]; then
        # Font sizing: 11pt across tables + non-empty body paragraphs.
        # Surfaces helper errors instead of silently swallowing to "[]".
        font_json=$(echo "$structure" | python3 "$GDOCS_HELPER_PY" body-font --tab-id "t.0" --size 11) \
            || gdocs_track_error "body-font helper failed (ai-health) at $0:$LINENO"
        if [ -n "${font_json:-}" ] && [ "$font_json" != "[]" ]; then
            if echo "$font_json" | gdocs batch-update "$GDOC_ID" --data - 2>/dev/null; then
                echo "$LOG_PREFIX   Body fonts set to 11pt"
            else
                gdocs_track_error "batch-update failed (ai-health-body-font) at $0:$LINENO"
            fi
        fi

        # Empty line cleanup: use shared script
        source ~/work/claude/scripts/gdocs-cleanup-empty-lines.sh
        gdocs_cleanup_empty_lines "$GDOC_ID" --tab-id "t.0" --log-prefix "$LOG_PREFIX  "
    fi
fi

# ─── Archive old AI Playbook entries (>archive_days) to Archive tab ──────────
# Pattern adapted from cron-nightly-routine-preprocessing.sh Section 2c.
# Date headings are HEADING_2 ("## AI Playbook — YYYY-MM-DD"), not HEADING_1.
# The doc top-level "# AI Playbook" (HEADING_1) is preserved.
# Retention window is configured via DAILY-DOCS.json -> docs.ai_playbook.archive_days.
AI_PLAYBOOK_ARCHIVE_TAB_ID="$(get_doc_tab ai_playbook archive 2>/dev/null)" || AI_PLAYBOOK_ARCHIVE_TAB_ID=""
AI_PLAYBOOK_ARCHIVE_DAYS="$(get_doc_setting ai_playbook archive_days 7)"

if [ -n "$AI_PLAYBOOK_ARCHIVE_TAB_ID" ] && command -v gdocs &>/dev/null; then
    echo "$LOG_PREFIX [archive] Archiving old AI Playbook entries (>${AI_PLAYBOOK_ARCHIVE_DAYS} days) to Archive tab..."

    # Algorithm: archive only contiguous H2 "AI Playbook — YYYY-MM-DD" or
    # "AI Health Dashboard — YYYY-MM-DD" (legacy) sections that are older than the cutoff.
    # The deletion range is bounded by the next non-matching H2 so we never delete
    # unrelated content.
    archive_range=$( (timeout 30 gdocs content get-structure "$GDOC_ID" --tab-id t.0 2>/dev/null || true) | python3 -c "
import sys, re
from datetime import datetime, timedelta

today = datetime.strptime('$TODAY', '%Y-%m-%d')
cutoff = today - timedelta(days=$AI_PLAYBOOK_ARCHIVE_DAYS)

lines = sys.stdin.read().strip().split('\n')
sections = []  # (start_index, kind) where kind in {'old', 'fresh', 'foreign'}
max_index = 1

for line in lines:
    for idx_str in re.findall(r'\d+(?=\])', line):
        idx = int(idx_str)
        if idx > max_index:
            max_index = idx
    idx_match = re.match(r'^\[(\d+)', line)
    if not idx_match or 'HEADING_2' not in line:
        continue
    idx = int(idx_match.group(1))
    m = re.search(r'(?:AI Playbook|AI Health Dashboard)\s*[—-]\s*(\d{4}-\d{2}-\d{2})', line)
    if m:
        try:
            d = datetime.strptime(m.group(1), '%Y-%m-%d')
            sections.append((idx, 'old' if d < cutoff else 'fresh'))
            continue
        except ValueError:
            pass
    sections.append((idx, 'foreign'))

arch_start = None
arch_end = None
for i, (idx, kind) in enumerate(sections):
    if kind == 'old':
        arch_start = idx
        for j in range(i + 1, len(sections)):
            if sections[j][1] != 'old':
                arch_end = sections[j][0]
                break
        if arch_end is None:
            arch_end = max_index
        break

if arch_start and arch_end and arch_end > arch_start:
    print(f'{arch_start} {arch_end}')
" 2>/dev/null || true)

    if [ -n "$archive_range" ]; then
        arch_start=$(echo "$archive_range" | awk '{print $1}')
        arch_end=$(echo "$archive_range" | awk '{print $2}')
        if [ "$arch_end" -gt "$arch_start" ]; then
            # NOTE: gdocs export does not accept --tab-id; it exports the active/main tab,
            # which is "AI Playbook" (t.0). The Archive tab (t.n5lk1bozt4ho) is excluded.
            gdocs export "$GDOC_ID" --format md > /tmp/ai-playbook-full-export.md 2>/dev/null || true
            if [ -f /tmp/ai-playbook-full-export.md ] && [ -s /tmp/ai-playbook-full-export.md ]; then
                python3 -c "
import re
from datetime import datetime, timedelta
today = datetime.strptime('$TODAY', '%Y-%m-%d')
cutoff = today - timedelta(days=$AI_PLAYBOOK_ARCHIVE_DAYS)
with open('/tmp/ai-playbook-full-export.md') as f:
    content = f.read()
# Split by H2 'AI Playbook — YYYY-MM-DD' headings
sections = re.split(r'(?=^##\s*(?:AI Playbook|AI Health Dashboard)\s*[—-]\s*\d{4}-\d{2}-\d{2})', content, flags=re.MULTILINE)
old_sections = []
for s in sections:
    date_match = re.match(r'##\s*(?:AI Playbook|AI Health Dashboard)\s*[—-]\s*(\d{4}-\d{2}-\d{2})', s.strip())
    if date_match:
        try:
            d = datetime.strptime(date_match.group(1), '%Y-%m-%d')
            if d < cutoff:
                old_sections.append(s)
        except ValueError:
            pass
if old_sections:
    with open('/tmp/ai-playbook-archive-content.md', 'w') as f:
        f.write('\n'.join(old_sections))
    print(f'{len(old_sections)} old AI Playbook entries extracted')
else:
    print('no old AI Playbook entries found')
" 2>/dev/null
                if [ -f /tmp/ai-playbook-archive-content.md ] && [ -s /tmp/ai-playbook-archive-content.md ]; then
                    timeout 60 gdocs content insert-text "$GDOC_ID" @/tmp/ai-playbook-archive-content.md --markdown --index 1 --tab-id "$AI_PLAYBOOK_ARCHIVE_TAB_ID" 2>/dev/null \
                        && { echo "$LOG_PREFIX   Old entries prepended to AI Playbook Archive tab"; tab_freshness_mark "ai-playbook-archive"; } \
                        || echo "$LOG_PREFIX   [WARN] Archive tab prepend failed"
                    rm -f /tmp/ai-playbook-archive-content.md
                fi
            fi
            # Delete old content from the main Playbook tab
            # Re-fetch structure to get current indices (earlier operations may have shifted them)
            archive_range_fresh=$( (timeout 30 gdocs content get-structure "$GDOC_ID" --tab-id t.0 2>/dev/null || true) | python3 -c "
import sys, re
from datetime import datetime, timedelta
today = datetime.strptime('$TODAY', '%Y-%m-%d')
cutoff = today - timedelta(days=$AI_PLAYBOOK_ARCHIVE_DAYS)
lines = sys.stdin.read().strip().split('\n')
sections = []
max_index = 1
for line in lines:
    for idx_str in re.findall(r'\d+(?=\])', line):
        idx = int(idx_str)
        if idx > max_index:
            max_index = idx
    idx_match = re.match(r'^\[(\d+)', line)
    if not idx_match or 'HEADING_2' not in line:
        continue
    idx = int(idx_match.group(1))
    m = re.search(r'(?:AI Playbook|AI Health Dashboard)\s*[—-]\s*(\d{4}-\d{2}-\d{2})', line)
    if m:
        try:
            d = datetime.strptime(m.group(1), '%Y-%m-%d')
            sections.append((idx, 'old' if d < cutoff else 'fresh'))
            continue
        except ValueError:
            pass
    sections.append((idx, 'foreign'))
arch_start = None
arch_end = None
for i, (idx, kind) in enumerate(sections):
    if kind == 'old':
        arch_start = idx
        for j in range(i + 1, len(sections)):
            if sections[j][1] != 'old':
                arch_end = sections[j][0]
                break
        if arch_end is None:
            arch_end = max_index
        break
if arch_start and arch_end and arch_end > arch_start:
    print(f'{arch_start} {arch_end}')
" 2>/dev/null || true)
            if [ -n "$archive_range_fresh" ]; then
                arch_start=$(echo "$archive_range_fresh" | awk '{print $1}')
                arch_end=$(echo "$archive_range_fresh" | awk '{print $2}')
            fi
            delete_err=$(echo "[{\"deleteContentRange\":{\"range\":{\"startIndex\":$arch_start,\"endIndex\":$((arch_end - 1)),\"tabId\":\"t.0\"}}}]" \
                | gdocs batch-update "$GDOC_ID" --data - 2>&1) && {
                echo "$LOG_PREFIX   Old entries deleted from main Playbook tab (index $arch_start to $arch_end)"
            } || {
                echo "$LOG_PREFIX   [WARN] Archive delete failed (non-fatal): $delete_err" | head -c 300
            }
        fi
    else
        echo "$LOG_PREFIX   No old AI Playbook entries to archive"
    fi

    rm -f /tmp/ai-playbook-full-export.md /tmp/ai-playbook-archive-content.md
fi

# Tier 1+3: propagate accumulated gdocs errors (batch-update + post-push validation).
gdocs_exit_with_status "$(basename "$0" .sh)"
