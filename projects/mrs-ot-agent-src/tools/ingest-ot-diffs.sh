#!/usr/bin/env bash
# ingest-ot-diffs.sh — mirror Phabricator diffs AUTHORED BY KEY OT PEOPLE into the
# OT-agent context corpus, so the change-delta-first ("what changed?") triage step has a
# recent-authored-diffs corpus to consult.
#
# WHY: today no cron ingests authored diffs — gchat/post monitors only capture incidental
# D### references. The diagram (`ctx` node) and the eval README Deep-dive both claim "diffs"
# are ingested daily; this tool makes that claim TRUE.
#
# ROSTER = person-centric (operator 2026-06-13: "pull from key people ... whoever are the key
# contributors and influencers ... different people have different trust level"). The roster is
# the CURATED key-people.json (references/key-people.json) — every person whose `surfaces`
# include "diffs". This replaces the old live-oncall-rotation roster: the curated file is always
# present (no cache-fallback machinery needed) and carries a per-person trust tier that is
# stamped onto the output for downstream weighting. The oncall rotation (diff-sources.json
# `candidate_rotation`) is now a PROPOSE-ONLY candidate feed: any active member NOT in the
# roster is surfaced (stderr) as a candidate-to-add, never auto-ingested — curation stays
# operator-controlled. Read-only on Phabricator: `meta phabricator.diff list` (search) ONLY —
# never comment/update/abandon. Read-only on oncall: `members list` ONLY.
#
# LEAK-SAFE: per diff we capture ONLY change-metadata — diff id (D###), author, title,
# summary, status, created date, url. NO diff bodies, NO reviewer lists, NO file contents.
#
# OUTPUT: one markdown file per author at references/diffs/<unixname>.md, idempotent on
# (diff number + status + created). Re-runs only rewrite a file when a diff is new OR its
# status changed. A combined README.md index is regenerated each run.
#
# DEDUP / IDEMPOTENCY: each <unixname>.md carries a machine block (one JSON line per diff,
# in an HTML comment). A run merges fresh results into that block keyed on diff number;
# the file is rewritten ONLY if the merged set differs from what's on disk (so a no-drift
# run touches nothing and the notes auto-push has nothing to commit).
#
# Usage:
#   bash ingest-ot-diffs.sh [--dry-run] [--config PATH] [--roster PATH] [--out-dir PATH] [--lookback-days N]
#
# Options:
#   --dry-run         Query + report counts, write NOTHING (for verification).
#   --config PATH     Override diff-sources.json path (lookback / per-author-limit / candidate_rotation).
#   --roster PATH     Override key-people.json path.
#   --out-dir PATH    Override references/diffs/ output dir.
#   --lookback-days N Override the config lookback_days (use for a backfill seed pull).
#
# Exit codes:
#   0 = ran ok (some diffs found or clean no-op)
#   2 = usage / config / fatal error
#
# Self-reporting: emits a one-line summary to stdout:
#   {"summary":{"authors":N,"authors_with_diffs":A,"diffs":M,"written":W,"errors":E,"lookback_days":D}}

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Default config + out-dir live in the notes context tree (sibling of references/gdocs/).
CONTEXT_DIR="$(cd "${SCRIPT_DIR}/../../mrs-ot-agent-context" 2>/dev/null && pwd || true)"
CONFIG="${CONTEXT_DIR}/references/diffs/diff-sources.json"
KEY_PEOPLE="${CONTEXT_DIR}/references/key-people.json"
OUT_DIR="${CONTEXT_DIR}/references/diffs"
DRY_RUN=false
LOOKBACK_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)        DRY_RUN=true; shift ;;
    --config)         CONFIG="$2"; shift 2 ;;
    --roster)         KEY_PEOPLE="$2"; shift 2 ;;
    --out-dir)        OUT_DIR="$2"; shift 2 ;;
    --lookback-days)  LOOKBACK_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,46p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ ! -f "${CONFIG}" ]; then
  echo "ERROR: diff-sources.json not found at ${CONFIG}" >&2
  exit 2
fi
if [ ! -f "${KEY_PEOPLE}" ]; then
  echo "ERROR: key-people.json not found at ${KEY_PEOPLE}" >&2
  exit 2
fi

# Parse static knobs from diff-sources.json: lookback_days, per_author_limit, and the
# (now optional) candidate_rotation used only to PROPOSE new people for the curated roster.
CFG_JSON=$(LOOKBACK_OVERRIDE="${LOOKBACK_OVERRIDE}" python3 - "${CONFIG}" <<'PY'
import json, sys, os
cfg = json.load(open(sys.argv[1]))
rotation = (cfg.get("candidate_rotation") or cfg.get("roster_rotation") or "").strip()
lb = os.environ.get("LOOKBACK_OVERRIDE") or cfg.get("lookback_days", 14)
try:
    lb = int(lb)
except Exception:
    lb = 14
lim = cfg.get("per_author_limit", 50)
try:
    lim = int(lim)
except Exception:
    lim = 50
print(json.dumps({"rotation": rotation, "lookback_days": lb, "per_author_limit": lim}))
PY
) || { echo "ERROR: failed to parse ${CONFIG}" >&2; exit 2; }

ROTATION=$(echo "${CFG_JSON}" | python3 -c "import json,sys; print(json.load(sys.stdin)['rotation'])")
LOOKBACK_DAYS=$(echo "${CFG_JSON}" | python3 -c "import json,sys; print(json.load(sys.stdin)['lookback_days'])")
PER_AUTHOR_LIMIT=$(echo "${CFG_JSON}" | python3 -c "import json,sys; print(json.load(sys.stdin)['per_author_limit'])")

# ---- CURATED ROSTER (person-centric) ----------------------------------------
# Roster = key-people.json members whose `surfaces` include "diffs". Single source of truth
# for WHO we ingest (operator-curated, trust-tiered). Always present → no cache fallback.
ROSTER_JSON=$(python3 - "${KEY_PEOPLE}" <<'PY'
import json, sys
kp = json.load(open(sys.argv[1]))
roster = [p for p in kp.get("people", []) if "diffs" in (p.get("surfaces") or [])]
authors = sorted({(p.get("unixname") or "").strip() for p in roster if p.get("unixname")})
trust = {(p.get("unixname") or "").strip(): {"trust": p.get("trust"),
         "domains": p.get("domains", [])} for p in roster if p.get("unixname")}
print(json.dumps({"authors": authors, "trust": trust}))
PY
) || { echo "ERROR: failed to parse ${KEY_PEOPLE}" >&2; exit 2; }

AUTHORS_CSV=$(echo "${ROSTER_JSON}" | python3 -c "import json,sys; print(','.join(json.load(sys.stdin)['authors']))")
TRUST_JSON=$(echo "${ROSTER_JSON}" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)['trust']))")
N_AUTHORS=$(echo -n "${AUTHORS_CSV}" | awk -F',' '{print ($0=="")?0:NF}')

if [ -z "${AUTHORS_CSV}" ] || [ "${N_AUTHORS}" -eq 0 ]; then
  echo "ERROR: key-people.json has no members with the 'diffs' surface" >&2
  exit 2
fi

# ---- CANDIDATE DISCOVERY (propose-only) -------------------------------------
# Best-effort: resolve candidate_rotation live; any active member NOT in the curated roster
# is surfaced as a candidate-to-add (propose-only, never auto-ingested). Non-fatal on failure.
CANDIDATES_CSV=""
if [ -n "${ROTATION}" ]; then
  MEMBERS_JSON=$(timeout 60 meta oncall.rotation.members list -r "${ROTATION}" --active-only -o json 2>/dev/null) || MEMBERS_JSON=""
  CANDIDATES_CSV=$(MEMBERS_JSON="${MEMBERS_JSON}" AUTHORS_CSV="${AUTHORS_CSV}" python3 <<'PY'
import json, os
raw = os.environ.get("MEMBERS_JSON", "").strip()
roster = {a for a in os.environ.get("AUTHORS_CSV", "").split(",") if a}
try:
    members = {(m.get("unixname") or "").strip() for m in (json.loads(raw) if raw else []) if m.get("unixname")}
except Exception:
    members = set()
print(",".join(sorted(members - roster)))
PY
)
  [ -n "${CANDIDATES_CSV}" ] && echo "CANDIDATES (active on '${ROTATION}', not in key-people.json — propose adding): ${CANDIDATES_CSV}" >&2
fi
ROSTER_SOURCE="key-people.json"

AFTER_DATE=$(python3 -c "from datetime import date, timedelta; print((date.today()-timedelta(days=${LOOKBACK_DAYS})).isoformat())")
NOW_ISO=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")

if [ "${DRY_RUN}" = "false" ]; then
  mkdir -p "${OUT_DIR}"
fi

# One bulk query — --author-is accepts comma-separated names. We capture change-metadata
# columns only. Single timeout-guarded call keeps the cron budget bounded.
DIFFS_JSON=$(timeout 180 meta phabricator.diff list \
  --author-is="${AUTHORS_CSV}" \
  --time-created-is-after="${AFTER_DATE}" \
  --columns=number,title,status,author,created,summary,url \
  -o json -l "$(( N_AUTHORS * PER_AUTHOR_LIMIT ))" 2>/dev/null) || {
  echo '{"summary":{"authors":'"${N_AUTHORS}"',"authors_with_diffs":0,"diffs":0,"written":0,"errors":1,"lookback_days":'"${LOOKBACK_DAYS}"'}}'
  echo "ERROR: meta phabricator.diff list failed (auth/timeout?)" >&2
  exit 2
}

# Stash the query result to a temp file so the python heredoc (which IS stdin) can read the
# DATA from a file path passed on argv — not from stdin (stdin is consumed by the heredoc).
DIFFS_TMP=$(mktemp)
trap 'rm -f "${DIFFS_TMP}"' EXIT
printf '%s' "${DIFFS_JSON}" > "${DIFFS_TMP}"

# Process: group by author, merge into per-author markdown files idempotently.
SUMMARY=$(OUT_DIR="${OUT_DIR}" DRY_RUN="${DRY_RUN}" NOW_ISO="${NOW_ISO}" \
  LOOKBACK_DAYS="${LOOKBACK_DAYS}" AFTER_DATE="${AFTER_DATE}" \
  N_AUTHORS="${N_AUTHORS}" ROTATION="${ROTATION}" ROSTER_SOURCE="${ROSTER_SOURCE}" \
  ROSTER_CSV="${AUTHORS_CSV}" TRUST_JSON="${TRUST_JSON}" CANDIDATES_CSV="${CANDIDATES_CSV}" \
  python3 - "${DIFFS_TMP}" <<'PY'
import json, os, re, sys

# argv[1] = path to the DIFFS_JSON data file (stdin is the heredoc script).
raw = open(sys.argv[1]).read().strip()
out_dir = os.environ["OUT_DIR"]
dry = os.environ["DRY_RUN"] == "true"
now_iso = os.environ["NOW_ISO"]
lookback = os.environ["LOOKBACK_DAYS"]
after_date = os.environ["AFTER_DATE"]
n_authors = int(os.environ["N_AUTHORS"])
rotation = os.environ.get("ROTATION", "")
roster_source = os.environ.get("ROSTER_SOURCE", "key-people.json")
roster = {a for a in os.environ.get("ROSTER_CSV", "").split(",") if a}
candidates = [c for c in os.environ.get("CANDIDATES_CSV", "").split(",") if c]
try:
    trust_map = json.loads(os.environ.get("TRUST_JSON", "{}"))
except Exception:
    trust_map = {}

def trust_of(author):
    return (trust_map.get(author) or {}).get("trust", "?")

def domains_of(author):
    return ",".join((trust_map.get(author) or {}).get("domains", []) or [])

try:
    diffs = json.loads(raw) if raw else []
except Exception:
    diffs = []

# Keep ONLY change-metadata fields (leak-safe whitelist).
KEEP = ("number", "title", "status", "author", "created", "summary", "url")
# Summary cap (2026-06-13): the summary carries the root-cause "why" (the field that was
# previously dropped entirely), but full diff summaries run 1-1.4KB and a very active author
# (127 diffs/30d) would bloat the file to 250KB+. Cap at 450 chars — the first paragraph holds
# the gist — applied at STORAGE so the machine block, details render, and on-disk size are all bounded.
SUMMARY_CAP = 450
def slim(d):
    r = {k: d.get(k, "") for k in KEEP}
    s = (r.get("summary") or "").strip()
    if len(s) > SUMMARY_CAP:
        s = s[:SUMMARY_CAP].rstrip() + " …"
    r["summary"] = s
    return r

by_author = {}
for d in diffs:
    a = (d.get("author") or "").strip()
    if not a:
        continue
    by_author.setdefault(a, {})[d.get("number")] = slim(d)

MACHINE_BEGIN = "<!-- OT-DIFFS-MACHINE-BEGIN (one JSON line per diff; keyed on number) -->"
MACHINE_END = "<!-- OT-DIFFS-MACHINE-END -->"

def read_existing(path):
    """Return dict number->record from the machine block of an existing file."""
    recs = {}
    if not os.path.exists(path):
        return recs
    txt = open(path).read()
    m = re.search(re.escape(MACHINE_BEGIN) + r"(.*?)" + re.escape(MACHINE_END), txt, re.S)
    if not m:
        return recs
    for line in m.group(1).splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            r = json.loads(line)
            # Re-slim through the leak-safe whitelist so any stray field that ever
            # landed on disk (manual edit, schema drift) is dropped on read.
            recs[r.get("number")] = slim(r)
        except Exception:
            pass
    return recs

def render(author, recs):
    """recs: dict number->record. Returns full markdown file text."""
    # sort by created desc (string ISO sorts correctly)
    ordered = sorted(recs.values(), key=lambda r: r.get("created", ""), reverse=True)
    lines = []
    lines.append("---")
    lines.append(f"author: {author}")
    lines.append(f"trust: {trust_of(author)}")
    lines.append(f"domains: {domains_of(author)}")
    lines.append(f"source: meta phabricator.diff list --author-is={author}")
    lines.append("roster: key-people.json (curated, trust-tiered)")
    lines.append(f"last_synced: {now_iso}")
    lines.append(f"lookback_days: {lookback}")
    lines.append(f"diff_count: {len(ordered)}")
    lines.append("note: AUTO-GENERATED by ingest-ot-diffs.sh (ot-ingest-diffs cron). DO NOT EDIT — clobbered on next sync. Change-metadata only; no diff bodies.")
    lines.append("---")
    lines.append("")
    lines.append(f"# OT key-person authored diffs — {author} (trust {trust_of(author)})")
    lines.append("")
    lines.append(f"Phabricator diffs created since {after_date} (change-delta corpus for the \"what changed?\" triage step). Metadata only.")
    lines.append("")
    # Scannable index table.
    lines.append("| Diff | Status | Created | Title |")
    lines.append("|------|--------|---------|-------|")
    for r in ordered:
        title = (r.get("title") or "").replace("|", "\\|").replace("\n", " ")[:160]
        created = (r.get("created") or "")[:10]
        num = r.get("number") or ""
        url = r.get("url") or (f"https://www.internalfb.com/diff/{num}")
        lines.append(f"| [{num}]({url}) | {r.get('status','')} | {created} | {title} |")
    lines.append("")
    # Details — title + SUMMARY (the root-cause "why"; previously dropped, 2026-06-13).
    # Summary is the highest-value field for change-delta triage. Already capped at SUMMARY_CAP
    # in slim() (open the diff via the link for the full text).
    lines.append("## Diff details (title + summary)")
    lines.append("")
    for r in ordered:
        num = r.get("number") or ""
        url = r.get("url") or (f"https://www.internalfb.com/diff/{num}")
        title = (r.get("title") or "").replace("\n", " ").strip()
        created = (r.get("created") or "")[:10]
        summary = (r.get("summary") or "").strip()
        lines.append(f"### [{num}]({url}) · {r.get('status','')} · {created}")
        lines.append(f"**{title}**")
        lines.append("")
        if summary:
            for sline in summary.split("\n"):
                lines.append("> " + sline if sline.strip() else ">")
        else:
            lines.append("> _(no summary)_")
        lines.append("")
    # Machine block for idempotent re-merge.
    lines.append(MACHINE_BEGIN)
    for r in ordered:
        lines.append(json.dumps(r, separators=(",", ":"), sort_keys=True))
    lines.append(MACHINE_END)
    lines.append("")
    return "\n".join(lines)

written = 0
total_diffs = sum(len(v) for v in by_author.values())

def strip_synced(t):
    # Compare ignoring the volatile last_synced line so a no-drift run is a true no-op.
    return re.sub(r"^last_synced:.*$", "", t, flags=re.M)

# Process EVERY author that has fresh diffs OR an existing on-disk file — so files whose
# diffs have all aged out of the window get re-pruned (not left stale). An existing file is
# recognized by an <unixname>.md sibling carrying our machine block.
candidate_authors = set(by_author)
if os.path.isdir(out_dir):
    for fn in os.listdir(out_dir):
        if fn.endswith(".md") and fn not in ("README.md",):
            p = os.path.join(out_dir, fn)
            if read_existing(p):  # only our auto-gen per-author files (have a machine block)
                candidate_authors.add(fn[:-3])

# OFF-ROSTER PRUNE: any on-disk per-author file for someone NO LONGER in the curated roster
# (e.g. removed from key-people.json) is out of scope and must be removed regardless of
# whether its cached diffs are still in-window. Only prune when we have a trustworthy roster
# (non-empty `roster`); never prune on an empty roster (would wipe the corpus on a glitch).
if roster:
    for author in list(candidate_authors):
        if author not in roster:
            path = os.path.join(out_dir, f"{author}.md")
            if os.path.exists(path):
                if not dry:
                    os.remove(path)
                written += 1
            candidate_authors.discard(author)

for author in candidate_authors:
    path = os.path.join(out_dir, f"{author}.md")
    fresh = by_author.get(author, {})
    existing = read_existing(path)
    # Merge: fresh wins on overlap (status updates), keep old ones still in window not re-returned.
    merged = dict(existing)
    merged.update(fresh)
    # Drop records older than the lookback window so files don't grow unbounded.
    merged = {n: r for n, r in merged.items() if (r.get("created", "") or "")[:10] >= after_date}
    old_text = open(path).read() if os.path.exists(path) else ""
    if not merged:
        # Author no longer has any in-window diffs → remove the stale file entirely.
        if old_text:
            if not dry:
                os.remove(path)
            written += 1
        continue
    new_text = render(author, merged)
    if strip_synced(new_text) != strip_synced(old_text):
        if not dry:
            open(path, "w").write(new_text)
        written += 1

# Regenerate the README index (combined view) — only if content drifted.
idx_path = os.path.join(out_dir, "README.md")
idx = []
idx.append("# OT key-person authored-diffs corpus")
idx.append("")
idx.append("AUTO-GENERATED by `ingest-ot-diffs.sh` (the `ot-ingest-diffs` cron).")
idx.append("Mirrors Phabricator diffs **authored by key OT people** so the change-delta-first")
idx.append("(\"what changed?\") triage step has a recent-authored-diffs corpus. **Change-metadata only**")
idx.append("(diff id, author, title, summary, status, date, url) — no diff bodies. Notes-only; not")
idx.append("mirrored to fbcode. Read-only on Phabricator.")
idx.append("")
idx.append(f"- Roster: **key-people.json** (curated, trust-tiered) — {n_authors} member(s) with the `diffs` surface.")
idx.append(f"- Lookback: {lookback} days. Last sync: {now_iso}.")
if candidates:
    idx.append(f"- Candidates to consider (active on `{rotation}`, not in roster): {', '.join(candidates)}.")
idx.append("- Refine scope: edit `key-people.json` (add/remove people, set `surfaces`/`trust`). New devs on the `" + rotation + "` rotation are auto-proposed as candidates (propose-only).")
idx.append("")
idx.append("| Author | Trust | Diffs (window) | File |")
idx.append("|--------|------:|---------------:|------|")
# Index reflects the on-disk per-author files (post-prune), not just the fresh query.
on_disk = {}
if os.path.isdir(out_dir):
    for fn in os.listdir(out_dir):
        if fn.endswith(".md") and fn != "README.md":
            recs = read_existing(os.path.join(out_dir, fn))
            if recs:
                on_disk[fn[:-3]] = len(recs)
for author in sorted(on_disk):
    idx.append(f"| {author} | {trust_of(author)} | {on_disk[author]} | [{author}.md]({author}.md) |")
idx.append("")
idx_text = "\n".join(idx)
def strip_synced2(t):
    return re.sub(r"Last sync:.*?\.", "", t)
old_idx = open(idx_path).read() if os.path.exists(idx_path) else ""
if strip_synced2(idx_text) != strip_synced2(old_idx):
    if not dry:
        open(idx_path, "w").write(idx_text)
    written += 1

print(json.dumps({"summary": {
    "authors": n_authors,
    "authors_with_diffs": len(by_author),
    "diffs": total_diffs,
    "written": written,
    "errors": 0,
    "lookback_days": int(lookback),
}}))
PY
) || { echo "ERROR: processing failed" >&2; exit 2; }

echo "${SUMMARY}"
exit 0
