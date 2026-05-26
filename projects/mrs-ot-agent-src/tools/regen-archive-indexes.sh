#!/bin/bash
# Regenerate INDEX.md for mitigated-{sevs,posts,alerts}/ subdirs.
#
# Maps each archive to its failure-patterns.md cluster (CL-NNN) via:
#   Tier 1: explicit Evidence-line citation from failure-patterns.md
#   Tier 2: title-keyword regex (TITLE_RULES in embedded python)
#
# Usage: bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/tools/regen-archive-indexes.sh
#
# Run after new archives land. Should eventually be cron-ified
# (proposal C in ../IMPROVEMENT-PROPOSALS.md).
#
# NOTE: Script body is bash because the fb:notes repo denies .py extensions.
# All real logic is embedded python3 below.

python3 - << 'PYEOF'
import os, re, glob
from pathlib import Path

BASE = Path('/home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-context')
MARKER = '<!-- AUTO-GENERATED TABLE BELOW'

def read_header(index_path):
    """Preserve hand-written content above the AUTO-GENERATED marker."""
    if not index_path.exists():
        return ''
    text = index_path.read_text()
    idx = text.find(MARKER)
    if idx < 0:
        return ''
    return text[:idx]

TITLE_RULES = [
    (re.compile(r'cogwheel|fbpkg.*build|light_cli|sandcastle.*preempt|trunk.*build|publish.*SIGKILL|publish.*failure', re.I), 'CL-004'),
    (re.compile(r'NCCL.*timeout|ALLTOALL.*timeout|watchdog.*timeout|raas.*timeout|training.*timeout', re.I), 'CL-014'),
    (re.compile(r'training.*age|example.*age|model.*age|scribe.*age|age.*increase|age.*delay', re.I), 'CL-013'),
    (re.compile(r'QPS.*drop|qps.*falling|QPS.*dip|error.*rate.*tier', re.I), 'CL-015'),
    (re.compile(r'QPS.*ramp|slow.*QPS|slow.*ramp.*up', re.I), 'CL-016'),
    (re.compile(r'snapshot.*stuck|stuck.*creating|snapshot.*transition.*stuck|missing.*snapshot|FULL_SNAPSHOT|publishing.*stability|DPP_WORKER_STUCK|stale.*snapshot', re.I), 'CL-001'),
    (re.compile(r'Shampoo|NaN|optimizer.*state|second.*moment|exploding.*gradient|publish.*NaN', re.I), 'CL-017'),
    (re.compile(r'skip_recurring|online_train_publish.*succeed|silent.*success|no.*OT.*diff|failing to produce', re.I), 'CL-009'),
    (re.compile(r'NCCL.*hang|all_to_all.*hang|gloo.*timeout|ZCH.*delta', re.I), 'CL-014'),
    (re.compile(r'e2e latency|sparse.delta.*latency|delta.*delay', re.I), 'CL-013'),
    (re.compile(r'\[AGG\]|aggregation.*rule', re.I), 'CL-AGG'),
    (re.compile(r'ZippyDB|Scribe.*overload|LogDevice|TIXU|EDPP', re.I), 'CL-003'),
    (re.compile(r'cannot.*restart|cannot.*get.*started|cannot.*started|silent.*stall|auto.*start', re.I), 'CL-009'),
    (re.compile(r'migration|preemptive', re.I), 'CL-010'),
    (re.compile(r'MAST.*pending|preempt.*quota|hardware.*data.*colocation', re.I), 'CL-006'),
    (re.compile(r'SIGUSR2|stray.*signal', re.I), 'CL-011'),
]

def load_explicit_clusters():
    fp = (BASE / 'auto-learnings/patterns/failure-patterns.md').read_text()
    out = {}
    current_cl = None
    for line in fp.splitlines():
        m = re.match(r'^### (CL-\d+)', line)
        if m: current_cl = m.group(1); continue
        if current_cl and re.search(r'\*\*Evidence', line):
            for sid in re.findall(r'S\d{5,}', line):
                out.setdefault(sid, []).append(current_cl)
    return out

def map_title(title, explicit=None):
    if explicit: return ' / '.join(explicit)
    matches = []
    for rx, cl in TITLE_RULES:
        if rx.search(title) and cl not in matches:
            matches.append(cl)
            if len(matches) >= 2: break
    return ' / '.join(matches) if matches else '(unmapped)'

def regen_sevs(explicit):
    rows = []
    for sf in sorted(glob.glob(str(BASE / 'incidents/resolved-sevs/*/L*.md'))):
        p = Path(sf); m = re.match(r'(L\d)-(\d{4}-\d{2}-\d{2})-S(\d+)\.md', p.name)
        if not m: continue
        level, date, sid = m.groups(); sev = f'S{sid}'
        title_m = re.match(r'^# .*S\d+\s*\u2014\s*(.+?)$', p.read_text()[:500], re.M)
        title = title_m.group(1)[:80] if title_m else '(no title)'
        rows.append((date, level, sev, map_title(title, explicit.get(sev)), title, str(p.relative_to(BASE / 'incidents/resolved-sevs'))))
    rows.sort(reverse=True)
    index_path = BASE / 'incidents/resolved-sevs/INDEX.md'
    header = read_header(index_path)
    with open(index_path, 'w') as f:
        f.write(header + MARKER + u' \u2014 do not edit below this line -->\n\n')
        f.write(f"**Total:** {len(rows)} \u00b7 **Mapped:** {sum(1 for r in rows if 'unmapped' not in r[3])} \u00b7 **Unmapped:** {sum(1 for r in rows if 'unmapped' in r[3])}\n\n")
        f.write("| Date | Level | SEV | Error pattern | Title |\n|---|---|---|---|---|\n")
        for r in rows: f.write(f"| {r[0]} | {r[1]} | [{r[2]}]({r[5]}) | {r[3]} | {r[4]} |\n")
    return len(rows), sum(1 for r in rows if 'unmapped' not in r[3])

def regen_posts():
    rows = []
    for pf in sorted(glob.glob(str(BASE / 'incidents/resolved-posts/*/*.md'))):
        p = Path(pf)
        if p.name in ('README.md','INDEX.md'): continue
        m = re.match(r'(\d{4}-\d{2}-\d{2})-W(\d+)\.md', p.name)
        if not m: continue
        date, pid = m.groups()
        title_m = re.search(r'(?:^|\n)# (.+?)$', p.read_text()[:1000], re.M)
        title = title_m.group(1)[:80] if title_m else '(no title)'
        rows.append((date, f'W{pid}', map_title(title), title, str(p.relative_to(BASE / 'incidents/resolved-posts'))))
    rows.sort(reverse=True)
    index_path = BASE / 'incidents/resolved-posts/INDEX.md'
    header = read_header(index_path)
    with open(index_path, 'w') as f:
        f.write(header + MARKER + u' \u2014 do not edit below this line -->\n\n')
        f.write(f"**Total:** {len(rows)} \u00b7 **Mapped:** {sum(1 for r in rows if 'unmapped' not in r[2])}\n\n")
        f.write("| Date | Post | Error pattern | Title |\n|---|---|---|---|\n")
        for r in rows: f.write(f"| {r[0]} | [{r[1]}]({r[4]}) | {r[2]} | {r[3]} |\n")
    return len(rows), sum(1 for r in rows if 'unmapped' not in r[2])

def regen_alerts():
    # Widened regex accepts P0/P1/high/medium/low/unknown prefixes; dedup by alert_id keeps richest archive
    seen = {}  # alert_id -> (size, date, pri, path)
    for af in sorted(glob.glob(str(BASE / 'incidents/resolved-alerts/*/*A*.md'))):
        p = Path(af)
        if p.name in ('README.md','INDEX.md'): continue
        m = re.match(r'([a-zA-Z]+|P\d|unknown)-(\d{4}-\d{2}-\d{2})-A(\d+)\.md', p.name)
        if not m: continue
        pri, date, aid = m.groups()
        sz = p.stat().st_size
        if aid in seen and seen[aid][0] >= sz:
            continue
        seen[aid] = (sz, date, pri, p)
    rows = []
    for aid, (sz, date, pri, p) in seen.items():
        title_m = re.search(r'(?:^|\n)# (.+?)$', p.read_text()[:1000], re.M)
        full_title = title_m.group(1) if title_m else '(no title)'
        display = full_title[:90]
        rows.append((date, pri, f'A{aid}', map_title(full_title), display, str(p.relative_to(BASE / 'incidents/resolved-alerts'))))
    rows.sort(reverse=True)
    index_path = BASE / 'incidents/resolved-alerts/INDEX.md'
    header = read_header(index_path)
    with open(index_path, 'w') as f:
        f.write(header + MARKER + u' \u2014 do not edit below this line -->\n\n')
        f.write(f"**Total:** {len(rows)} \u00b7 **Mapped:** {sum(1 for r in rows if 'unmapped' not in r[3])}\n\n")
        f.write("| Date | Pri | Alert | Error pattern | Title |\n|---|---|---|---|---|\n")
        for r in rows: f.write(f"| {r[0]} | {r[1]} | [{r[2]}]({r[5]}) | {r[3]} | {r[4]} |\n")
    return len(rows), sum(1 for r in rows if 'unmapped' not in r[3])

explicit = load_explicit_clusters()
s_t, s_m = regen_sevs(explicit)
p_t, p_m = regen_posts()
a_t, a_m = regen_alerts()
print(f"SEVs:   {s_m}/{s_t} mapped")
print(f"Posts:  {p_m}/{p_t} mapped")
print(f"Alerts: {a_m}/{a_t} mapped")
PYEOF
