#!/usr/bin/env bash
# area-monitor.sh — Nightly scan of your organizational neighborhood.
#
# Monitors peer activity (diffs/PRs, posts), group discussions, and incidents.
# Synthesizes into a daily digest with actionable insights via Claude.
#
# Output: cache/AREA-MONITOR.md (local markdown digest)
#
# Usage:
#   bash area-monitor.sh                    # Run with defaults
#   REPO_DIR=~/my-workspace bash area-monitor.sh  # Custom workspace
#
# Crontab:
#   0 3 * * * bash ~/work/claude/scripts/area-monitor.sh >> ~/logs/area-monitor.log 2>&1

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION — edit these paths to match your workspace layout
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="${REPO_DIR:-$HOME/work/claude}"
CONFIG="$REPO_DIR/config/area-monitor-config.json"
TEMPLATE="$REPO_DIR/templates/area-monitor-template.md"
CACHE="$REPO_DIR/cache/AREA-MONITOR.md"
LOCK_FILE="/tmp/area-monitor.lock"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')

# ═══════════════════════════════════════════════════════════════════════════════
# PRE-CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

if [ ! -f "$CONFIG" ]; then
    echo "$LOG_PREFIX [FAIL] Config not found: $CONFIG"
    echo "Copy area-monitor-config.json to $CONFIG and fill in your peers."
    exit 1
fi

if ! command -v claude &>/dev/null; then
    echo "$LOG_PREFIX [FAIL] claude CLI not found. Install Claude Code first."
    exit 1
fi

# Prevent overlapping runs
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$lock_age" -lt 7200 ]; then
        echo "$LOG_PREFIX Already running (pid $pid, age ${lock_age}s), skipping"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; rm -rf "${WORK_DIR:-}"' EXIT

echo "$LOG_PREFIX === Area Monitor ==="

WORK_DIR=$(mktemp -d /tmp/area-monitor-XXXX)
LOOKBACK=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('lookback_days', 7))")
START_DATE=$(date -d "-${LOOKBACK} days" '+%Y-%m-%d' 2>/dev/null || date -v-${LOOKBACK}d '+%Y-%m-%d')

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: DATA COLLECTION
#
# *** ADAPT THIS SECTION TO YOUR COMPANY'S TOOLS ***
#
# The functions below use placeholder commands. Replace them with your
# company's search API, PR system, and incident tooling.
#
# Each function writes raw text to files in $WORK_DIR/.
# The format doesn't matter much — Claude will parse it.
# ═══════════════════════════════════════════════════════════════════════════════

collect_peer_activity() {
    echo "$LOG_PREFIX  [1/3] Collecting peer activity..."

    python3 - "$CONFIG" "$WORK_DIR" "$START_DATE" << 'PYEOF'
import json, sys, subprocess, os

config_path = sys.argv[1]
work_dir = sys.argv[2]
start_date = sys.argv[3]

with open(config_path) as f:
    config = json.load(f)

peers = config.get("peers", [])
all_activity = []

for peer in peers:
    name = peer["name"]
    username = peer.get("username", "")
    user_id = peer.get("id", "")
    circle = peer.get("circle", "unknown")
    role = peer.get("role", "")

    # ──────────────────────────────────────────────────────────────
    # ADAPT: Replace these with your company's API calls.
    #
    # Examples for different platforms:
    #
    # GitHub:
    #   gh api "search/issues?q=author:{username}+type:pr+created:>{start_date}" \
    #       --jq '.items[] | "\(.title) | \(.html_url)"'
    #
    # GitLab:
    #   curl "https://gitlab.com/api/v4/merge_requests?author_username={username}&created_after={start_date}"
    #
    # Phabricator:
    #   arc list --author {username} --json
    #
    # Meta (internal):
    #   meta search.doc search -q " " --doc-type=DIFF --author {user_id} \
    #       --start-creation-time {start_date} --limit 15 -o json
    # ──────────────────────────────────────────────────────────────

    diffs = []
    posts = []

    # Placeholder: fetch PRs/diffs for this peer
    try:
        # REPLACE with your API call
        # result = subprocess.run([...], capture_output=True, text=True, timeout=30)
        # diffs = json.loads(result.stdout)
        pass
    except Exception:
        pass

    entry = f"### {name} ({role}) [circle: {circle}]\n"
    entry += f"Diffs/PRs ({len(diffs)}):\n"
    for d in diffs[:10]:
        title = d.get("title", "Untitled")
        url = d.get("url", d.get("html_url", ""))
        entry += f"  - {title} | {url}\n"

    entry += f"Posts ({len(posts)}):\n"
    for p in posts[:5]:
        title = p.get("title", "Untitled")
        url = p.get("url", "")
        snippet = str(p.get("snippet", p.get("body", "")))[:300]
        entry += f"  - {title} | {url} | {snippet}\n"

    all_activity.append(entry)

output_path = os.path.join(work_dir, "peer_activity.txt")
with open(output_path, "w") as f:
    f.write("\n".join(all_activity))

print(f"Collected activity for {len(peers)} peers")
PYEOF
}

collect_group_posts() {
    echo "$LOG_PREFIX  [2/3] Collecting group posts..."

    python3 - "$CONFIG" "$WORK_DIR" "$START_DATE" << 'PYEOF'
import json, sys, subprocess, os

config_path = sys.argv[1]
work_dir = sys.argv[2]
start_date = sys.argv[3]

with open(config_path) as f:
    config = json.load(f)

groups = config.get("groups", [])
all_posts = []

for group in groups:
    gid = group["id"]
    gname = group["name"]

    # ──────────────────────────────────────────────────────────────
    # ADAPT: Replace with your company's group/channel API.
    #
    # Slack:
    #   Use conversations.history API for channel messages
    #
    # Workplace:
    #   meta search.doc search --doc-type=GROUP_POST --workplace-group={gid} ...
    #
    # Microsoft Teams:
    #   Use Graph API to fetch channel messages
    # ──────────────────────────────────────────────────────────────

    posts = []
    # REPLACE with your API call
    # try:
    #     result = subprocess.run([...], capture_output=True, text=True, timeout=30)
    #     posts = json.loads(result.stdout)
    # except Exception:
    #     pass

    for p in posts:
        if isinstance(p, dict):
            title = p.get("title", "Untitled")
            url = p.get("url", "")
            snippet = str(p.get("snippet", p.get("body", "")))[:400]
            author = p.get("author", "Unknown")
            all_posts.append(f"[{gname}] {title}\nAuthor: {author}\nURL: {url}\n{snippet}\n---")

output_path = os.path.join(work_dir, "group_posts.txt")
with open(output_path, "w") as f:
    if all_posts:
        f.write(f"Found {len(all_posts)} group posts:\n\n")
        f.write("\n".join(all_posts))
    else:
        f.write("No group posts found in the lookback window.\n")

print(f"Collected {len(all_posts)} group posts from {len(groups)} groups")
PYEOF
}

collect_incidents() {
    echo "$LOG_PREFIX  [3/3] Collecting incidents..."

    python3 - "$CONFIG" "$WORK_DIR" "$START_DATE" << 'PYEOF'
import json, sys, subprocess, os

config_path = sys.argv[1]
work_dir = sys.argv[2]
start_date = sys.argv[3]

with open(config_path) as f:
    config = json.load(f)

oncall_teams = config.get("oncall_teams", [])
all_incidents = []

for team in oncall_teams:
    # ──────────────────────────────────────────────────────────────
    # ADAPT: Replace with your incident management system.
    #
    # PagerDuty:
    #   curl "https://api.pagerduty.com/incidents?service_ids[]={service_id}&since={start_date}"
    #
    # OpsGenie:
    #   Use OpsGenie API to fetch alerts for your teams
    #
    # Meta SEV system:
    #   meta search.doc search -q "{team}" --doc-type=SEV ...
    # ──────────────────────────────────────────────────────────────

    incidents = []
    # REPLACE with your API call

    for inc in incidents:
        title = inc.get("title", "Untitled")
        url = inc.get("url", "")
        snippet = str(inc.get("snippet", ""))[:300]
        all_incidents.append(f"- {title}\n  URL: {url}\n  {snippet}")

output_path = os.path.join(work_dir, "incidents.txt")
with open(output_path, "w") as f:
    if all_incidents:
        f.write(f"Found {len(all_incidents)} incidents in the last 14 days:\n\n")
        f.write("\n".join(all_incidents))
    else:
        f.write("No incidents found for monitored oncall teams.\n")

print(f"Collected {len(all_incidents)} incidents for {len(oncall_teams)} teams")
PYEOF
}

# Run all collection in parallel
collect_peer_activity &
PID_PEERS=$!
collect_group_posts &
PID_GROUPS=$!
collect_incidents &
PID_INCIDENTS=$!

# Wait for all
wait $PID_PEERS || echo "$LOG_PREFIX  [WARN] Peer collection failed"
wait $PID_GROUPS || echo "$LOG_PREFIX  [WARN] Group post collection failed"
wait $PID_INCIDENTS || echo "$LOG_PREFIX  [WARN] Incident collection failed"

echo "$LOG_PREFIX  Data collection complete"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: CLAUDE SYNTHESIS
#
# This is the core — feeds raw data + template to Claude, gets structured output.
# No adaptation needed here unless you change the template structure.
# ═══════════════════════════════════════════════════════════════════════════════

echo "$LOG_PREFIX  Running Claude synthesis..."

YOUR_NAME=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('your_name', 'Engineer'))")
YOUR_ROLE=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('your_role', 'Engineer'))")
EXPERTISE=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(', '.join(c.get('expertise_domains', [])))")

# Build the synthesis prompt
PROMPT_FILE="$WORK_DIR/prompt.txt"
cat > "$PROMPT_FILE" << PROMPTEOF
You are an area intelligence analyst for $YOUR_NAME, a $YOUR_ROLE.

Your job: surface things $YOUR_NAME should know about but might miss. Focus on EM and TL activity, broader peer work, and opportunities where $YOUR_NAME could help or should be aware.

## Peer Activity (last $LOOKBACK days)
$(cat "$WORK_DIR/peer_activity.txt" 2>/dev/null || echo "No peer data available.")

## Group Posts
$(cat "$WORK_DIR/group_posts.txt" 2>/dev/null || echo "No group posts available.")

## Incident Activity
$(cat "$WORK_DIR/incidents.txt" 2>/dev/null || echo "No incident data available.")

## Expertise Domains
$EXPERTISE

## Peer Circles
People are organized into circles in the config:
- "management" = EM, TLs — your direct reporting chain
- "team" = immediate teammates
- "leadership" = skip manager and above (directors, VPs)
- "adjacent" = people in related teams you collaborate with
- "collaborator" = cross-team partners

## Output Template
Fill in the placeholders in this template. Output ONLY the filled template — no preamble, no wrapper.

$(cat "$TEMPLATE")

## Placeholder Instructions
Each {{PLACEHOLDER}} = markdown TABLE ROWS only (no header row — headers are in the template).

- **{{ORG_PULSE}}**: 2-3 rows. \`| [signal](URL) | how $YOUR_NAME can help |\`. ORG-LEVEL only — multi-team impact, leadership decisions. Individual tasks go in Team Activity.
- **{{OPPORTUNITIES}}**: \`| [description](URL) | benefit + action |\`. Action includes who to contact and what to say.
- **{{TEAM_ACTIVITY}}**: Merge management + team peers into ONE table. \`| [Person](URL) | activity + benefit | draft reach-out message |\`. Sort by importance. No activity: \`| Person | No visible activity. Monitor. | — |\`
- **{{LEADERSHIP_ACTIVITY}}**: One row per person. \`| [Person](URL) | activity + benefit | draft reach-out |\`. **NO reach-out for VP/Director level** — use \`—\` for their Reach Out column.
- **{{INCIDENT_RADAR}}**: \`| [Incident](URL) | status + relevance |\`. None: \`| No incidents. | — |\`

Rules:
- Compact. One sentence per cell. No filler.
- Links in first column.
- Follow the template columns exactly — do NOT add extra columns.
- Cap 5 rows per section. Replace {{DATE}} with $TODAY.
PROMPTEOF

# Run Claude synthesis (10 minute timeout)
ORG_MD_RAW="$WORK_DIR/org_raw.md"
ORG_MD="$WORK_DIR/org_clean.md"

timeout 600 claude -p "$(cat "$PROMPT_FILE")" \
    --allowedTools Read \
    --output-format text \
    > "$ORG_MD_RAW" 2>/dev/null || {
    echo "$LOG_PREFIX  [WARN] Claude synthesis failed or timed out"
}

# Clean output — strip preamble before first heading
if [ -f "$ORG_MD_RAW" ] && [ -s "$ORG_MD_RAW" ]; then
    python3 -c "
import re, sys
with open('$ORG_MD_RAW') as f:
    content = f.read()
match = re.search(r'^# ', content, re.MULTILINE)
if match:
    content = content[match.start():]
else:
    content = '# $TODAY — Area Monitor\n\nSynthesis did not produce valid output.\n'
with open('$ORG_MD', 'w') as f:
    f.write(content.strip() + '\n')
"
    echo "$LOG_PREFIX  Synthesis complete ($(wc -l < "$ORG_MD") lines)"
else
    printf "# %s — Area Monitor\n\nNo synthesis output produced.\n" "$TODAY" > "$ORG_MD"
    echo "$LOG_PREFIX  [WARN] Synthesis produced no output"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: OUTPUT
# ═══════════════════════════════════════════════════════════════════════════════

# Write to local cache
mkdir -p "$(dirname "$CACHE")"
cp "$ORG_MD" "$CACHE"
echo "$LOG_PREFIX  Cache written to $CACHE"

# Update last_scan in config
python3 -c "
import json
with open('$CONFIG') as f:
    config = json.load(f)
config['last_scan'] = '$TODAY'
with open('$CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
"

echo "$LOG_PREFIX === Area Monitor Done ==="
echo ""
echo "Output: $CACHE"
echo "To view: cat $CACHE"
