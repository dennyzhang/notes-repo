# shellcheck shell=bash
# lib-qps.sh — shared training-QPS fetch helper for OT fleet-health scans.
#
# Single source of truth for FETCHING a model's training-QPS series, with the
# failure-vs-empty discipline that scan-perf-regression.sh hardened (codex
# 2026-06-03 / 2026-06-05). The PARSING + rate half lives in lib_qps.py (sourced
# by both scans' python). Centralizing here avoids a third divergent copy in
# scan-scribe-age.sh.
#
# PRIMARY metric (coverage fix 2026-06-05): ODS `dpp_worker.num_examples_read.sum.60`
# on `regex(mast.mvai-training-online-<EID>.*.dpp_worker.*)` — the SAME dpp_worker
# entity family our scribe_example_age_ms metric uses, so it covers the WHOLE
# fleet (retrieval/HSTU models included, which never emitted qps/global/window/
# train). The metric is a per-60s-window SUM emitted PER dpp_worker shard; summing
# the shard rows per timestamp and dividing by 60 yields a clean examples/sec rate
# — NO cumulative-counter Δ/Δt derivation needed. Verified unit-consistent with
# the old TB key on a model that emits both (2123426413: TB ~17.9K/s vs
# shard-sum/60 ~15–18K/s, 2026-06-05).
#
# FALLBACK metric: TB `qps/global/window/train` (mvai_metrics scuba), kept ONLY
# for the rare case the ODS metric is empty. The old `qps-qps|total_examples`
# Δ/Δt derivation is RETIRED — the dpp_worker metric makes it dead code.
#
# Source this file, then call:
#   fetch_qps_json <entity_id> <hours>
# It sets two globals for the caller to pass into python (as QPS_J / QPSQ_J):
#   QPS_FETCH_PRIMARY   — COMPACT pre-reduced dpp_worker series, one
#                         `<timestamp> <rate_per_sec>` line per 5m bucket (the
#                         raw multi-MB ODS text is reduced in-shell via lib_qps.py
#                         --reduce-dpp-worker so it never crosses the env ARG_MAX
#                         boundary — a 168h × 50-shard raw pull is 2-5 MB > ARG_MAX).
#                         A leading `# present` line means dpp_worker rows existed.
#   QPS_FETCH_FALLBACK  — raw `-o json` for qps/global/window/train (or "[]")
# and RETURNS:
#   0 = fetch ok (either family may still be empty = genuinely no metric)
#   2 = a fetch FAILED (timeout / query error, rc!=0) — caller must treat as a
#       probe failure (ERROR / cause_class=unknown), NEVER a silent empty.

# fetch_qps_json <entity_id> <hours>  ->  sets QPS_FETCH_PRIMARY / QPS_FETCH_FALLBACK; rc 0|2
fetch_qps_json() {
  local EID="$1"
  local HOURS="$2"
  QPS_FETCH_PRIMARY=""
  QPS_FETCH_FALLBACK="[]"

  # PRIMARY: ODS dpp_worker.num_examples_read.sum.60 over the baseline window.
  # Same entity family + query shape as scan-scribe-age's scribe_example_age_ms,
  # so coverage matches (whole fleet). Distinguish a fetch FAILURE (timeout /
  # ODS error, rc!=0 → return 2) from a genuinely empty result (rc==0, "" → real
  # "not emitting"). Granularity 5m (buckets the per-shard sum.60 metric);
  # python sums shard rows per-timestamp then derives a per-second rate.
  # Reduce the (potentially multi-MB) raw ODS text IN-SHELL with a stdin pipe to
  # lib_qps.py --reduce-dpp-worker, capturing the compact per-bucket series. The
  # raw text never crosses an env/argv boundary (it would exceed ARG_MAX). We
  # must distinguish a fetch FAILURE (the ODS query rc!=0) from a genuinely empty
  # result; PIPESTATUS gives us the query's rc through the pipe.
  local NOW START QPS_COMPACT qrc lib_dir
  NOW=$(date +%s)
  START=$(( NOW - HOURS * 3600 ))
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  QPS_COMPACT=$(timeout 90 meta ods.metric query \
    -e "regex(mast.mvai-training-online-${EID}.*.dpp_worker.*)" \
    -k 'dpp_worker.num_examples_read.sum.60' \
    --start-time "${START}" --end-time "${NOW}" --granularity 5m 2>/dev/null \
    | python3 "${lib_dir}/lib_qps.py" --reduce-dpp-worker "${EID}")
  qrc="${PIPESTATUS[0]}"
  if [ "${qrc}" -ne 0 ]; then return 2; fi
  QPS_FETCH_PRIMARY="${QPS_COMPACT}"

  # FALLBACK: TB qps/global/window/train — fetched whenever the ODS primary
  # yielded no usable DATA rows (no derivable per-second rate), which includes
  # both "no dpp_worker coverage at all" (empty output) AND "rollup-only / no
  # shard rows" (output is just the `# present` marker). In the rollup-only case
  # the primary still can't produce a rate, so a TB series — if one exists — is a
  # better answer than skipping straight to "dead" (codex 2026-06-05). Same
  # failure-vs-empty discipline: rc!=0 (timeout/auth/schema) → return 2, never a
  # silent empty; rc==0 "[]" is a genuine "no TB key for this model".
  if ! printf '%s\n' "${QPS_COMPACT}" | grep -qE '^[0-9]+ '; then
    local QPS_J qqrc
    QPS_J=$(timeout 40 meta scuba.dataset query -d mvai_metrics -a avg -c metric_value \
      -w "[{\"column\":\"model_entity_id\",\"op\":\"eq\",\"values\":[\"${EID}\"]},{\"column\":\"metric_name\",\"op\":\"eq\",\"values\":[\"qps/global/window/train\"]}]" \
      --hours="${HOURS}" --time-bucket="1 hour" -o json 2>/dev/null); qqrc=$?
    if [ "${qqrc}" -ne 0 ]; then return 2; fi
    [ -z "${QPS_J}" ] && QPS_J="[]"
    QPS_FETCH_FALLBACK="${QPS_J}"
  fi
  return 0
}
