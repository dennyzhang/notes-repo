#!/usr/bin/env bash
# cron-collaborator-map.sh — Compute close-collaborator map from the observer journal.
#
# CONSUMER of ~/work/claude/my_work_journal/<date>.md (built by cron-work-journal.sh).
# Composite score per person across 14d + 60d windows: DM depth, co-action-items, small-meeting
# invitees, group-chat co-presence, thanks exchanged. Writes a top-15 table + delta-vs-prior-week
# and cross-references STAKEHOLDERS.md to flag any T1/T2 NOT in the top 10 (sponsor-gap radar).
#
# Output: ~/work/claude/state/collaborator-map.md (overwritten daily) — read by the coach digest
# and surfaced as a 🤝 Closeness moves line when ranks shift ≥2 positions.
#
# Schedule: daily 07:30 (after journal at 23:30, before coach at 08:00).
# Crontab (registered in private_scripts/setup-claude.sh):
#   30 7 * * * source ~/work/claude/scripts/cron-alert.sh && cron_run 300 collaborator-map \
#     ~/work/claude/scripts/cron-collaborator-map.sh >> ~/logs/collaborator-map.log 2>&1

set -eo pipefail

REPO_DIR="$HOME/work/claude"
JOURNAL_DIR="$REPO_DIR/my_work_journal"
STATE_DIR="$REPO_DIR/state"
OUT="$STATE_DIR/collaborator-map.md"
PRIOR="$STATE_DIR/collaborator-map.prior.md"
STAKEHOLDERS="$REPO_DIR/projects/ai-coach-private/STAKEHOLDERS.md"

# shellcheck disable=SC1091
source "$REPO_DIR/scripts/cron-alert.sh"

mkdir -p "$STATE_DIR"
[ ! -d "$JOURNAL_DIR" ] && { cron_alert "collaborator-map" "journal dir missing: $JOURNAL_DIR"; exit 1; }

# Rotate yesterday's map → prior, so today's run can diff ranks
[ -f "$OUT" ] && cp "$OUT" "$PRIOR"

cron_log "computing collaborator map (windows: 14d, 60d)"

OUT="$OUT" PRIOR="$PRIOR" STAKEHOLDERS="$STAKEHOLDERS" JOURNAL_DIR="$JOURNAL_DIR" \
python3 <<'PYEOF'
import os, re, glob, datetime as dt
from collections import Counter

JOURNAL_DIR = os.environ['JOURNAL_DIR']
OUT = os.environ['OUT']
PRIOR = os.environ.get('PRIOR', '')
STAKEHOLDERS = os.environ.get('STAKEHOLDERS', '')

def window(days):
    cutoff = dt.date.today() - dt.timedelta(days=days)
    files = []
    for f in sorted(glob.glob(os.path.join(JOURNAL_DIR, '2*-*-*.md'))):
        try:
            d = dt.date.fromisoformat(os.path.basename(f)[:10])
            if d >= cutoff:
                files.append(f)
        except ValueError:
            continue
    return files

def score_window(files):
    """Composite score per person.
    Weights:
      DM Denny-► turn = 3 (deepest signal of closeness)
      co-action-item (named in their ### section) = 2
      small-meeting invitee (≤6 people) = 2
      group-chat co-presence (per day) = 1
      thanks exchanged = 4 (high-value signal)
    """
    score = Counter()
    detail = {}  # person -> dict of per-signal counts
    def bump(name, kind, n=1, weight=1):
        score[name] += n * weight
        detail.setdefault(name, Counter())[kind] += n

    for f in files:
        with open(f) as fp: text = fp.read()

        # DMs
        for m in re.finditer(r'### DM ·\s*([^\n?]+)\??\s*\n(.+?)(?=\n### |\n## |\Z)', text, re.DOTALL):
            who = m.group(1).strip()
            if not who or who == '?': continue
            body = m.group(2)
            denny_turns = len(re.findall(r'^► |► Denny', body, re.M))
            depth = max(denny_turns, body.count('\n') // 5)
            if depth: bump(who, 'dm_depth', depth, 3)

        # Action items under per-person ### sections (only inside AI meeting notes blocks)
        for m in re.finditer(r'### ([A-Z][a-z]+(?: [A-Z][a-z]+)?)\s*\n((?:- \[ \].+\n?)+)', text):
            who = m.group(1).strip()
            if 'Denny' in who: continue
            n = m.group(2).count('- [ ]')
            if n: bump(who, 'co_action_items', n, 2)

        # Small-meeting invitees (≤6 people = real collaboration, not a townhall)
        for m in re.finditer(r'\*\*Invitees:\*\* (.+)', text):
            invs = [x.strip() for x in m.group(1).split(',') if x.strip()]
            if 2 <= len(invs) <= 6:
                for inv in invs:
                    if 'Denny' in inv: continue
                    bump(inv, 'small_mtg', 1, 2)

        # Group-chat co-presence (name appears in body of a non-DM thread)
        for m in re.finditer(r'### ([^\n]+)\n(.+?)(?=\n### |\n## |\Z)', text, re.DOTALL):
            if 'DM ·' in m.group(1): continue
            body = m.group(2)[:3000]
            seen = set()
            for nm in re.findall(r'\b([A-Z][a-z]+ [A-Z][a-z]+)(?=[: ►,\.])', body):
                if nm == 'Denny Zhang' or nm in seen: continue
                seen.add(nm)
                bump(nm, 'group_touch', 1, 1)

        # Thanks (received + given — both signal closeness)
        thx_sec = re.search(r'## Thanks (?:received|given).*?(?=^## )', text, re.DOTALL|re.M)
        if thx_sec:
            for m in re.finditer(r'\| 2026-\d\d-\d\d \| ([A-Z][a-z]+ [A-Z][a-z]+) \|', thx_sec.group()):
                bump(m.group(1).strip(), 'thanks', 1, 4)

    return score, detail

def canonicalize(score, detail):
    """Merge first-name-only entries into full-name entries when unambiguous.
    'Keir' + 'Keir Simmons' → all credit to 'Keir Simmons'. Drops first-name-only
    entries that have no full-name match (avoids attributing to the wrong person)."""
    full_by_first = {}
    for name in list(score.keys()):
        parts = name.split()
        if len(parts) >= 2:
            full_by_first.setdefault(parts[0], []).append(name)
    for name in list(score.keys()):
        parts = name.split()
        if len(parts) == 1:
            matches = full_by_first.get(parts[0], [])
            if len(matches) == 1:
                score[matches[0]] += score.pop(name)
                if name in detail:
                    for k, v in detail[name].items():
                        detail.setdefault(matches[0], Counter())[k] += v
                    detail.pop(name)
            else:
                # ambiguous (Keir maps to Keir Simmons AND Keir Foobar) or no match — drop
                score.pop(name)
                detail.pop(name, None)
    return score, detail

# Compute 14d + 60d
f14, f60 = window(14), window(60)
s14, d14 = score_window(f14)
s60, _ = score_window(f60)
s14, d14 = canonicalize(s14, d14)
s60, _ = canonicalize(s60, {})

# Rank
top14 = s14.most_common(20)

# Parse prior map for rank-delta
prior_ranks = {}
if PRIOR and os.path.exists(PRIOR):
    with open(PRIOR) as fp:
        for line in fp:
            m = re.match(r'\|\s*(\d+)\s*\|\s*\*?\*?([^|*]+?)\*?\*?\s*\|', line)
            if m:
                try:
                    prior_ranks[m.group(2).strip()] = int(m.group(1))
                except ValueError:
                    pass

# Stakeholders cross-ref — flag T1/T2 NOT in top 10
# Format: `## Tier 1 — ...` followed by multiple `### Name — title (unixname)` rows
t1_t2 = set()
if STAKEHOLDERS and os.path.exists(STAKEHOLDERS):
    with open(STAKEHOLDERS) as fp:
        chunk = fp.read()
    cur_tier = None
    for line in chunk.splitlines():
        m = re.match(r'## Tier (\d[a-z]?)\b', line)
        if m:
            cur_tier = m.group(1)
            continue
        if cur_tier and cur_tier.startswith(('1', '2')):
            n = re.match(r'### ([A-Z][a-z]+(?:[ -][A-Z][a-z]+)*)', line)
            if n:
                t1_t2.add(n.group(1).strip())

top10_names = {p for p, _ in top14[:10]}
sponsor_gap = sorted(t1_t2 - top10_names)

# Write
today = dt.date.today().isoformat()
with open(OUT, 'w') as fp:
    fp.write(f"# Close-collaborator map — {today}\n\n")
    fp.write(f"_From observer journal: {len(f14)} files (14d window), {len(f60)} files (60d window)._\n")
    fp.write("_Composite score: DM-depth×3 + co-action-items×2 + small-mtg×2 + group-touch×1 + thanks×4._\n\n")

    fp.write("## Top 15 collaborators (14d)\n\n")
    fp.write("| # | Person | 14d | Δ rank | 60d | Top signal |\n")
    fp.write("|---|--------|-----|--------|-----|------------|\n")
    for i, (p, sc) in enumerate(top14[:15], 1):
        prior_r = prior_ranks.get(p)
        if prior_r is None:
            delta = "★ new"
        elif prior_r > i:
            delta = f"↑ {prior_r}→{i}"
        elif prior_r < i:
            delta = f"↓ {prior_r}→{i}"
        else:
            delta = "→"
        sc60 = s60.get(p, 0)
        det = d14.get(p, Counter())
        top_sig = det.most_common(1)[0][0] if det else "—"
        fp.write(f"| {i} | {p} | {sc} | {delta} | {sc60} | {top_sig} |\n")

    fp.write("\n## Sponsor-gap radar (T1/T2 stakeholders NOT in top 10)\n\n")
    if sponsor_gap:
        for who in sponsor_gap:
            sc = s14.get(who, 0)
            fp.write(f"- ⚠️ **{who}** — 14d score: {sc}. ")
            fp.write("Zero direct contact in the window.\n" if sc == 0 else "Surface contact only — needs a non-meeting deposit this week.\n")
    elif t1_t2:
        fp.write("_All T1/T2 stakeholders are in the top 10 — sponsor coverage healthy._\n")
    else:
        fp.write("_STAKEHOLDERS.md has no T1/T2 entries to cross-reference._\n")

    fp.write("\n## Closeness moves (vs prior run)\n\n")
    moves = []
    for p, sc in top14[:15]:
        pr = prior_ranks.get(p)
        if pr is None and sc > 0:
            moves.append(f"- ★ **{p}** entered top 15 (score {sc})")
    for p, pr in prior_ranks.items():
        if pr <= 10 and p not in {x for x, _ in top14[:15]}:
            moves.append(f"- ↓ **{p}** dropped out of top 15 (was #{pr})")
    for p, sc in top14[:10]:
        pr = prior_ranks.get(p)
        if pr and pr - top14.index((p, sc)) - 1 >= 2:
            moves.append(f"- ↑ **{p}** climbed {pr - (top14.index((p, sc)) + 1)} positions")
    if moves:
        fp.write("\n".join(moves) + "\n")
    else:
        fp.write("_No significant rank changes since prior run._\n")

print(f"wrote {OUT}: {len(top14)} ranked people, {len(sponsor_gap)} sponsor-gaps")
PYEOF

cron_log "collaborator-map written: $OUT"
write_heartbeat "collaborator-map"
cron_alert_clear "collaborator-map"
