#!/usr/bin/env bash
# kb-staleness-audit.sh — the durable-KB decay check (P-rows / R-rules have no TTL, unlike
# known-issues). Flags rules NOT confirmed by any recent incident so stale knowledge gets reviewed
# before it misleads. ADVISORY ONLY — never auto-deletes (dropping a rule is high-risk; humans decide).
#
# "Confirmed recently" = the rule id appears in, within STALE_DAYS:
#   (1) triage_events (a live triage referenced it), (2) gold-set ground_truth.p_row,
#   (3) a resolved-incident archive file (by the file's date).
# A rule with no hit in STALE_DAYS (or never) -> review candidate (may be genuinely stale, or just
# new — the report shows last-seen so the operator can tell).
#
# Usage: kb-staleness-audit.sh [stale_days]   (default 120)
set -uo pipefail
export KSA_DAYS="${1:-120}"
export KSA_CTX="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context"
export KSA_KP="$KSA_CTX/human-input/knowledge/known-patterns.md"
export KSA_TD="$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-src/human-input/triage-discipline.md"
export KSA_DB="$HOME/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db"
export KSA_OUT="$KSA_CTX/eval/reports/kb-staleness.md"

python3 - <<'PY'
import os, re, json, glob, sqlite3, datetime
days=int(os.environ["KSA_DAYS"]); ctx=os.environ["KSA_CTX"]; out=os.environ["KSA_OUT"]
today=datetime.date.today(); cutoff=(today-datetime.timedelta(days=days)).isoformat()

def ids(path, pat):
    try: t=open(path).read()
    except FileNotFoundError: return []
    return sorted(set(re.findall(pat, t)), key=lambda s:(len(s),s))
prows=ids(os.environ["KSA_KP"], r'\bP\d{1,3}\b')
rrules=ids(os.environ["KSA_TD"], r'\bR\d{1,3}\b')

# last-seen per id across the three sources
last={}
def bump(i,d):
    if d and (i not in last or d>last[i]): last[i]=d

# (3) archives — one pass; file date from filename (YYYY-MM-DD) else skip
for f in glob.glob(f"{ctx}/incidents/**/*.md", recursive=True):
    m=re.search(r'(\d{4}-\d{2}-\d{2})', os.path.basename(f))
    if not m: continue
    d=m.group(1)
    try: txt=open(f).read()
    except Exception: continue
    for i in set(re.findall(r'\bP\d{1,3}\b|\bR\d{1,3}\b', txt)):
        bump(i,d)
# (2) gold set
try:
    g=json.load(open(f"{ctx}/eval/gold-set.json"))
    for c in g.get("cases",[]):
        pr=(c.get("ground_truth") or {}).get("p_row") or ""
        for i in re.findall(r'\bP\d{1,3}\b', pr): bump(i, c.get("added","2026-06-11"))
except Exception: pass
# (1) triage_events
try:
    con=sqlite3.connect(os.environ["KSA_DB"])
    for sig,nt,ts in con.execute("SELECT COALESCE(signal,''),COALESCE(notification_text,''),substr(ts_notified,1,10) FROM triage_events"):
        for i in set(re.findall(r'\bP\d{1,3}\b|\bR\d{1,3}\b', sig+' '+nt)): bump(i, ts)
except Exception: pass

def classify(i):
    d=last.get(i)
    if not d: return ("never", "—")
    return (("fresh" if d>=cutoff else "STALE"), d)

def section(title, items):
    L=[f"### {title} ({len(items)})", "", "| id | last confirmed | status |","|---|---|---|"]
    stale=0
    for i in items:
        s,d=classify(i)
        if s!="fresh": stale+=1
        L.append(f"| {i} | {d} | {'✅ fresh' if s=='fresh' else ('⚠️ STALE >'+str(days)+'d' if s=='STALE' else '❓ never seen')} |")
    return L, stale

Lp,sp=section("P-rows (known-patterns.md)", prows)
Lr,sr=section("R-rules (triage-discipline.md)", rrules)
hdr=[f"# KB staleness audit ({today})",
     "",
     f"_Durable-KB decay check. A rule with no confirming incident in **{days}d** is a REVIEW candidate "
     "(may be stale, or just new — check last-confirmed). Advisory only; never auto-deleted. "
     "Confirmed = appears in triage_events / gold-set / a dated incident archive._",
     "",
     f"**{sp}/{len(prows)} P-rows** and **{sr}/{len(rrules)} R-rules** are stale/never-confirmed → review.",
     ""]
open(out,"w").write("\n".join(hdr+Lp+[""]+Lr)+"\n")
print(f"KB staleness: P-rows {sp}/{len(prows)} stale, R-rules {sr}/{len(rrules)} stale (>{days}d). wrote {out}")
PY
