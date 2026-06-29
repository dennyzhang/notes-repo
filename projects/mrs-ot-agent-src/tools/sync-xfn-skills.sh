#!/usr/bin/env bash
# sync-xfn-skills.sh — import XFN (cross-functional) Claude skills from their
# fbcode source-of-truth into the OT MyClaw's local skill load path.
#
# WHY: the agent-market / claude-templates marketplace is a downstream SNAPSHOT
# of fbcode and can lag (newly-landed components take hours-to-days to roll out).
# fbcode is canonical. We copy from fbcode directly and re-run this to keep the
# local copy fresh — the same way the mvai skill is managed (inventory points at
# the fbcode path, not a marketplace install).
#
# Re-runnable / idempotent. Reads tools/xfn-skills.json. For each skill:
#   - copy fbcode source -> notes mirror (reinstall survival)
#   - copy fbcode source -> active skill load path (so MyClaw loads it)
#   - copy fbcode source -> agent context references/xfn-skills/ (OT agent reads these)
#   - record the fbcode commit + sync time in state (staleness audit)
#
# Usage: bash tools/sync-xfn-skills.sh [--check]
#   --check : report fbcode-vs-local drift only; do not copy.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${HERE}/xfn-skills.json"
STATE="${HERE}/../state/xfn-skills-sync-state.json"
CHECK_ONLY=0; [[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

exp() { eval echo "$1"; }  # expand leading ~

FBSRC="$(exp "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["fbsource_root"])' "$MANIFEST")")"
DEST="$(exp "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["dest_skills_dir"])' "$MANIFEST")")"
MIRROR="$(exp "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["notes_mirror"])' "$MANIFEST")")"
CTX="$(exp "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["context_skills_dir"])' "$MANIFEST")")"
mkdir -p "$DEST" "$MIRROR" "$CTX" "$(dirname "$STATE")"

rows="$(python3 -c 'import json,sys
for s in json.load(open(sys.argv[1]))["skills"]:
    print("%s\t%s" % (s["name"], s["fbcode_path"]))' "$MANIFEST")"

results="["; sep=""
while IFS=$'\t' read -r name fbpath; do
  [[ -z "$name" ]] && continue
  src="${FBSRC}/${fbpath}"
  if [[ ! -d "$src" ]]; then
    echo "✗ ${name}: fbcode source missing: ${src}" >&2
    results="${results}${sep}{\"name\":\"${name}\",\"status\":\"SOURCE_MISSING\",\"src\":\"${src}\"}"; sep=","
    continue
  fi
  commit="$(cd "$FBSRC" && sl log -l1 -T '{node|short}' "$fbpath" 2>/dev/null || echo unknown)"
  cdate="$(cd "$FBSRC" && sl log -l1 -T '{date|isodate}' "$fbpath" 2>/dev/null || echo unknown)"
  if [[ "$CHECK_ONLY" == "1" ]]; then
    drift="$(diff -rq "$src" "${DEST}/${name}" 2>/dev/null | head -1 || true)"
    echo "• ${name}: fbcode@${commit} (${cdate}) — $([[ -z "$drift" ]] && echo IN-SYNC || echo "DRIFT: ${drift}")"
    continue
  fi
  # scoped per-skill mirror; --delete is safe (confined to this skill's own dir)
  rsync -a --delete "${src}/" "${MIRROR}/${name}/"
  rsync -a --delete "${src}/" "${DEST}/${name}/"
  rsync -a --delete "${src}/" "${CTX}/${name}/"
  echo "✓ ${name}: synced fbcode@${commit} (${cdate}) -> ${DEST}/${name}"
  results="${results}${sep}{\"name\":\"${name}\",\"status\":\"OK\",\"fbcode_commit\":\"${commit}\",\"fbcode_date\":\"${cdate}\"}"; sep=","
done <<< "$rows"
results="${results}]"

[[ "$CHECK_ONLY" == "1" ]] && exit 0
python3 -c 'import json,sys,subprocess
res=json.loads(sys.argv[2])
ts=subprocess.check_output(["date","-u","+%Y-%m-%dT%H:%M:%SZ"]).decode().strip()
json.dump({"synced_at":ts,"skills":res}, open(sys.argv[1],"w"), indent=1)
print("state ->", sys.argv[1])' "$STATE" "$results"
