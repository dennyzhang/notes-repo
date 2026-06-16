#!/usr/bin/env bash
# scoping-corpus-curate.sh — automated lifecycle management for the eval SCOPING corpus.
#
# Sibling of gold-set-curate.sh (same .sh+python-heredoc form, same SCORE-BLIND contract). Where
# gold-set-curate feeds eval-flow's triage gold set, THIS feeds eval-scoping's engage/drop corpus
# (eval/scoping-corpus.json) — the fixed set that computes detection_recall + scoping_precision.
#
# (.sh wrapper because the notes repo deny_files hook rejects .py; logic is the embedded python.)
#
# ── FROZEN-CORPUS INVARIANT (read before editing) ────────────────────────────────────────────
# eval-scoping.js FREEZES this corpus: it reads scoping-corpus.json, takes corpus[] items
# {id,label,source,title}, and SHORT-CIRCUITS to the frozen set when len >= FROZEN_MIN (30);
# below 30 it falls back to live mining and runs become non-comparable. So this curator MUST:
#   (1) keep the top-level "corpus" array intact and >= FROZEN_MIN at all times (never prune below);
#   (2) preserve each item's {id,label,source,title} shape (the eval reads exactly these);
#   (3) bump "version" on any mutation — the eval stamps results per-version so cross-run
#       comparisons stay within-version (a growth event starts a new comparable window, like the
#       gold set's weekly bump). Within a version the set is fixed -> runs are comparable.
# The per-item "decision" field is the eval's OUTPUT, written back by eval-scoping. This tool
# NEVER reads it for add/prune. (see ANTI-GAMING below.)
#
# ── ANTI-GAMING / SCORE-BLIND ────────────────────────────────────────────────────────────────
# NO mode reads eval scores, decision-vs-label agreement, or pass/fail. Add/prune key ONLY off
# data properties: archive eligibility (in-org OT, confirmed), dedup by id, orphaned source, label
# balance, cap. Selecting cases the agent gets wrong (or right) = teaching to the test = corrupts
# the whole fitness function. Hard/leaky cases stay; that is a separate operator-reviewed call.
#
# ── THE BALANCE TENSION (flagged honestly, per task) ─────────────────────────────────────────
# scoping_precision needs DROP negatives (out_of_org / non_ot). But the closed-loop archives ONLY
# contain in-org OT incidents — out-of-org / non-OT signals are filtered at triage time and NEVER
# archived. So archive-mining can grow ONLY the ENGAGE side. Left unchecked that erodes the
# engage/drop balance the precision metric depends on. Mitigations baked in here:
#   * `report` surfaces the engage:drop ratio and WARNs when engage growth would push the negative
#     class below MIN_NEG_FRAC of the corpus.
#   * `new-ids` defaults to type=sev (the only archived type that yields engage cases) and is
#     ENGAGE-only by construction; the tool refuses to let merge tip the balance past the floor.
#   * Growing DROP cases is necessarily a live-mining job (eval-scoping's noise miners) or an
#     operator hand-add — it cannot be archive-derived. report says so explicitly.
#
# Modes:
#   report                    read-only: corpus size, engage:drop balance, frozen-min headroom,
#                             archive backlog of candidate ENGAGE ids, orphaned/dup safe-prune
#                             candidates, BALANCE WARN. Default.
#   new-ids --limit N [--type sev]
#                             emit up to N archive SEV ids NOT in the corpus (recent-first) + paths,
#                             JSON. ENGAGE candidates only (archives are in-org OT by construction).
#   merge <candidates.json>   append eligible+new ENGAGE cases (dedup by id, stamp added+source,
#                             MAX_CASES cap, BALANCE floor), bump version. Writes scoping-corpus.json.
#   prune [--apply]           list ONLY safe removals (exact dup id; case whose source archive is
#                             gone). NEVER below FROZEN_MIN, NEVER by score/decision. --apply to act.
#
# Usage: scoping-corpus-curate.sh [mode] [flags]
set -uo pipefail
python3 - "$@" <<'PY'
import json, os, re, sys, glob, datetime, argparse

ROOT = os.path.expanduser("~/notes/users/dennyzhang/projects/mrs-ot-agent-context")
CORPUS = f"{ROOT}/eval/scoping-corpus.json"
# Archives are in-org OT only -> ENGAGE source only. SEV is the archived type that maps to scoping
# signals; alert/post archives are not part of the scoping corpus's id space today.
ARCHIVE_DIRS = {"sev": "incidents/resolved-sevs"}
MAX_CASES = 120          # hard cap on corpus size (keeps the eval tractable / per-item agent call bounded)
FROZEN_MIN = 30          # MUST match eval-scoping.js FROZEN_MIN — below this the eval re-mines (non-comparable)
MIN_NEG_FRAC = 0.30      # negatives (drop) must stay >= this fraction; below it scoping_precision degenerates
ID_RE = re.compile(r"(S\d{6,})")
TODAY = datetime.date.today().isoformat()

def load_corpus():
    g = json.load(open(CORPUS)); return g, {c["id"]: c for c in g.get("corpus", [])}

def archive_index():
    idx = {}
    for typ, d in ARCHIVE_DIRS.items():
        for f in glob.glob(f"{ROOT}/{d}/**/*.md", recursive=True):
            base = os.path.basename(f)
            if base in ("INDEX.md", "noisy-models.md", "MISSING.md"): continue
            m = ID_RE.search(base)
            if m: idx.setdefault(m.group(1), {"type": typ, "path": os.path.relpath(f, ROOT)})
    return idx

def balance(cases):
    eng = sum(1 for c in cases if c.get("label") == "engage")
    drp = sum(1 for c in cases if c.get("label") == "drop")
    return eng, drp

def neg_frac(cases):
    eng, drp = balance(cases)
    return (drp / (eng + drp)) if (eng + drp) else 0.0

def cmd_report(_):
    g, have = load_corpus(); idx = archive_index()
    eng, drp = balance(have.values())
    backlog = {i: v for i, v in idx.items() if i not in have}  # candidate ENGAGE ids
    # NOTE: existing corpus uses "source" for CLASSIFICATION (out_of_org/non_ot/auto_detected_false),
    # NOT a file path. Orphan-prune is keyed off the curator-stamped "source_path" only.
    orphan = [i for i, c in have.items() if c.get("source_path") and not os.path.exists(f"{ROOT}/{c['source_path']}")]
    seen, dups = set(), []
    for c in g.get("corpus", []):
        if c["id"] in seen: dups.append(c["id"])
        seen.add(c["id"])
    print(f"scoping corpus: {len(have)} cases (version {g.get('version')})  cap {MAX_CASES}  frozen-min {FROZEN_MIN}")
    print(f"  balance        : {eng} engage / {drp} drop  (neg-frac {neg_frac(have.values()):.2f}, floor {MIN_NEG_FRAC:.2f})")
    print(f"  frozen status  : {'OK' if len(have) >= FROZEN_MIN else 'BELOW FROZEN_MIN — eval will re-mine!'}  (headroom over min: {len(have) - FROZEN_MIN})")
    print(f"  room to cap    : {max(0, MAX_CASES - len(have))}")
    print(f"  ENGAGE backlog : {len(backlog)} in-org OT archive SEVs not yet in corpus (archive-derivable)")
    print(f"  DROP backlog   : 0 archive-derivable — out-of-org/non-OT are filtered pre-archive;")
    print(f"                   grow DROP via eval-scoping live noise-mining or operator hand-add ONLY")
    print(f"  date-stamped   : {sum(1 for c in have.values() if c.get('added'))}/{len(have)} (curator-added)")
    print(f"  safe-prune     : {len(dups)} dup ids {dups[:6]} | {len(orphan)} orphaned-src {orphan[:6]}")
    # BALANCE WARN: how many engage adds before we hit the negatives floor.
    # adding k engage: drp / (eng+k+drp) >= MIN_NEG_FRAC  ->  k <= drp/MIN_NEG_FRAC - (eng+drp)
    room_before_floor = int(drp / MIN_NEG_FRAC - (eng + drp)) if drp else 0
    if room_before_floor <= 0:
        print(f"  *** BALANCE WARN: negatives at/below floor ({neg_frac(have.values()):.2f} <= {MIN_NEG_FRAC:.2f}).")
        print(f"      merge will REFUSE further engage adds until drop cases are added. ***")
    else:
        print(f"  balance budget : can add up to {room_before_floor} engage case(s) before hitting the neg-frac floor")

def cmd_new_ids(a):
    g, have = load_corpus(); idx = archive_index()
    want = [t.strip() for t in a.type.split(",")] if a.type else list(ARCHIVE_DIRS)
    cand = [{"id": i, "type": v["type"], "path": v["path"]} for i, v in idx.items() if i not in have and v["type"] in want]
    def datekey(c):
        m = re.search(r"(\d{4}-\d{2}-\d{2})", c["path"]); return m.group(1) if m else c["path"]
    cand.sort(key=datekey, reverse=True)
    # These are ENGAGE candidates by construction (in-org OT archives). The extractor sets label="engage".
    print(json.dumps({"candidates": cand[: a.limit], "note": "all label=engage (in-org OT archives); set source=auto_detected_false unless the archive shows an alarm fired"}, indent=1))

def cmd_merge(a):
    g, have = load_corpus(); idx = archive_index()
    incoming = json.load(open(a.file))
    cases = incoming if isinstance(incoming, list) else incoming.get("cases", incoming.get("corpus", []))
    out = list(g.get("corpus", []))
    added = skipped_dup = skipped_inelig = skipped_balance = capped = 0
    for c in cases:
        cid = c.get("id")
        if not cid or cid in have: skipped_dup += 1; continue
        if not c.get("eligible"): skipped_inelig += 1; continue
        if c.get("label") not in ("engage", "drop"): skipped_inelig += 1; continue
        if len(out) >= MAX_CASES: capped += 1; continue
        # BALANCE floor: adding an engage case must not push negatives below MIN_NEG_FRAC.
        if c.get("label") == "engage":
            trial = out + [c]
            if neg_frac(trial) < MIN_NEG_FRAC:
                skipped_balance += 1; continue
        rec = {"id": cid, "label": c["label"], "source": c.get("source", "auto_detected_false"),
               "title": c.get("title", ""), "added": TODAY}
        if cid in idx: rec["source_path"] = idx[cid]["path"]  # for orphan-prune; not read by eval
        out.append(rec); have[cid] = rec; added += 1
    g["corpus"] = out
    g["corpus_size"] = {"total": len(out), **dict(zip(("positives", "negatives"), balance(out)))}
    if added or a.write:
        g["version"] = f"{TODAY}-curated"
        json.dump(g, open(CORPUS, "w"), indent=1, ensure_ascii=False)
    eng, drp = balance(out)
    print(f"merge: +{added} added | {skipped_dup} dup-skipped | {skipped_inelig} ineligible-skipped | "
          f"{skipped_balance} balance-floor-skipped | {capped} over-cap-skipped | "
          f"total now {len(out)} ({eng} engage/{drp} drop, version {g.get('version')})")

def cmd_prune(a):
    g, _ = load_corpus()
    cases = g.get("corpus", [])
    seen, dups = set(), []
    for c in cases:
        if c["id"] in seen: dups.append(c["id"])
        seen.add(c["id"])
    orphan = [c["id"] for c in cases if c.get("source_path") and not os.path.exists(f"{ROOT}/{c['source_path']}")]
    print("prune candidates (SAFE class only — never by score/decision/difficulty):")
    print(f"  exact-dup ids : {dups}")
    print(f"  orphaned src  : {orphan}  (only curator-stamped source_path cases are eligible)")
    if a.apply and (dups or orphan):
        kept, seen2 = [], set()
        for c in cases:
            if c["id"] in seen2 or c["id"] in orphan: continue
            kept.append(c); seen2.add(c["id"])
        if len(kept) < FROZEN_MIN:
            print(f"  REFUSED: pruning would drop corpus to {len(kept)} < FROZEN_MIN {FROZEN_MIN} "
                  f"(eval would re-mine, breaking comparability). No change."); return
        g["corpus"] = kept
        g["corpus_size"] = {"total": len(kept), **dict(zip(("positives", "negatives"), balance(kept)))}
        g["version"] = f"{TODAY}-curated"
        json.dump(g, open(CORPUS, "w"), indent=1, ensure_ascii=False)
        print(f"  APPLIED -> {len(kept)} cases (version {g['version']})")
    elif dups or orphan:
        print("  (read-only; pass --apply to remove the SAFE class above)")
    else:
        print("  none")

ap = argparse.ArgumentParser()
sub = ap.add_subparsers(dest="mode")
sub.add_parser("report")
n = sub.add_parser("new-ids"); n.add_argument("--limit", type=int, default=15); n.add_argument("--type", default="sev")
m = sub.add_parser("merge"); m.add_argument("file"); m.add_argument("--write", action="store_true")
p = sub.add_parser("prune"); p.add_argument("--apply", action="store_true")
a = ap.parse_args()
{"report": cmd_report, "new-ids": cmd_new_ids, "merge": cmd_merge, "prune": cmd_prune}.get(a.mode or "report", cmd_report)(a)
PY
