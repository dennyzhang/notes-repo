#!/usr/bin/env bash
# generate-autolearn-changelog.sh — Rebuild AUTOLEARN-CHANGELOG.md from all cheatsheets + metrics log.
# Single source of truth for everything the system has auto-learned.
# Run: bash ~/work/claude/scripts/generate-autolearn-changelog.sh

set -euo pipefail

REPO_DIR="$HOME/work/claude"
OUTPUT="$REPO_DIR/context/cache/AUTOLEARN-CHANGELOG.md"

python3 << 'PYEOF'
import re, os
from datetime import date
from pathlib import Path

cheatsheet_dir = Path(os.path.expanduser("~/work/claude/cheatsheets"))
entries = []

for md_file in cheatsheet_dir.rglob("*.md"):
    rel = str(md_file.relative_to(cheatsheet_dir))
    with open(md_file) as f:
        for line in f:
            m = re.search(r'\(Learned (\d{4}-\d{2}-\d{2}):?\s*(.+?)\)', line)
            if m:
                dt = m.group(1)
                source = m.group(2).strip().rstrip(')')
                cells = [c.strip() for c in line.split('|') if c.strip()]
                rule = cells[0] if cells else line.strip()
                if len(rule) > 120:
                    rule = rule[:117] + "..."
                entries.append((dt, source, rel, rule))

metrics = os.path.expanduser("~/work/claude/state/autolearn-metrics.csv")
if os.path.exists(metrics):
    with open(metrics) as f:
        for line in f:
            parts = line.strip().split(',', 4)
            if len(parts) >= 5 and parts[1] == 'experiment':
                dt = parts[0].split(' ')[0]
                desc = parts[4][:120]
                entries.append((dt, 'experiment-apply', 'crontab', desc))

entries.sort(key=lambda x: x[0])

out = os.path.expanduser("~/work/claude/context/cache/AUTOLEARN-CHANGELOG.md")
with open(out, 'w') as f:
    f.write("# Autolearn Changelog\n\n")
    f.write("Single source of truth for all auto-learned rules, corrections, and experiments.\n")
    f.write(f"Last rebuilt: {date.today()}\n\n")
    f.write(f"**Total entries: {len(entries)}**\n\n")
    f.write("| # | Date | Source | File | What was learned |\n")
    f.write("|---|------|--------|------|------------------|\n")
    for i, (dt, source, file, rule) in enumerate(entries, 1):
        rule = rule.replace('|', '\\|')
        f.write(f"| {i} | {dt} | {source} | `{file}` | {rule} |\n")

print(f"Wrote {len(entries)} entries to {out}")
PYEOF
