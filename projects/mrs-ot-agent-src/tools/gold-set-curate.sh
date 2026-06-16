#!/usr/bin/env bash
# gold-set-curate.sh — automated lifecycle management for the eval gold set.
#
# (.sh wrapper because the notes repo deny_files hook rejects .py; logic is the embedded python.)
#
# The gold set must EVOLVE (new confirmed incidents in; stale/leaky/dup out) or the agent ends up
# graded only on memorized history. This is the deterministic, SCORE-BLIND core of that lifecycle;
# the LLM cron `ot-eval-goldset-curator` does prose->structured extraction and calls `merge`.
# Anti-gaming invariant: NO mode reads eval scores or pass/fail — add/prune key only off data
# properties (eligibility, dup, orphaned source, date, strata).
#
# Modes:
#   report                    read-only status: in-set count, backlog, strata balance, safe-prune
#                             candidates (dup / orphaned-source). Default.
#   new-ids --limit N [--type sev,alert,post]
#                             emit up to N archive ids NOT in the set (recent-first) + paths, JSON.
#   merge <candidates.json>   append eligible cases (dedup by id, stamp added+source, MAX_CASES cap),
#                             bump version. Writes gold-set.json.
#   prune [--apply]           list ONLY safe removals (exact dup id; case whose source archive is
#                             gone). Never removes by difficulty/score. --apply to act.
#
# Usage: gold-set-curate.sh [mode] [flags]
set -uo pipefail
python3 - "$@" <<'PY'
import json, os, re, sys, glob, datetime, argparse

ROOT = os.path.expanduser("~/notes/users/dennyzhang/projects/mrs-ot-agent-context")
GOLD = f"{ROOT}/eval/gold-set.json"
ARCHIVE_DIRS = {"sev": "incidents/resolved-sevs", "alert": "incidents/resolved-alerts", "post": "incidents/resolved-posts"}
MAX_CASES = 180
ID_RE = re.compile(r"([SAW]\d{6,})")
TODAY = datetime.date.today().isoformat()

def load_gold():
    g = json.load(open(GOLD)); return g, {c["id"]: c for c in g.get("cases", [])}

def archive_index():
    idx = {}
    for typ, d in ARCHIVE_DIRS.items():
        for f in glob.glob(f"{ROOT}/{d}/**/*.md", recursive=True):
            base = os.path.basename(f)
            if base == "INDEX.md": continue
            m = ID_RE.search(base)
            if m: idx.setdefault(m.group(1), {"type": typ, "path": os.path.relpath(f, ROOT)})
    return idx

def strata(cases):
    s = {}
    for c in cases: s[c.get("type", "?")] = s.get(c.get("type", "?"), 0) + 1
    return s

def cmd_report(_):
    g, have = load_gold(); idx = archive_index()
    backlog = {i: v for i, v in idx.items() if i not in have}
    orphan = [i for i, c in have.items() if c.get("source") and not os.path.exists(f"{ROOT}/{c['source']}")]
    print(f"gold set: {len(have)} cases (version {g.get('version')})  cap {MAX_CASES}")
    print(f"  strata in-set : {strata(have.values())}")
    print(f"  backlog       : {len(backlog)} archive incidents not yet in set  {strata([{'type':v['type']} for v in backlog.values()])}")
    print(f"  room to cap   : {max(0, MAX_CASES - len(have))}")
    print(f"  orphaned src  : {len(orphan)} (case source gone -> safe-prune)  {orphan[:8]}")
    print(f"  date-stamped  : {sum(1 for c in have.values() if c.get('added'))}/{len(have)} (curator-added)")
    leaky = [i for i, c in have.items() if leaks_answer(c)]
    print(f"  LEAK-suspect  : {len(leaky)} (answer text in input — review; eval's generalization_composite already discounts these)  {leaky[:6]}")

def cmd_new_ids(a):
    g, have = load_gold(); idx = archive_index()
    want = [t.strip() for t in a.type.split(",")] if a.type else list(ARCHIVE_DIRS)
    cand = [{"id": i, "type": v["type"], "path": v["path"]} for i, v in idx.items() if i not in have and v["type"] in want]
    def datekey(c):
        m = re.search(r"(\d{4}-\d{2}-\d{2})", c["path"]); return m.group(1) if m else c["path"]
    cand.sort(key=datekey, reverse=True)
    print(json.dumps({"candidates": cand[: a.limit]}, indent=1))

def leaks_answer(c):
    # ANTI-GAMING / anti-poisoning: the eval is only valid if input.body is the FIRE-TIME symptom
    # with the answer hidden. If the LLM extractor leaked the root cause into the body, the case
    # rewards memorization, not triage. Reject any case where a 6-word shingle of ground_truth's
    # root_cause appears verbatim in input.body. (Prose said "don't leak"; this enforces it.)
    rc = (((c.get("ground_truth") or {}).get("root_cause")) or "").lower().split()
    body = ((c.get("input") or {}).get("body") or "").lower()
    return any(" ".join(rc[i:i+6]) in body for i in range(0, max(0, len(rc) - 5)))

def cmd_merge(a):
    g, have = load_gold(); idx = archive_index()
    incoming = json.load(open(a.file))
    cases = incoming if isinstance(incoming, list) else incoming.get("cases", [])
    added = skipped_dup = skipped_inelig = skipped_leak = capped = 0
    out = list(g.get("cases", []))
    for c in cases:
        cid = c.get("id")
        if not cid or cid in have: skipped_dup += 1; continue
        if not c.get("eligible"): skipped_inelig += 1; continue
        if leaks_answer(c): skipped_leak += 1; continue   # answer leaked into input -> reject (poisoning guard)
        if len(out) >= MAX_CASES: capped += 1; continue
        c.setdefault("added", TODAY)
        if cid in idx: c.setdefault("source", idx[cid]["path"])
        out.append(c); have[cid] = c; added += 1
    g["cases"] = out; g["version"] = f"{TODAY}-curated"
    if added or a.write: json.dump(g, open(GOLD, "w"), indent=1, ensure_ascii=False)
    print(f"merge: +{added} added | {skipped_dup} dup-skipped | {skipped_inelig} ineligible-skipped | "
          f"{skipped_leak} LEAK-skipped (answer in input) | {capped} over-cap-skipped | total now {len(out)} (version {g['version']})")

def cmd_prune(a):
    g, _ = load_gold()
    seen, dups = set(), []
    for c in g.get("cases", []):
        if c["id"] in seen: dups.append(c["id"])
        seen.add(c["id"])
    orphan = [c["id"] for c in g.get("cases", []) if c.get("source") and not os.path.exists(f"{ROOT}/{c['source']}")]
    print("prune candidates (SAFE class only — never by score/difficulty):")
    print(f"  exact-dup ids : {dups}")
    print(f"  orphaned src  : {orphan}")
    if a.apply and (dups or orphan):
        kept, seen2 = [], set()
        for c in g.get("cases", []):
            if c["id"] in seen2 or c["id"] in orphan: continue
            kept.append(c); seen2.add(c["id"])
        g["cases"] = kept; g["version"] = f"{TODAY}-curated"
        json.dump(g, open(GOLD, "w"), indent=1, ensure_ascii=False)
        print(f"  APPLIED -> {len(kept)} cases (version {g['version']})")
    elif dups or orphan:
        print("  (read-only; pass --apply to remove the SAFE class above)")
    else:
        print("  none")

ap = argparse.ArgumentParser()
sub = ap.add_subparsers(dest="mode")
sub.add_parser("report")
n = sub.add_parser("new-ids"); n.add_argument("--limit", type=int, default=15); n.add_argument("--type", default="")
m = sub.add_parser("merge"); m.add_argument("file"); m.add_argument("--write", action="store_true")
p = sub.add_parser("prune"); p.add_argument("--apply", action="store_true")
a = ap.parse_args()
{"report": cmd_report, "new-ids": cmd_new_ids, "merge": cmd_merge, "prune": cmd_prune}.get(a.mode or "report", cmd_report)(a)
PY
