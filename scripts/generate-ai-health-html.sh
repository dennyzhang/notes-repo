#!/usr/bin/env bash
# generate-ai-health-html.sh — Convert AI-HEALTH.md to styled HTML for Google Docs.
# Usage: generate-ai-health-html.sh [INPUT_MD] [OUTPUT_HTML]

set -eo pipefail

INPUT="${1:-$HOME/work/claude/context/cache/AI-HEALTH.md}"
OUTPUT="${2:-/tmp/ai-health.html}"

[ ! -f "$INPUT" ] && echo "Input not found: $INPUT" >&2 && exit 1

python3 -c "
import re, sys

with open('$INPUT') as f:
    md = f.read()

html = ['<html><body style=\"font-family: Arial, sans-serif; font-size: 13px; max-width: 900px;\">']

def status_style(status):
    s = status.strip()
    if s == 'GREEN': return 'background-color: #d4edda; color: #155724;'
    if s == 'YELLOW': return 'background-color: #fff3cd; color: #856404;'
    if s == 'RED': return 'background-color: #f8d7da; color: #721c24;'
    return 'background-color: #f8f9fa; color: #666;'

def p_tag(priority):
    colors = {'P0': '#dc3545', 'P1': '#e67700', 'P2': '#666'}
    return f'<span style=\"color:{colors.get(priority, \"#666\")}; font-weight:bold;\">{priority}</span>'

in_table = False
table_header = True

for line in md.split('\n'):
    line = line.rstrip()

    # Title
    if line.startswith('# ') and not line.startswith('## '):
        html.append(f'<h1 style=\"color:#1a73e8; border-bottom: 2px solid #1a73e8; padding-bottom: 8px;\">{line[2:]}</h1>')
        continue

    # Section headers
    if line.startswith('### '):
        if in_table:
            html.append('</table>')
            in_table = False
        html.append(f'<h3 style=\"color:#555; margin-top: 16px;\">{line[4:]}</h3>')
        continue
    if line.startswith('## '):
        if in_table:
            html.append('</table>')
            in_table = False
        html.append(f'<h2 style=\"color:#1a73e8; margin-top: 24px;\">{line[3:]}</h2>')
        continue

    # Overall status line
    if line.startswith('**Overall:'):
        # Color the status badge
        status_match = re.search(r'\*\*Overall: (\w+)\*\*', line)
        if status_match:
            status = status_match.group(1)
            rest = line.split('**', 4)[-1].strip(' —')
            html.append(f'<p style=\"font-size: 14px; margin: 8px 0;\"><b>Overall: <span style=\"{status_style(status)}padding:2px 8px; border-radius:4px;\">{status}</span></b> — {rest}</p>')
        continue

    # Action items (bullet points with priorities)
    if line.startswith('- [P'):
        m = re.match(r'- \[(P\d)\] \*\*(.+?)\*\*:?\s*(.*)', line)
        if m:
            pri, title, detail = m.groups()
            # Convert markdown links
            detail = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href=\"\2\">\1</a>', detail)
            html.append(f'<p style=\"margin: 4px 0 4px 16px;\">• {p_tag(pri)} <b>{title}</b>: {detail}</p>')
        continue

    # Fleet summary line (not a table, not a header)
    if re.match(r'^\d+ registered', line):
        line_html = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', line)
        html.append(f'<p style=\"margin: 4px 0; color: #333;\">{line_html}</p>')
        continue

    # Table rows
    if line.startswith('|'):
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if all(c.replace('-', '') == '' for c in cols):
            table_header = False
            continue  # skip separator row
        if not in_table:
            html.append('<table style=\"border-collapse: collapse; margin: 8px 0;\">')
            in_table = True
            table_header = True

        row_html = '<tr>'
        for i, col in enumerate(cols):
            # Convert markdown links
            col = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href=\"\2\">\1</a>', col)
            col = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', col)

            style = 'padding: 4px 8px; border: 1px solid #ccc;'
            if table_header:
                style = 'background-color: #C9DAF8; ' + style
                col = f'<b>{col}</b>'
            # Color status cells (content-based, works in any column position)
            else:
                stripped = col.strip()
                for s in ['GREEN', 'YELLOW', 'RED']:
                    if stripped == s or stripped == f'<b>{s}</b>':
                        style += ' ' + status_style(s)
                        break

            row_html += f'<td style=\"{style}\">{col}</td>'
        row_html += '</tr>'
        html.append(row_html)
        continue
    else:
        if in_table:
            html.append('</table>')
            in_table = False
            table_header = True

    # Horizontal rule
    if line.startswith('---'):
        html.append('<hr style=\"border: none; border-top: 1px solid #ddd; margin: 16px 0;\">')
        continue

    # Italic footer
    if line.startswith('*') and line.endswith('*'):
        html.append(f'<p style=\"color: #999; font-size: 11px; margin-top: 16px;\"><i>{line.strip(\"*\")}</i></p>')
        continue

    # Generic non-empty lines
    if line.strip():
        line_html = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', line)
        line_html = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href=\"\2\">\1</a>', line_html)
        html.append(f'<p style=\"margin: 4px 0;\">{line_html}</p>')

if in_table:
    html.append('</table>')

html.append('</body></html>')

with open('$OUTPUT', 'w') as f:
    f.write('\n'.join(html))
print(f'HTML written to $OUTPUT ({len(\"\\n\".join(html))} bytes)')
"
