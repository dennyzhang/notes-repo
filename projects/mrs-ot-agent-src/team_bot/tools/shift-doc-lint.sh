#!/usr/bin/env bash
# shift-doc-lint.sh — deterministic pre-publish validator for the OT oncall shift gdoc.
#
# WHY THIS EXISTS (2026-06-06 retro): the shift-summary cron prompt accumulated 80+ rules,
# many of them "pre-push lint: grep X → ABORT" that the LLM is supposed to run by hand at
# render time. Across one day the operator re-flagged the SAME classes (bare/broken IDs,
# subjectless grammar, by-design noise in the paged section, no-value non-statements,
# stale SLICK) because prose lints get skipped under task focus — ESPECIALLY on interactive
# mid-shift hand-inserts that bypass the cron path entirely. This script turns those prose
# lints into ONE executable gate that runs identically on every write path (cron Tuesday
# render, WED–MON mid-shift refresh, AND interactive comment-driven edits). It is the
# structural fix the prose rules could not be.
#
# USAGE:
#   shift-doc-lint.sh <rendered-ghtml-file>           # lint a draft file before push
#   gdocs get <DOC> --tab-id <TAB> | shift-doc-lint.sh -   # lint a live tab via stdin (ghtml checks only)
#   shift-doc-lint.sh --doc <DOC> --tab <TAB>         # fetch live tab + run ALL ghtml checks AND the
#                                                       docs-API font-audit (check #12) — the COMPLETE gate
#
# EXIT: 0 = clean; 1 = violations found (printed to stderr). Wire as a hard gate: a non-zero
# exit must BLOCK the push (cron) or the "done" claim (interactive). Prefer --doc/--tab so the
# font/namedStyle regression (NOT visible in ghtml) is caught by the same gate (RULE 88/89).
#
# Encodes (executable form of) RULES 35/61-bis/64/73/74/75 + the 2026-06-06/07 additions.
set -uo pipefail

DOC=""; TAB=""
if [ "${1:-}" = "--doc" ]; then
  DOC="${2:-}"; [ "${3:-}" = "--tab" ] && TAB="${4:-}"
  raw="$(GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=true timeout 120 gdocs get "$DOC" --tab-id "$TAB" </dev/null 2>/dev/null)"
else
  src="${1:-/dev/stdin}"
  raw="$(cat "$src")"
fi
# Strip <aside>…</aside> (Google-Docs COMMENT blocks: their quoted-text + reply history carry
# hundreds of bare IDs that are comment metadata, NOT body content) and <head>…</head> before
# linting. We validate the rendered BODY the reader sees, not the comment threads.
html="$(printf '%s' "$raw" | perl -0pe 's/<aside\b[^>]*>.*?<\/aside>//gs; s/<head\b[^>]*>.*?<\/head>//gs')"
# Also drop the operator-owned "Local notes (Bot — don't touch it)" section (heading → next <h3>
# or EOF): it is manual input the bot is read-only on (RULE 72/80), so its bare IDs are not the
# bot's to fix. The bot consolidates ITS signal into the structured sections (RULE 80) where the
# linkified copy IS linted; the manual block itself is out of scope for this validator.
html="$(printf '%s' "$html" | perl -0pe 's/<h3\b[^>]*>[^<]*Local notes \(Bot.*$//s')"
fail=0
report() { printf '  ✗ [%s] %s\n' "$1" "$2" >&2; fail=1; }

# RELIABILITY (2026-06-07 red-team) — FAIL LOUD on an empty/failed fetch. A gate that silently
# PASSES a doc it never actually read is worse than no gate: the caller pushes believing it was
# audited. gdocs get / google-mux can return nothing on auth expiry, wrong --doc/--tab, or
# rate-limit (we 2>/dev/null them), which would otherwise leave every grep matching nothing →
# exit 0. Require non-empty input, and in live --doc mode require the shift-doc title anchor so a
# wrong-tab or partial fetch can't masquerade as a clean run.
if [ -z "${raw//[[:space:]]/}" ]; then
  report "fetch-empty" "input/fetch returned EMPTY — nothing was validated (gdocs get failed? wrong --doc/--tab? auth/rate-limit?). This is NOT a pass."
elif [ -n "$DOC" ] && ! printf '%s' "$raw" | grep -q 'Oncall Summary for mrs_online_training'; then
  report "fetch-suspect" "fetched tab lacks the shift-doc title anchor ('Oncall Summary for mrs_online_training') — wrong tab or partial fetch; NOT a pass."
fi

# Strip <a ...>...</a> link spans so we can detect IDs that are NOT inside a link.
# (Linkified IDs are fine; bare ones are the violation.)
no_links="$(printf '%s' "$html" | perl -0pe 's/<a\b[^>]*>.*?<\/a>//gs')"

# 1) Bare identifiers — every S/D/T (>=6 digits), A and W (>=10 digits) must be inside <a href>.
#    (RULE 64) Bare IDs outside links recurred on diffs (AAAB85kcND0) and across SEV/post/alert.
#    W (Workplace posts) added 2026-06-07 (operator AAAB889DKGo: "alerts, SEVs, and posts should have url attached").
while IFS= read -r id; do
  [ -n "$id" ] && report "bare-id" "identifier '$id' is not inside an <a href> link (RULE 64; SEVs/posts/alerts all need a url)"
done < <(printf '%s' "$no_links" | grep -oE '\b[SDT][0-9]{6,}\b|\b[AW][0-9]{10,}\b' | sort -u)

# 2) Diff URL must carry the D prefix (RULE 35): /diff/<digits> (no D) 404s.
if printf '%s' "$html" | grep -qE 'diff/[0-9]'; then
  report "diff-url" "found /diff/<number> without the D prefix — 404s (RULE 35)"
fi

# 3) Alert URL must be the resolvable detector expression, not a bare numeric feed id (RULE 74c).
if printf '%s' "$html" | grep -qE 'onedetection/alert\?alert_id=[0-9]+(&|"|<|$)'; then
  report "alert-url" "onedetection alert link uses a purely-numeric alert_id (feed id) — 404s; use the short_id from 'meta oncall.feed metadata' (RULE 74c)"
fi

# 4) Subjectless grammar (RULE 75b): 'These page ...' must be 'These alerts page ...'.
if printf '%s' "$html" | grep -qE 'These page '; then
  report "grammar" "subjectless 'These page ...' — must be 'These alerts page ...' (RULE 75b)"
fi

# 5) No-value non-statement (RULE 74b): a 'No confirmed robocalls' bullet is padding.
if printf '%s' "$html" | grep -qiE 'No confirmed robocalls'; then
  report "non-statement" "'No confirmed robocalls' non-statement — collapse to one line or lead with page-eligible majors (RULE 74b)"
fi

# 6) By-design noise in the paged section (RULE 74a): [Invalid Detector]/[No Data]/[Preemptive]
#    must not appear under the 'SEVs and Alerts Oncall Got Paged' heading.
paged_section="$(printf '%s' "$html" | perl -0ne 'print $1 if /Oncall Got Paged<\/h3>(.*?)<h3/s')"
if printf '%s' "$paged_section" | grep -qiE '\[Invalid Detector\]|\[No Data\]|\[Preemptive\]'; then
  report "paged-noise" "by-design alert ([Invalid Detector]/[No Data]/[Preemptive]) in the paged section — route out or omit (RULE 74a)"
fi

# 7) Required-human-input loudness (RULE 61-bis): every 'TODO (oncall)' must carry the marker.
while IFS= read -r line; do
  [ -z "$line" ] && continue
  printf '%s' "$line" | grep -q 'REQUIRED — oncall fill' || \
    report "bare-todo" "TODO (oncall) without the bold-red '⚠️ REQUIRED — oncall fill:' marker (RULE 61-bis)"
done < <(printf '%s' "$html" | grep -oE '<li>[^<]*TODO \(oncall\)[^<]*' )

# 8) Whole-sentence / wall-of-bold inside a bullet (RULE 82) — bold is for short labels/key terms,
#    NOT full sentences (operator 2026-06-06: "the one sentence is in bold. this hurts readability").
#    Recurs because find-replace/insertText inherit the bold of the preceding label and the un-bold
#    step gets skipped. Flag a <b> span inside an <li> that is a sentence (contains '. ' or ends '.')
#    or a wall (>110 chars). Short label phrases (no period, <=110 chars) are fine.
while IFS= read -r b; do
  [ -z "$b" ] && continue
  inner="$(printf '%s' "$b" | perl -pe 's/<[^>]+>//g')"
  len=${#inner}
  if printf '%s' "$inner" | grep -qE '\. ' || { printf '%s' "$inner" | grep -qE '\.$' && [ "$len" -gt 40 ]; } || [ "$len" -gt 110 ]; then
    report "bold-sentence" "whole-sentence/wall bold in a bullet (bold only short labels): $(printf '%s' "$inner" | cut -c1-70)…"
  fi
done < <(printf '%s' "$html" | perl -0ne 'while(/<li>(.*?)<\/li>/gs){my $li=$1; while($li=~/<b>(.*?)<\/b>/gs){print "$1\n"}}')

# 9) Over-broad hyperlink (RULE 84) — a link must wrap the CRITICAL TOKEN only (an id / short label),
#    NEVER a whole sentence (operator 2026-06-06: "is not usable for the whole sentence attached to a
#    link. it should be the most critical ones only"). Same inherit-trap as bold: find-replace/insert
#    after a linked run makes the new text inherit the link. Flag <a> whose visible text is a sentence
#    (contains '. ') or is long (>45 chars). Legit id/label links (S/D/T/A###, group names) are short.
while IFS= read -r atxt; do
  [ -z "$atxt" ] && continue
  if printf '%s' "$atxt" | grep -qE '\. ' || [ "${#atxt}" -gt 45 ]; then
    report "broad-link" "hyperlink wraps a whole sentence/long span (link the critical token only): $(printf '%s' "$atxt" | cut -c1-60)…"
  fi
done < <(printf '%s' "$html" | perl -0ne 'while(/<a\b[^>]*>(.*?)<\/a>/gs){my $x=$1; $x=~s/<[^>]+>//g; print "$x\n"}')

# 10) Timeline day-heading rendered as a bullet (RULE 86) — a new day MUST be an <h4> heading, never an
#     <li>. The mid-shift incremental cron appended 6/6 & 6/7 as flat bullets under 6/5 (operator: "don't
#     you see problems with the format?"). Flag any <li> whose text starts like a date "M/D (Weekday)".
while IFS= read -r li; do
  [ -z "$li" ] && continue
  report "day-as-bullet" "timeline day rendered as a bullet, must be an <h4> heading: $(printf '%s' "$li" | cut -c1-40)"
done < <(printf '%s' "$html" | perl -0ne 'while(/<li>(.*?)<\/li>/gs){my $x=$1;$x=~s/<[^>]+>//g; print "$x\n" if $x=~/^\s*\d{1,2}\/\d{1,2}\s*\((Mon|Tue|Wed|Thu|Fri|Sat|Sun)/i}')

# 11) Shift-character summary must be CONSISTENT with the Overview counts (RULE 87) — operator
#     ("what mechanism would make the summary line consistent with the new changes?"). The opening
#     summary said "one HIGH-TOUCH" while Overview said "SEVs (HIGH-TOUCH): 3". Cross-check the two.
# Opener-agnostic (RULE 87): match the summary's "N HIGH-TOUCH" prose regardless of the
# opener phrase ("Steady-grind shift" / "Active shift" / etc). The number-BEFORE-HIGH-TOUCH
# form is the summary prose; the Overview uses "(HIGH-TOUCH): N" (number after), so this
# won't cross-match it. Hardcoding the opener (was "Steady-grind shift") silently no-op'd
# the whole check for any other opener.
sum_ht="$(printf '%s' "$html" | perl -0ne 'print "$1" if /\b(\d+|one|two|three)\s+HIGH-TOUCH/s' | head -1)"
case "$sum_ht" in one) sum_ht=1;; two) sum_ht=2;; three) sum_ht=3;; esac
ov_ht="$(printf '%s' "$html" | perl -0ne 'print "$1" if /SEVs \(HIGH-TOUCH\)\s*:?\s*<\/b>?\s*(\d+)/s' | head -1)"
[ -z "$ov_ht" ] && ov_ht="$(printf '%s' "$html" | perl -0ne 'print "$1" if /HIGH-TOUCH\)\D*(\d+)\s*\xe2\x80\x94/s' | head -1)"
if [ -n "$sum_ht" ] && [ -n "$ov_ht" ] && [ "$sum_ht" != "$ov_ht" ]; then
  report "summary-inconsistent" "shift-character says ${sum_ht} HIGH-TOUCH but Overview says ${ov_ht} — regenerate the summary from current counts (RULE 87)"
fi

# 13) FALSE BOT-ACTION on a read-only surface (RULE 90) — the bot is READ-ONLY on alerts/SEVs/WP
#     (CLAUDE.md), so it can NEVER resolve/fix/mitigate them. Flag "bot-resolved/-fixed/-mitigated/
#     -cleared" claims (operator AAAB889DKB8: "Is the 'bot-resolved' accurate?" — those alerts
#     auto-cleared; the bot only observed). Use "auto-cleared / self-resolved / bot-observed" instead.
if printf '%s' "$html" | grep -qiE 'bot-?(resolved|fixed|mitigated|cleared)'; then
  report "false-bot-action" "claims bot resolved/fixed/mitigated an alert/SEV — bot is READ-ONLY there; use 'auto-cleared / self-resolved / bot-observed' (RULE 90)"
fi

# 12) FONT-AUDIT (RULE 88) — list items must be NORMAL_TEXT, not HEADING_* (insert-html inheritance
#     bug renders <li> oversized; INVISIBLE in ghtml so it needs the docs API). Only runs in --doc mode.
if [ -n "$DOC" ] && [ -n "$TAB" ]; then
  # PERF (2026-06-07, operator "the OT shift update flow become heavy now"): checks #12 (namedStyle font-audit)
  # and #14 (mostly-bold bullet) used to fetch the SAME doc twice. Consolidated into ONE docs-API call that
  # pulls both fields; one python pass emits "nbad bbad". Saves a full-doc API round-trip per gate (~2s).
  read -r nbad bbad < <(GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=true timeout 90 google-mux api call GET "https://docs.googleapis.com/v1/documents/${DOC}?includeTabsContent=true&fields=tabs(tabProperties(tabId),documentTab(body(content(paragraph(elements(textRun(content,textStyle(bold))),bullet,paragraphStyle(namedStyleType))))))" </dev/null 2>/dev/null | T="$TAB" python3 -c "
import json,sys,os
tabid=os.environ['T']
try: d=json.load(sys.stdin)
except Exception: print('-1 -1'); sys.exit()
nbad=bbad=tot=0
for t in d.get('tabs',[]):
  if t.get('tabProperties',{}).get('tabId')!=tabid: continue
  for c in t.get('documentTab',{}).get('body',{}).get('content',[]):
    p=c.get('paragraph')
    if not (p and p.get('bullet')): continue
    tot+=1
    if p.get('paragraphStyle',{}).get('namedStyleType','NORMAL_TEXT')!='NORMAL_TEXT': nbad+=1   # check #12 (font/heading)
    boldchars=sum(len(e['textRun']['content']) for e in p.get('elements',[]) if e.get('textRun') and e['textRun'].get('textStyle',{}).get('bold'))
    if boldchars>60: bbad+=1   # check #14 (bold wall)
# 0 bullets = the fetch found no content (wrong tab / malformed fields= / empty 200). A real shift tab
# always has many bullets → treat as fetch-failure so a silent empty response cannot pass the audit.
if tot==0: print('-1 -1'); sys.exit()
print(nbad,bbad)
")
  # 12) FONT-AUDIT (RULE 88): list items must be NORMAL_TEXT, not HEADING_* (insert-html inheritance bug,
  #     invisible in ghtml). 14) MOSTLY-BOLD BULLET (RULE 82): a fully-bold line fragmented by inline links
  #     evades the ghtml check #8 — run-level bold from the API is immune (operator AAAB889DKKY).
  # Empty `nbad` (python/google-mux missing → read got nothing) is also a fetch-failure, not a pass.
  if [ "${nbad:-x}" = "-1" ] || [ -z "${nbad:-}" ]; then report "font-audit" "could not fetch/parse docs API for font+bold audit (empty or 0-bullet response) — NOT a pass; checks #12/#14 did not run";
  else
    [ "${nbad:-0}" -gt 0 ] && report "font-audit" "${nbad} list item(s) styled as HEADING_* (oversized font) — fix to NORMAL_TEXT via updateParagraphStyle (RULE 88)"
    [ "${bbad:-0}" -gt 0 ] && report "bold-wall-api" "${bbad} bullet(s) are mostly-bold (>60 bold chars — a bold wall, not a label; links fragment ghtml so this needs the API). Un-bold the body, keep only the short label bold (RULE 82)"
  fi

  # 15) PAGE-COUNT ACCURACY (RULE 99, operator AAAB889DKLA "what mechanisms would ensure this counting
  #     accurate?"): the doc's "N escalated pages" must equal the --escalating ledger count for the shift
  #     window. --escalating = alerts SENT-TO/escalated-to the oncall (real pages), NOT the subscribed feed.
  #     Derives shift_start from the title date range "M/D – M/D"; skips (no false-fail) if it can't.
  doc_pages="$(printf '%s' "$html" | perl -0ne 'print "$1" if /Paged this shift:\s*(\d+)\s+escalated pages/')"
  shift_md="$(printf '%s' "$html" | perl -0ne 'print "$1" if /Oncall Summary for mrs_online_training:\s*(\d+\/\d+)/')"
  if [ -n "$doc_pages" ] && [ -n "$shift_md" ]; then
    ledger="$(GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=true timeout 100 meta oncall.notification list --oncall=mrs_online_training --escalating -l 500 -o json </dev/null 2>/dev/null | SMD="$shift_md" CY="$(date +%Y)" CM="$(date +%-m)" python3 -c "
import json,sys,os
md=os.environ['SMD']; mo,da=(int(x) for x in md.split('/'))
cy=int(os.environ['CY']); cm=int(os.environ['CM'])
# Title carries no year. Default to the current year; if the title month is ahead of the current
# month (Dec shift viewed in Jan) it belongs to the previous year. Avoids the hardcoded-2026 bug.
yr=cy-1 if mo>cm else cy
start='%04d-%02d-%02d'%(yr,mo,da)
try: d=json.load(sys.stdin)
except Exception: print(-1); sys.exit()
items=d if isinstance(d,list) else d.get('data',[])
print(sum(1 for it in items if it.get('created_at','')>=start))
")"
    if [ "${ledger:-0}" != "-1" ] && [ -n "$ledger" ] && [ "$doc_pages" != "$ledger" ]; then
      report "page-count" "doc says ${doc_pages} escalated pages but the --escalating ledger (since ${shift_md}) shows ${ledger} — re-derive from the ledger, not the feed (RULE 99/DKLA)"
    fi
  fi
fi

# 15b) PAGE-COUNT CONSISTENCY ACROSS THE DOC (operator AAAB889DKLA + DKMk: counting must be accurate
#      AND self-consistent). #15 checks the headline vs the ledger; this catches a SECOND mention that
#      contradicts the headline — e.g. headline "7 escalated pages" while the Page-reduction line still
#      says "Of the 89 alert pages" (the raw feed volume mislabeled as pages). Any "<n> ... pages"
#      whose number differs from the headline escalated count is flagged. Runs in every mode (html-only).
hl_pages="$(printf '%s' "$html" | perl -0ne 'print "$1" if /Paged this shift:\s*(\d+)\s+escalated pages/')"
if [ -n "$hl_pages" ]; then
  while IFS= read -r n; do
    [ -n "$n" ] && [ "$n" != "$hl_pages" ] && report "page-consistency" "a second page count '${n} … pages' disagrees with the headline '${hl_pages} escalated pages' — only ${hl_pages} escalated to a page; call other counts 'alert fires/feed volume', not 'pages' (DKLA/DKMk)"
  done < <(printf '%s' "$html" | grep -oiE '[0-9]+ (alert )?pages' | grep -oE '^[0-9]+' | sort -u)
fi

# 16) WP-REPORT COUNT ACCURACY (operator AAAB889DKMk "what mechanisms could make the counting accurate?").
#     The stated "WP user reports: N this shift" must equal the number of items actually enumerated on
#     that line (items are '; '-separated after the em-dash). Internal-consistency catch — the cheap,
#     deterministic mechanism: a stated count that doesn't match the listed items is the recurring bug.
# strip tags first — the real doc has "<b>WP user reports:</b> 2 this shift", so the count sits
# AFTER a closing tag; matching on tag-stripped text makes the check actually fire (not silently skip).
wp_flat="$(printf '%s' "$html" | perl -pe 's/<[^>]+>//g')"
wp_line="$(printf '%s' "$wp_flat" | perl -0ne 'print "$1\n" if /WP user reports:\s*(\d+\s+this shift.*?)(?:\n|$)/')"
wp_n="$(printf '%s' "$wp_line" | grep -oE '^[0-9]+')"
if [ -n "$wp_n" ] && printf '%s' "$wp_line" | grep -q '—'; then
  body="${wp_line#*—}"
  # count '; '-separated items in the enumerated tail (only if there is a real tail, not "0 this shift")
  if [ "$wp_n" -gt 0 ] && [ -n "${body// /}" ]; then
    listed="$(printf '%s' "$body" | grep -oE ';' | wc -l)"; listed=$((listed+1))
    [ "$listed" != "$wp_n" ] && report "wp-count" "WP user reports says '${wp_n}' but ${listed} item(s) are enumerated on the line — derive N from the actual this-shift WP list (meta workplace.post), not a carried-forward number (DKMk)"
  fi
fi

# 17) NEEDS-A-HUMAN ITEMS MUST CARRY A 'needs:' CLAUSE (operator AAAB889DKNQ "what part really needs
#     human?"). Any NEEDS-YOU / NEEDS ONCALL / '🚨 CRITICAL (active)' line must spell out the human-only
#     action (the bot is read-only on SEVs/pages) — flagged if it lacks a 'needs:' clause.
while IFS= read -r line; do
  [ -z "$line" ] && continue
  printf '%s' "$line" | grep -qiE 'needs:' || \
    report "needs-clause" "a NEEDS-YOU/CRITICAL-active item lacks a 'needs: <human-only action>' clause (file SEV / escalate shared-infra owner / page) — say what the human must do (RULE/DKNQ): $(printf '%s' "$line" | perl -pe 's/<[^>]+>//g' | cut -c1-70)…"
done < <(printf '%s' "$html" | grep -oiE '<li>[^<]*(NEEDS-YOU|NEEDS ONCALL|CRITICAL \(active\))[^<]*')

# 18) ALERT REFERENCES MUST CARRY A REAL ALERT LINK (operator AAAB889DKTU "what mechanisms can ensure
#     alert links won't be missing?"). The ENFORCEMENT half of the capture-at-source fix (ot-alert-monitor
#     persists each alert's .url at detection; shift render reads it, RULE 93 resolution order). Any
#     publishing-stability / FULL_SNAPSHOT / SPARSE_DELTA / DENSE_DELTA line that cites a model-id (>=9
#     digits) MUST contain an alert <a href> (onedetection / monitoring.alert) OR an explicit
#     "(alert cleared; url unavailable)" annotation. A bare alert line (no link, no note) FAILS — that is
#     the "missing alert link" the operator keeps catching. A SLICK group-dashboard fburl is NOT an alert
#     link (RULE 93) and is called out specifically. Runs in every mode (html-only).
while IFS= read -r li; do
  [ -z "$li" ] && continue
  printf '%s' "$li" | grep -qiE 'FULL_SNAPSHOT|SPARSE_DELTA|DENSE_DELTA|publishing.?stability' || continue
  printf '%s' "$li" | grep -qE '[0-9]{9,}' || continue
  printf '%s' "$li" | grep -qiE 'url unavailable|alert cleared|purged|unroutable' && continue
  if printf '%s' "$li" | grep -qiE '<a [^>]*href="[^"]*(onedetection|monitoring/alert)'; then continue; fi
  snippet="$(printf '%s' "$li" | perl -pe 's/<[^>]+>//g' | cut -c1-60)"
  if printf '%s' "$li" | grep -qiE 'fburl.com/monitoring'; then
    report "alert-link" "alert line links a SLICK group-dashboard, not the alert (RULE 93/DKTU) — use the captured onedetection .url, or leave bare with '(alert cleared; url unavailable)': ${snippet}…"
  else
    report "alert-link" "alert line cites a model-id but has NO alert link and no '(alert cleared; url unavailable)' note (DKTU — ensure alert links aren't silently missing): ${snippet}…"
  fi
done < <(printf '%s' "$html" | perl -0ne 'while(/<li>(.*?)<\/li>/gs){my $x=$1; $x=~s/\n/ /g; print "$x\n"}')

if [ "$fail" -eq 0 ]; then
  echo "shift-doc-lint: PASS — no deterministic violations" >&2
else
  echo "shift-doc-lint: FAIL — fix the above before push/declaring done" >&2
fi
exit "$fail"
