# shellcheck shell=bash
# lib-url.sh — shared URL-construction + validation helper for the OT agent.
#
# THE PRINCIPLE (learned 2026-06-06, the hard way): do NOT validate URLs by
# content-scanning an outgoing message — that false-positives on a message that
# merely *discusses* a URL (a send-hook attempt blocked its own explanation).
# Validate at CONSTRUCTION: build the URL from the structured id, where it is
# unambiguously a link and the id-type is known. Every emitter sources this file
# and builds links through these functions, so every link is resolvable
# CORRECT-BY-CONSTRUCTION.
#
# Single source of truth for every internalfb.com link the OT scan/render scripts
# emit. Used by: scan-zombie-fleet.sh, scan-scribe-age.sh, scan-perf-regression.sh,
# scan-weekly-failures.sh, render-fleet-digest.py (via the mast_url field the scans
# now emit). Cron prompts render the emitted URL fields verbatim.
#
# Source this file, then call one of the id-typed builders below. Each echoes the
# RESOLVABLE url form; display text is the operator's preferred short id (bare
# numeric eid for MAST, S###/D###/T### kept as the caller renders them).
#
#   mast_url <eid_or_jobname>   → mlhub MAST runs URL (prepends mvai-training-online-)
#   sev_url  <S###|numeric>     → sevmanager view URL
#   diff_url <D###|numeric>     → /D<numeric>
#   task_url <T###|numeric>     → /T<numeric>
#   alert_url <short_id>        → onedetection short_id passthrough (rejects bare numeric)
#   assert_resolvable <url>     → rc 0 if format-resolvable, nonzero otherwise (NO http)
#
# Self-test:  bash tools/lib-url.sh --self-test

_LIB_URL_BASE="https://www.internalfb.com"
_LIB_URL_MAST_PREFIX="mvai-training-online-"

# mast_url <eid_or_jobname>
#   bare entity id (digits)        → prepend mvai-training-online-
#   full mvai-training-online-*    → use as-is (already a job_name)
# Echoes the resolvable mlhub MAST runs URL. Display text (the bare eid) is the
# caller's job — this returns only the href.
mast_url() {
  local arg="$1" job
  [ -z "${arg}" ] && return 1
  case "${arg}" in
    ${_LIB_URL_MAST_PREFIX}*) job="${arg}" ;;           # already a job_name
    *[!0-9]*) job="${arg}" ;;                            # has non-digits: treat as job_name verbatim
    *) job="${_LIB_URL_MAST_PREFIX}${arg}" ;;           # bare numeric eid → prepend
  esac
  printf '%s/mlhub/pipelines/runs/mast/%s' "${_LIB_URL_BASE}" "${job}"
}

# sev_url <S###|numeric>  → strip leading S, build sevmanager view URL.
sev_url() {
  local n="${1#[Ss]}"
  [ -z "${n}" ] && return 1
  case "${n}" in *[!0-9]*) return 1 ;; esac
  printf '%s/sevmanager/view/%s' "${_LIB_URL_BASE}" "${n}"
}

# diff_url <D###|numeric>  → /D<numeric>.
diff_url() {
  local n="${1#[Dd]}"
  [ -z "${n}" ] && return 1
  case "${n}" in *[!0-9]*) return 1 ;; esac
  printf '%s/D%s' "${_LIB_URL_BASE}" "${n}"
}

# task_url <T###|numeric>  → /T<numeric>.
task_url() {
  local n="${1#[Tt]}"
  [ -z "${n}" ] && return 1
  case "${n}" in *[!0-9]*) return 1 ;; esac
  printf '%s/T%s' "${_LIB_URL_BASE}" "${n}"
}

# alert_url <short_id>
#   The resolvable onedetection short_id (the `url`/`short_id` from
#   `meta monitoring.alert metadata`) is passed through unchanged — it is already
#   a resolvable link (carries the @#$/alert_created_time composite). A BARE
#   numeric alert_id does NOT resolve (the ?alert_id=<numeric> form 404s for
#   AGG/SUM detectors), so it is REJECTED: empty output + nonzero rc. Callers must
#   resolve the short_id first and pass that.
alert_url() {
  local arg="$1"
  [ -z "${arg}" ] && return 1
  # If a full resolvable URL was passed, accept it as-is.
  case "${arg}" in
    http*onedetection*|http*alert*) printf '%s' "${arg}"; return 0 ;;
  esac
  # A bare-numeric alert_id has no composite → does not resolve → reject.
  case "${arg}" in
    *[!0-9]*) : ;;                                       # has non-digits: assume a short_id composite
    *) return 1 ;;                                       # all digits = bare alert_id → reject
  esac
  # A short_id composite (carries @ # $ or alert_created_time) → resolvable.
  case "${arg}" in
    *@*|*\#*|*\$*|*alert_created_time*)
      case "${arg}" in
        http*) printf '%s' "${arg}" ;;
        *)     printf '%s/monitoring/alerts/?alert_instance=%s' "${_LIB_URL_BASE}" "${arg}" ;;
      esac
      return 0 ;;
  esac
  # Non-numeric but no composite marker → not demonstrably resolvable → reject.
  return 1
}

# assert_resolvable <url>  → rc 0 if format-resolvable, nonzero otherwise.
# FORMAT CHECK ONLY — no http reachability (too slow for the cron path).
# Rejects: empty, unfilled placeholder ({{...}}, <...>, NNN, %s), a bare-numeric
# onedetection alert (?alert_id=<digits> with no composite), and obvious malforms.
assert_resolvable() {
  local url="$1"
  [ -z "${url}" ] && return 1
  case "${url}" in
    http://*|https://*) : ;;
    *) return 1 ;;                                       # not a URL
  esac
  # Unfilled placeholders.
  case "${url}" in
    *'{{'*|*'}}'*|*'<'*'>'*|*NNN*|*'%s'*|*'${'*) return 1 ;;
  esac
  # Bare-numeric onedetection alert: ?alert_id=<digits> with NO composite → 404s.
  case "${url}" in
    *onedetection*|*'/alerts/'*|*alert_id=*)
      case "${url}" in
        *@*|*'%40'*|*alert_created_time*|*alert_instance=*) : ;;   # has composite → ok
        *alert_id=*[0-9]) return 1 ;;                              # bare numeric → reject
        *alert_id=*) return 1 ;;
      esac ;;
  esac
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Self-test:  bash tools/lib-url.sh --self-test
# ─────────────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--self-test" ]; then
  _fail=0
  _ck() { # _ck <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then printf 'ok   %s\n' "$1"
    else printf 'FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"; _fail=1; fi
  }
  _ck_rc() { # _ck_rc <desc> <expected_rc> <actual_rc>
    if [ "$2" = "$3" ]; then printf 'ok   %s (rc=%s)\n' "$1" "$3"
    else printf 'FAIL %s (expected rc=%s, got rc=%s)\n' "$1" "$2" "$3"; _fail=1; fi
  }

  B="https://www.internalfb.com"

  # mast_url: bare eid → prepended job_name URL.
  _ck "mast_url bare eid prepends prefix" \
    "${B}/mlhub/pipelines/runs/mast/mvai-training-online-2124428748" \
    "$(mast_url 2124428748)"
  # mast_url: full job_name → used as-is.
  _ck "mast_url full job_name as-is" \
    "${B}/mlhub/pipelines/runs/mast/mvai-training-online-2124428748" \
    "$(mast_url mvai-training-online-2124428748)"
  # mast_url: job_name with suffix → used as-is.
  _ck "mast_url job_name with suffix as-is" \
    "${B}/mlhub/pipelines/runs/mast/mvai-training-online-123_v2" \
    "$(mast_url mvai-training-online-123_v2)"

  _ck "sev_url strips S"     "${B}/sevmanager/view/665454" "$(sev_url S665454)"
  _ck "sev_url bare numeric" "${B}/sevmanager/view/665454" "$(sev_url 665454)"
  _ck "diff_url strips D"    "${B}/D98638473"              "$(diff_url D98638473)"
  _ck "task_url strips T"    "${B}/T12345"                 "$(task_url T12345)"

  # alert_url: bare-numeric alert_id → REJECT (empty + nonzero rc).
  out=$(alert_url 123456789); rc=$?
  _ck    "alert_url bare numeric → empty output" "" "${out}"
  _ck_rc "alert_url bare numeric → nonzero rc"   1 "${rc}"
  # alert_url: short_id composite → passthrough/resolvable.
  out=$(alert_url 'detector@#$1700000000'); rc=$?
  _ck_rc "alert_url short_id composite → rc 0" 0 "${rc}"
  [ -n "${out}" ] && printf 'ok   alert_url short_id non-empty: %s\n' "${out}" || { printf 'FAIL alert_url short_id empty\n'; _fail=1; }

  # assert_resolvable
  _ck_rc "assert_resolvable mast url ok" 0 "$(assert_resolvable "$(mast_url 2124428748)"; echo $?)" 2>/dev/null
  assert_resolvable "${B}/mlhub/pipelines/runs/mast/mvai-training-online-2124428748"; _ck_rc "assert good mast" 0 $?
  assert_resolvable "${B}/sevmanager/view/665454"; _ck_rc "assert good sev" 0 $?
  assert_resolvable "${B}/monitoring/alerts/?alert_id=123456789"; _ck_rc "assert bare-numeric alert rejected" 1 $?
  assert_resolvable "${B}/mlhub/pipelines/runs/mast/mvai-training-online-{{EID}}"; _ck_rc "assert placeholder rejected" 1 $?
  assert_resolvable "${B}/mlhub/pipelines/runs/mast/mvai-training-online-%s"; _ck_rc "assert printf-leftover rejected" 1 $?
  assert_resolvable ""; _ck_rc "assert empty rejected" 1 $?
  assert_resolvable "not-a-url"; _ck_rc "assert non-url rejected" 1 $?

  echo "────────────────────────────────────────"
  if [ "${_fail}" = "0" ]; then echo "lib-url.sh self-test: ALL PASS"; exit 0
  else echo "lib-url.sh self-test: FAILURES ABOVE"; exit 1; fi
fi
