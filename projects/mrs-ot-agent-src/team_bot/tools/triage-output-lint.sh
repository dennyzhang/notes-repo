#!/usr/bin/env bash
# triage-output-lint.sh — deterministic pre-POST validator for OT triage verdicts.
#
# WHY THIS EXISTS (T274815014, operator gdoc AAAB889DKBQ 2026-06-07): the shift-doc
# forcing function (shift-doc-lint.sh) turned ~80 prose "pre-push lint" rules into ONE
# executable gate so bad shift-doc output literally cannot ship. This is the TRIAGE
# analog. The triage flow has the same failure mode prose rules can't fix under task
# focus: confidently-wrong verdicts that narrate instead of cite, assert unverified
# mechanisms, ship 404 alert links, or stop at the first pattern match. Wire this into
# ot-sev-monitor / ot-alert-monitor BEFORE a verdict posts: a non-zero exit MUST block
# the post. This is the DETERMINISTIC layer; the independent validator agent + codex
# cross-model pass is the ADVERSARIAL layer — two layers, same as diff review.
#
# USAGE:
#   triage-output-lint.sh <verdict-file>          # lint a drafted verdict file
#   printf '%s' "$verdict" | triage-output-lint.sh -   # lint from stdin
# EXIT: 0 = clean (safe to post); 1 = violations printed to stderr (DO NOT POST).
#
# Checks (mirror the task's (a)-(e)):
#   1 structure   — required sections present            (proxy for rigor / root-cause depth, (d))
#   2 header      — root-cause + class + explicit confidence
#   3 citation    — Evidence carries >=1 [VERIFIED: <source>]   (self-reporting, (a))
#   4 naked-number— each numeric Evidence bullet cites a source (self-reporting, (a))
#   5 mechanism   — a causal claim is [INFERRED] or backed       (confirm-before-assert, (b))
#   6 alert-404   — onedetection alert_id not purely-numeric      (no-404-URLs, P-004, (c))
#   7 bare-alert  — A<id> wrapped in a URL (alerts don't auto-linkify) ((c))
#   8 paste-url   — 'Machine fields' has a resolvable P<id> URL
set -uo pipefail

src="${1:--}"; [ "$src" = "-" ] && src=/dev/stdin
v="$(cat "$src")"
fail=0
report() { printf '  ✗ [%s] %s\n' "$1" "$2" >&2; fail=1; }

# Extract a "*Section*" body: from its label to the next *Header* / 📊 / Alert: / EOF.
sec() { printf '%s' "$v" | perl -0ne 'BEGIN{$l=shift @ARGV} print $1 if /[*_]\Q$l\E[^*_\n]*[*_]:?(.*?)(?=\n\s*[*_][A-Z]|\n📊|\nAlert:|$)/s' "$1"; }

# 1) STRUCTURE — the verdict must show its work (what / evidence / alternatives / next).
#    A missing "Ruled out" is the deterministic proxy for first-pattern-match triage (d).
for s in "What happened" "Evidence" "Ruled out" "Next action"; do
  printf '%s' "$v" | grep -qiE "[*_]${s}" || \
    report "missing-section" "no *${s}* section — a triage verdict must show what happened, evidence, what was ruled out, and next actions (rigor, not first-pattern-match)"
done

# 2) HEADER — structured, explicit confidence (the precondition the validator agent assesses, (e)).
hdr="$(printf '%s' "$v" | head -3)"
printf '%s' "$hdr" | grep -qiE 'root-?cause:'                 || report "header" "verdict header missing 'root-cause:' field"
printf '%s' "$hdr" | grep -qiE 'class:'                        || report "header" "verdict header missing 'class:' field"
printf '%s' "$hdr" | grep -qiE 'confidence:[[:space:]]*(high|medium|low)' || report "header" "verdict header missing explicit 'confidence: high|medium|low'"

# 3) SELF-REPORTING (a) — Evidence must cite the system of record at least once.
ev="$(sec Evidence)"
printf '%s' "$ev" | grep -qE '\[VERIFIED:' || \
  report "no-citation" "Evidence has no [VERIFIED: <meta CLI / Scuba>] citation — every claim about external state must cite the literal source, not narration"

# 4) NAKED QUANT CLAIM (a) — a number-bearing Evidence bullet must cite a source / URL / [INFERRED].
while IFS= read -r b; do
  [ -z "$b" ] && continue
  printf '%s' "$b" | grep -qE '[0-9]' || continue
  printf '%s' "$b" | grep -qE '\[VERIFIED:|\[INFERRED\]|https?://' && continue
  report "naked-number" "Evidence bullet states a number with no [VERIFIED:]/URL/[INFERRED]: $(printf '%s' "$b" | sed 's/^[[:space:]]*//' | cut -c1-70)…"
done < <(printf '%s' "$ev" | grep -E '^[[:space:]]*[•*-]')

# 5) CONFIRM-BEFORE-ASSERT (b) — a causal mechanism must be [INFERRED] or evidence/SEV-backed.
hyp="$(sec Hypothesis)"
if printf '%s' "$hyp" | grep -qiE '→|->| causes?| caused by|throttl|because| leads? to| triggers?| due to| drives?'; then
  printf '%s' "$hyp" | grep -qE '\[INFERRED\]|\[VERIFIED:|S[0-9]{6,}' || \
    report "unbacked-mechanism" "Hypothesis asserts a causal mechanism with no [INFERRED] label and no [VERIFIED:]/SEV backing — label it [INFERRED] or cite the source (confirm-before-assert)"
fi

# 6) ALERT URL RESOLVABLE (c, P-004) — a purely-numeric onedetection alert_id is a feed id and 404s.
if printf '%s' "$v" | grep -qE 'onedetection/alert\?alert_id=[0-9]+([&"<[:space:]]|$)'; then
  report "alert-url-404" "onedetection link uses a purely-numeric alert_id (feed id) — it renders 'invalid'/404; use the resolvable detector expression (alert_created_time + %40%23%24 composite) or the short_id from 'meta monitoring.alert metadata' (P-004)"
fi

# 7) BARE ALERT ID (c) — A<id> must sit inside a URL; alerts don't auto-linkify in gchat
#    (S/D/T do, so they're allowed bare). Operator AAAB889DKGo: alerts/SEVs/posts need a url.
no_url="$(printf '%s' "$v" | perl -0pe 's/https?:\/\/\S+//g')"
while IFS= read -r id; do
  [ -n "$id" ] && report "bare-alert-id" "alert id '$id' has no URL — alerts don't auto-linkify; attach the resolvable onedetection link"
done < <(printf '%s' "$no_url" | grep -oE '\bA[0-9]{10,}\b' | sort -u)

# 8) MACHINE-FIELDS PASTE — if present, it must carry a real resolvable paste URL (not a bare P<id>).
if printf '%s' "$v" | grep -qiE 'Machine fields'; then
  printf '%s' "$v" | grep -qE 'intern/paste/P[0-9]+' || \
    report "paste-url" "'Machine fields' line present but no resolvable intern/paste/P<id> URL"
fi

# 9) ROOT-DEEP-FIX ON TRANSIENT (Denny 2026-06-08, thread Qk2y0-uGTf0) — mechanical enforcement
#    of ot-alert-monitor L80 ("WARNING = investigate DEEP, never fast-drop as TRANSIENT_NOISE").
#    A TRANSIENT_NOISE / NO_ACTION-auto-resolved verdict on a WARNING-class / staleness / recurring
#    signal MUST still carry a ROOT DEEP FIX in *Next actions* — "self-heals / monitor / auto-resolve"
#    is NOT terminal (logs purge fast; the recurrence repeats). L80 was prose and got skipped on
#    model 2133008573 (post-restart FULL_SNAPSHOT stall, ≥2nd occurrence). This is the gate.
if printf '%s' "$v" | head -3 | grep -qiE 'TRANSIENT_NOISE|NO[ _]ACTION'; then
  if printf '%s' "$v" | grep -qiE 'WARNING|FULL_SNAPSHOT|stale|publishing.?stab|RECURRING|recurr|bootstrap|post-?restart'; then
    nexts="$(sec 'Next action')"
    printf '%s' "$nexts" | grep -qiE 'leading.?indicator|prevent|recurrenc|durable|root.?fix|resume.*checkpoint|config diff|detector|escalat|T[0-9]{6,}' || \
      report "no-root-deep-fix" "TRANSIENT/NO_ACTION verdict on a WARNING/staleness/recurring signal but *Next actions* has NO root deep fix (durable prevention / leading-indicator / config diff / root-fix task / escalation). 'Self-heals/monitor/auto-resolve' is not terminal — propose the fix that prevents recurrence (or escalate). Enforces ot-alert-monitor L80."
  fi
fi

# 10) PAGE MUST BE EARNED (Denny 2026-06-08, S673338 false-page; [[anti-laziness-proof-of-work]]).
#     A PAGE verdict with confidence:low AND (root-cause not found / BOT INCOMPLETE / investigation
#     not started) is a false-page — block it. S673338: 🔴 PAGE rvishna · root-cause: not found ·
#     confidence: low · "BOT INCOMPLETE" — on an out-of-scope, already-Closed SEV. A PAGE must be
#     earned (root cause found OR a complete investigation), not "low confidence + unknown + incomplete."
if printf '%s' "$v" | head -3 | grep -qiE '(^|[[:space:]·])PAGE([[:space:]·]|$)|🔴[[:space:]]*PAGE'; then
  if printf '%s' "$v" | head -3 | grep -qiE 'confidence:[[:space:]]*low'; then
    if printf '%s' "$v" | grep -qiE 'root-?cause:[[:space:]]*(not found|not_found|unknown)|BOT INCOMPLETE|cannot investigate|investigation not started'; then
      report "unearned-page" "PAGE verdict with confidence:low AND (root-cause not found / BOT INCOMPLETE / investigation not started) — a PAGE must be EARNED (root cause found OR a complete investigation). Downgrade to MONITOR or escalate-with-diagnosis to the 1:1; do NOT page a human on a low-confidence, incomplete triage."
    fi
  fi
fi

if [ "$fail" -ne 0 ]; then
  printf '\ntriage-output-lint: violations above — DO NOT POST this verdict. Fix the citations/links or downgrade the claim, then re-lint.\n' >&2
  exit 1
fi
exit 0
