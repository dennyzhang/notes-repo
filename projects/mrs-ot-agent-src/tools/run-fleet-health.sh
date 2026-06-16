#!/usr/bin/env bash
# run-fleet-health.sh — ONE deterministic orchestrator for the fleet-health cron.
#
# scan(×3, parallel) → persist → render → deliver. ALL logic lives here in code so
# the run is reproducible; the markdown cron prompt is just a thin wrapper that runs
# this and echoes its stdout. 2026-06-05 (operator: "make the fleet cron logic as
# stable as possible; if necessary move logic from markdown to sh"). This removes
# LLM variance from orchestration AND delivery — the LLM does zero arithmetic, zero
# branching, zero formatting.
#
# stdout contract = the cron's FINAL response, verbatim:
#   - "HEARTBEAT_OK"               → fleet clean, OR digest already delivered to team
#                                     by THIS script (so the daemon never double-posts).
#   - "⚠️ fleet-health: <detail>"  → a check/reconcile/send failure (daemon delivers it).
# Diagnostics (scan stderr, reconcile report, send result) → this script's stderr.
#
# Flags:
#   --dry-run   do everything EXCEPT the team-space send and the persist write;
#               print what WOULD be sent. For testing.
#
# Exit: always 0 (the meaningful signal is the single stdout line, per the contract).
set -uo pipefail   # NOT -e: scan non-zero rc's are DATA, not fatal.

# ---- SELF-AUDIT: the job must measure ITSELF, not just the fleet -------------
# 2026-06-10 operator: "why can't you find these problems independently?" — a 5→9m
# latency regression and a ttfb false-clean both surfaced as narration instead of
# findings because nothing watched the run's OWN health against a threshold. Fix:
# time the run vs a budget and emit a loud regression line to stderr (→ raw_response,
# picked up by the human-attention brief). Self-instrumentation, not "try harder".
SELF_START=${SECONDS}
LATENCY_BUDGET_S=420   # 7m: norm is 5-6m; over budget = a finding about MYSELF.

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="${SRC_DIR}/tools"
TEAM_SPACE="spaces/AAQA2bZMw24"
OPERATOR_SPACE="spaces/AAQAVOjYc80"   # operator 1:1 — routine (non-team-worthy) digests go here
DRY=false
[[ "${1:-}" == "--dry-run" ]] && DRY=true

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# rc 124 (timeout) → 2 (check could-not-run), matching the scans' own convention.
norm_rc() { [[ "$1" == "124" ]] && echo 2 || echo "$1"; }

# ---- 0. preflight: validate models.md (the scans' input) --------------------
# models.md is hand/agent-curated with no deterministic generator; drift (a row
# missing its entity_id= link, a dup, a non-uniform column count) makes the scans
# SILENTLY drop models from coverage. Run the gate every cycle so drift surfaces
# in this run's stderr (captured in raw_response → ot-human-attention-brief).
# Non-fatal: a Customer-enum typo must never block zombie detection.
if MODELS_VALIDATION="$(python3 "${TOOLS}/validate-models.py" 2>&1)"; then
  echo "[run-fleet-health] models.md validation: clean" >&2
else
  echo "⚠️ [run-fleet-health] models.md validation FAILED — scans may under-cover; fix + rerun tools/validate-models.py:" >&2
  echo "${MODELS_VALIDATION}" | sed 's/^/    /' >&2
fi

# ---- 0.1 preflight: renderer golden self-test (can't-skip regression guard) --
# model_type was dropped from the digest TWICE (2026-06-10/11) because the per-finding
# display label was copy-pasted across 6 format strings. The structural fix is the
# single label() helper; THIS preflight makes a regression impossible to ship silently
# — it renders one line per finding type and asserts model_type/tier/pg are present. It
# also catches a hard-broken renderer (e.g. a recursion bug) BEFORE we try to render the
# real digest. Non-fatal + loud (matches models-validation): surfaces in raw_response.
if RENDER_SELFTEST="$(python3 "${TOOLS}/test-render-digest.py" 2>&1)"; then
  echo "[run-fleet-health] render self-test: ${RENDER_SELFTEST}" >&2
else
  echo "⚠️ [run-fleet-health] RENDER SELF-TEST FAILED — a required display field (model_type/tier/pg) is dropped or the renderer is broken; fix render-fleet-digest.py:" >&2
  echo "${RENDER_SELFTEST}" | sed 's/^/    /' >&2
fi

# ---- 1. scans (parallel) ----------------------------------------------------
timeout 900 bash "${TOOLS}/scan-zombie-fleet.sh"              >"${TMP}/z" 2>"${TMP}/z.err" & zp=$!
timeout 900 bash "${TOOLS}/scan-scribe-age.sh"               >"${TMP}/s" 2>"${TMP}/s.err" & sp=$!
timeout 900 bash "${TOOLS}/scan-perf-regression.sh" --json-only >"${TMP}/p" 2>"${TMP}/p.err" & pp=$!
timeout 900 bash "${TOOLS}/scan-pkg-expiry.sh" --json-only    >"${TMP}/x" 2>"${TMP}/x.err" & xp=$!
timeout 900 bash "${TOOLS}/scan-dpp-starvation.sh" --json-only >"${TMP}/d" 2>"${TMP}/d.err" & dp=$!
timeout 900 bash "${TOOLS}/scan-ttfb.sh" --json-only          >"${TMP}/t" 2>"${TMP}/t.err" & tp=$!
wait $zp; zrc=$(norm_rc $?)
wait $sp; src=$(norm_rc $?)
wait $pp; prc=$(norm_rc $?)
wait $xp; xrc=$(norm_rc $?)
wait $dp; drc=$(norm_rc $?)
wait $tp; trc=$(norm_rc $?)
echo "[run-fleet-health] scan rc: zombie=${zrc} scribe=${src} perf=${prc} pkg-expiry=${xrc} dpp=${drc} ttfb=${trc}" >&2

# ---- SELF-AUDIT (scans done) ------------------------------------------------
# (1) Latency vs budget — a regression is a finding about the job, surfaced not narrated.
SELF_ELAPSED=$(( SECONDS - SELF_START ))
if [ "${SELF_ELAPSED}" -gt "${LATENCY_BUDGET_S}" ]; then
  echo "⚠️ [self-audit] fleet-health wall-time ${SELF_ELAPSED}s > budget ${LATENCY_BUDGET_S}s — LATENCY REGRESSION; check meta latency / scan concurrency (zombie fan-out is the usual long pole)" >&2
fi
# (2) Window-gated scans must prove they EVALUATED something — a false-clean is a scan
# that judged ~0 jobs yet reported clean (the ttfb 0/56-skipped trap, 2026-06-10).
# ttfb summary now carries in_window; assert it, so "0 flagged" can't masquerade as
# "all healthy" when really nothing was in the window to judge.
ttfb_iw=$(python3 -c "import json,sys;print(json.load(open('${TMP}/t')).get('summary',{}).get('in_window','?'))" 2>/dev/null || echo "?")
if [ "${ttfb_iw}" = "0" ]; then
  echo "ℹ️ [self-audit] ttfb in_window=0 — NO jobs were cold-starting this run; 'ttfb clean' means 'nothing to judge', not 'all healthy' (render shows 0/0)" >&2
fi

# ---- 2.0. ZOMBIE HANDLING — READ-ONLY (operator revoked auto-kill 2026-06-08:
#           "no, you are not allowed to kill the zombie job. Revert it"). The bot is
#           back to fully read-only on MAST job state: scan-confirmed zombies render as
#           act-now items for a HUMAN to kill — the bot never mutates job state itself.
#           Empty zkills file = digest shows every zombie as act-now (manual), no
#           "auto-killed" line. (No kill ever fired before this revert: audit log empty.)
: > "${TMP}/zkills"

# ---- 2.1. SYSTEMIC-GAP auto-task (operator 2026-06-07: "10+ models same pattern =
#           systematic gap → auto-file follow-up → explore mitigation → work it").
#           Files ONE deduped, handhold-first task per ≥5-model perf subsystem; the
#           task carries the confirm-root (diurnal vs real) + deep-diagnose + mitigation-
#           routing plan. All output → stderr (keeps the stdout contract clean).
if ! ${DRY}; then
  python3 "${TOOLS}/file-systemic-gap-task.py" --perf "${TMP}/p" >&2 2>&1 || \
    echo "[run-fleet-health] WARN: systemic-gap task step failed (non-fatal)" >&2
fi

# ---- 2. persist (deterministic history; skip on dry-run) --------------------
if ! ${DRY}; then
  bash "${TOOLS}/persist-fleet-history.sh" \
    --zombie "${TMP}/z" --zombie-rc "${zrc}" \
    --scribe "${TMP}/s" --scribe-rc "${src}" \
    --perf   "${TMP}/p" --perf-rc   "${prc}" >&2 2>&1 || \
    echo "[run-fleet-health] WARN: persist failed (non-fatal)" >&2
fi

# ---- 3. render (deterministic digest + reconciliation gate) -----------------
digest="$(python3 "${TOOLS}/render-fleet-digest.py" \
  --zombie "${TMP}/z" --zombie-rc "${zrc}" \
  --scribe "${TMP}/s" --scribe-rc "${src}" \
  --perf   "${TMP}/p" --perf-rc   "${prc}" \
  --pkg-expiry "${TMP}/x" --pkg-expiry-rc "${xrc}" \
  --dpp-starvation "${TMP}/d" --dpp-starvation-rc "${drc}" \
  --ttfb "${TMP}/t" --ttfb-rc "${trc}" \
  --zombie-kills "${TMP}/zkills" 2>"${TMP}/render.err")"
rrc=$?
cat "${TMP}/render.err" >&2

# ---- 4. deliver strictly by renderer exit code ------------------------------
case "${rrc}" in
  1)  # all clean
      echo "HEARTBEAT_OK"
      ;;
  0)  # problems rendered. ROUTE BY TEAM-WORTHINESS (operator 2026-06-14 "this msg
      # should send to 1:1 gchat"): a DOWN/systemic incident (🧟/🐌/📊 or *N models*)
      # → TEAM space; routine single-model age/perf drift → OPERATOR 1:1 (still
      # surfaced, just not the shared room). render-fleet-digest.py writes the verdict
      # as `TEAM_WORTHY=0|1` to render.err. Default to 1:1 if the marker is missing
      # (fail-safe: never default routine noise INTO the team room).
      tw="$(sed -n 's/^TEAM_WORTHY=//p' "${TMP}/render.err" | head -1)"
      if [ "${tw}" = "1" ]; then DEST="${TEAM_SPACE}"; else DEST="${OPERATOR_SPACE}"; fi
      if ${DRY}; then
        echo "[dry-run] would send to ${DEST} (team_worthy=${tw:-0}):" >&2
        printf '%s\n' "${digest}" >&2
        echo "HEARTBEAT_OK"
      elif meta google.chat.message send --space-name="${DEST}" --text="${digest}" >"${TMP}/send" 2>&1; then
        echo "[run-fleet-health] delivered to ${DEST} (team_worthy=${tw:-0})" >&2
        echo "HEARTBEAT_OK"
      else
        echo "⚠️ fleet-health: digest computed but SEND FAILED — $(head -1 "${TMP}/send")"
      fi
      ;;
  3)  # reconciliation failed → renderer withheld the digest (numbers didn't add up)
      echo "⚠️ fleet-health: digest WITHHELD (reconcile failed) — $(grep -m1 . "${TMP}/render.err" | sed 's/RECONCILE-FAIL://')"
      ;;
  *)  # any scan could not run / unexpected renderer exit → fleet status UNKNOWN
      echo "⚠️ fleet-health: could not produce digest (scan rc z=${zrc} s=${src} p=${prc} x=${xrc} d=${drc} t=${trc}, render exit ${rrc}); check meta access / re-run scans"
      ;;
esac

# ---- 5. chronic → deduped tracking task (generalizes ot-alert-monitor's auto-fix
#         pattern to fleet-health; 14c sweep, 2026-06-05). A model breaching every
#         one of the last N runs gets ONE owner=dennyzhang task (helper dedups per
#         model+signal; cap 3/run here to avoid a first-run task storm). ALL output
#         → stderr so the stdout contract (the cron's final response) stays clean.
if ! ${DRY}; then
  while IFS='|' read -r ceid csig cowner cclass cev; do
    [[ -n "${ceid}" ]] || continue
    bash "${TOOLS}/file-chronic-fleet-task.sh" --eid "${ceid}" --signal "${csig}" \
      --class "${cclass}" --evidence "${cev}" ${cowner:+--owner-unixname "${cowner}"} \
      --mast-url "https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-${ceid}" \
      >&2 2>&1 || true
  done < <(python3 "${TOOLS}/detect-chronic-fleet.py" 2>/dev/null | head -3)
fi
exit 0
