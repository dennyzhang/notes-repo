#!/usr/bin/env bash
# cron-area-monitor.sh — Nightly scan of broader area activity + AI skill techniques.
#
# Monitors EM/TL activity, broader peer diffs/posts, workplace groups,
# help requests, AND AI skill community sources. Synthesizes into daily digests.
#
# Output: Google Doc (two tabs: Org Monitor + AI Skill Monitor) + local caches at
#         context/cache/AREA-MONITOR.md and context/cache/UPSTREAM-TODAY.md
#
# Previously two scripts (cron-area-monitor.sh + cron-upstream-inside.sh),
# merged for parallel execution and shared Google Doc output.
#
# Runs daily at 3:00 AM via crontab. ~5-10 min typical runtime.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$HOME/work/claude"
CONFIG="$REPO_DIR/config/AREA-MONITOR.json"
SKILL_CONFIG="$REPO_DIR/context/SKILL-SCOUT.yaml"
CACHE="$REPO_DIR/context/cache/AREA-MONITOR.md"
SKILL_CACHE="$REPO_DIR/context/cache/UPSTREAM-TODAY.md"
SCOUT_DIGEST="$REPO_DIR/context/cache/CLAUDE-SKILL-SCOUT.md"
LOCK_FILE="/tmp/cron-area-monitor.lock"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M')"
TODAY=$(date '+%Y-%m-%d')
DOW=$(date +%u)  # 1=Mon .. 7=Sun

# Clear Claude Code session markers so nested claude -p works
unset CLAUDECODE CLAUDE_CODE_CURRENT_SESSION_ID 2>/dev/null || true

source "$SCRIPT_DIR/cron-alert.sh"
source "$SCRIPT_DIR/lib/gdocs_lib.sh"
source "$SCRIPT_DIR/fetch-cache.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/llm-dispatch.sh"

# Pre-check: workspace exists
if [ ! -f "$REPO_DIR/CLAUDE.md" ]; then
    cron_alert "area-monitor" "Workspace missing — ~/work/claude/CLAUDE.md missing"
    exit 1
fi

# Prevent overlapping runs
LOCK_MAX_AGE_SECONDS=7200
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "0") ))
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if [ "$lock_age" -gt "$LOCK_MAX_AGE_SECONDS" ]; then
            echo "$LOG_PREFIX Lock held by pid $pid for ${lock_age}s (>${LOCK_MAX_AGE_SECONDS}s) — killing stale process"
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
        else
            echo "$LOG_PREFIX Already running (pid $pid, age ${lock_age}s), skipping"
            exit 0
        fi
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

echo "$LOG_PREFIX === Area Monitor + AI Skill Scan ==="

# Health-gate google-mux before gdocs operations
if ! ensure_gmux_healthy; then
    echo "$LOG_PREFIX   WARNING: google-mux unhealthy — gdocs calls may fail"
fi

GDOC_ID=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['gdoc_id'])")

# Address open comments BEFORE adding the new day's content (operator rule 2026-06-14)
gdoc_address_comments_first "$GDOC_ID"

WORK_DIR=$(mktemp -d /tmp/area-monitor-XXXX)
trap 'rm -rf "$WORK_DIR"; rm -f "$LOCK_FILE"' EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 0: Tab-level description initialization (AREA RULE 16)
# Description lives at doc top once, shared across all days. Idempotent.
# ═══════════════════════════════════════════════════════════════════════════════

ORG_TAB_DESC='*Purpose*: Nightly scan of peer diffs, Workplace posts, and SEV feed to surface org-level signals and cross-team opportunities across MRS Training Infra. *Pipeline*: `cron-area-monitor.sh` @ 04:00 PT — parallel fetch (24 peers, 7d diffs + Workplace groups + SEV feed) → Claude synthesis → 3 tables + SEV radar. *Source*: `scripts/cron-area-monitor.sh`.'
SKILL_TAB_DESC='*Purpose*: Nightly scout for AI/Claude practice across Meta — validated practices, community trends, techniques, power users, fbcode templates — to feed my own AI toolkit and spot converging work. *Pipeline*: `cron-area-monitor.sh` @ 04:00 PT — parallel fetch (skill Workplace groups, 8 power users, fbcode claude-templates, AI-practice GChat spaces) → Claude synthesis → 5 tables. *Source*: `scripts/cron-area-monitor.sh`.'

init_tab_description() {
    local tab_id="$1"
    local tab_label="$2"
    local desc_text="$3"
    local marker="$4"

    echo "$LOG_PREFIX  [step-0] Checking $tab_label for description ($marker)..."
    local tab_text
    # NOTE: gdocs CLI is `gdocs get` not `gdocs content get` — the latter silently errors,
    # which used to fail the existence check and re-insert a Purpose paragraph every cron run
    # (accumulating one per day across the tab). Use `gdocs get` with --untrusted-authors-mode.
    tab_text=$(gdocs get "$GDOC_ID" --tab-id "$tab_id" --untrusted-authors-mode 2>/dev/null || echo "")

    local marker_count
    # Count only real body occurrences in <p> tags (not in comment data-quote metadata).
    marker_count=$(echo "$tab_text" | grep -cE "<p[^>]*>(<i>)?(<b>)?(<u>)?Purpose" || echo "0")

    if [ "${marker_count:-0}" -eq 1 ]; then
        echo "$LOG_PREFIX  [step-0] $tab_label description present (1) — skipping"
        return 0
    fi

    if [ "${marker_count:-0}" -gt 1 ]; then
        echo "$LOG_PREFIX  [step-0] WARNING: $tab_label has $marker_count Purpose paragraphs (expected 1) — manual cleanup needed"
        return 0
    fi

    echo "$LOG_PREFIX  [step-0] Inserting one-time description at top of $tab_label..."
    local desc_file="$WORK_DIR/desc_${tab_id//\./_}.md"
    printf '%s\n' "$desc_text" > "$desc_file"

    if gdocs content insert-markdown "$GDOC_ID" "@${desc_file}" --index 1 --tab-id "$tab_id" 2>&1; then
        echo "$LOG_PREFIX  [step-0] Description initialized for $tab_label"
    else
        echo "$LOG_PREFIX  [step-0] WARNING: Failed to insert description for $tab_label"
    fi
}

init_tab_description "t.7p1pm5er8oet" "Org Monitor" "$ORG_TAB_DESC" "Nightly scan"
init_tab_description "t.n3cgnazi5bxp" "AI Skill Monitor" "$SKILL_TAB_DESC" "Nightly scout"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 0.5: Departed-employee pre-flight (Denny review 2026-06-21)
# Run `meta people.profile get --unixname <u>` for each peer; skip rendering rows
# for anyone with status=former. Cache results in $WORK_DIR/departed-peers.json
# so STEP 1 / Claude synthesis can read it and filter. Cap at 1 lookup per peer per
# run (~24 calls × ~1s each = ~30s). On lookup failure, treat as ACTIVE (safe default).
# ═══════════════════════════════════════════════════════════════════════════════
DEPARTED_CACHE="$WORK_DIR/departed-peers.json"
echo "$LOG_PREFIX  [step-0.5] Pre-flight: checking peer employment status..."
python3 - "$CONFIG" "$DEPARTED_CACHE" "$LOG_PREFIX" <<'PYEOF'
import json, subprocess, sys
config_path, cache_path, log_prefix = sys.argv[1], sys.argv[2], sys.argv[3]
with open(config_path) as f:
    cfg = json.load(f)
departed, errors = [], []
for peer in cfg.get("peers", []):
    u = (peer.get("unixname") or "").strip()
    if not u:
        continue
    try:
        r = subprocess.run(
            ["meta", "people.profile", "get", "--unixname", u, "-o", "json"],
            capture_output=True, text=True, timeout=20,
        )
        if r.returncode != 0 or not r.stdout.strip():
            errors.append(u); continue
        prof = json.loads(r.stdout)
        if (prof.get("status") or "").lower() == "former":
            departed.append({"name": peer.get("name"), "unixname": u})
    except Exception:
        errors.append(u)
with open(cache_path, "w") as f:
    json.dump({"departed": departed, "lookup_errors": errors}, f, indent=2)
if departed:
    names = ", ".join(f"{d['name']} ({d['unixname']})" for d in departed)
    print(f"{log_prefix}  [step-0.5] DEPARTED detected ({len(departed)}): {names} — will be filtered from render")
else:
    print(f"{log_prefix}  [step-0.5] All peers active (errors: {len(errors)})")
PYEOF

# Append a warning to ALERTS.md once per departed peer per quarter so Denny can
# manually purge AREA-MONITOR.json (self-healing prompt, not a blocker).
DEPARTED_NAMES=$(python3 -c "import json; d=json.load(open('$DEPARTED_CACHE'))['departed']; print(','.join(p['name'] for p in d))" 2>/dev/null || echo "")
if [ -n "$DEPARTED_NAMES" ]; then
    ALERTS_FILE="$HOME/work/claude/ALERTS.md"
    QUARTER=$(date '+%Y-Q'$(( ($(date +%-m) - 1) / 3 + 1 )))
    SENTINEL="$WORK_DIR/.departed-alert-$QUARTER"
    if [ ! -f "$SENTINEL" ] && [ -w "$ALERTS_FILE" ]; then
        echo "- **$(date '+%Y-%m-%d %H:%M')** [area-monitor:departed-peers] AREA-MONITOR.json contains former employees: $DEPARTED_NAMES — remove from config to clean up render." >> "$ALERTS_FILE"
        touch "$SENTINEL"
        echo "$LOG_PREFIX  [step-0.5] Wrote departed-peers alert to ALERTS.md (quarter $QUARTER)"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Parallel data collection — org track + AI skill track
# ═══════════════════════════════════════════════════════════════════════════════

LOOKBACK=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('lookback_days', 7))")
START_DATE=$(date -d "-${LOOKBACK} days" '+%Y-%m-%dT00:00:00Z')

# --- Background Job A: Org Track (peer diffs, workplace groups, SEVs) ---
collect_org() {
    local job_log="$WORK_DIR/org_collect.log"

    # Section 1: Peer diffs
    echo "$LOG_PREFIX  [org 1/3] Fetching peer diffs and posts..." >> "$job_log"

    python3 - "$CONFIG" "$WORK_DIR" "$START_DATE" << 'PYEOF'
import json, sys, subprocess, os

config_path = sys.argv[1]
work_dir = sys.argv[2]
start_date = sys.argv[3]

with open(config_path) as f:
    config = json.load(f)

peers = config.get("peers", [])

# DEPARTED-EMPLOYEE FILTER (Denny review 2026-06-21): step-0.5 wrote
# departed-peers.json — drop any peer whose unixname is in that list so neither
# diffs nor posts get fetched/rendered for them.
departed_cache = os.path.join(work_dir, "departed-peers.json")
departed_unixnames = set()
if os.path.exists(departed_cache):
    try:
        with open(departed_cache) as f:
            departed_unixnames = {p.get("unixname", "") for p in json.load(f).get("departed", [])}
    except Exception:
        pass
if departed_unixnames:
    before = len(peers)
    peers = [p for p in peers if p.get("unixname") not in departed_unixnames]
    print(f"  [collect_org] filtered {before - len(peers)} departed peer(s) from active set", flush=True)

all_activity = []

# Enrich peers with people profile data if available
people_dir = os.path.join(os.path.expanduser("~"), "work/claude/context/people")
for peer in peers:
    profile_path = os.path.join(people_dir, peer.get("unixname", "").upper() + ".md")
    if os.path.exists(profile_path):
        peer["has_profile"] = True
    else:
        peer["has_profile"] = False

for peer in peers:
    name = peer["name"]
    fbid = peer["fbid"]
    circle = peer.get("circle", "unknown")
    role = peer.get("role", "")

    # Fetch diffs
    try:
        result = subprocess.run(
            ["meta", "search.doc", "search", "-q", " ",
             "--doc-type=DIFF", "--author", fbid,
             "--start-creation-time", start_date,
             "--limit", "15", "-o", "json"],
            capture_output=True, text=True, timeout=30
        )
        diffs = json.loads(result.stdout) if result.returncode == 0 else []
        if not isinstance(diffs, list):
            diffs = []
    except Exception:
        diffs = []

    # Fetch workplace posts
    try:
        result = subprocess.run(
            ["meta", "search.doc", "search", "-q", " ",
             "--doc-type=GROUP_POST", "--author", fbid,
             "--start-creation-time", start_date,
             "--limit", "10", "-o", "json"],
            capture_output=True, text=True, timeout=30
        )
        posts = json.loads(result.stdout) if result.returncode == 0 else []
        if not isinstance(posts, list):
            posts = []
    except Exception:
        posts = []

    entry = f"### {name} ({role}) [circle: {circle}]\n"
    entry += f"Diffs ({len(diffs)}):\n"
    for d in diffs[:10]:
        title = d.get("title", "Untitled")
        url = d.get("url", "")
        snippet = d.get("snippet", "")[:200]
        entry += f"  - {title} | {url} | {snippet}\n"

    entry += f"Posts ({len(posts)}):\n"
    for p in posts[:5]:
        title = p.get("title", "Untitled")
        url = p.get("url", "")
        snippet = p.get("snippet", p.get("body", ""))[:300]
        entry += f"  - {title} | {url} | {snippet}\n"

    all_activity.append(entry)

output_path = os.path.join(work_dir, "peer_activity.txt")
with open(output_path, "w") as f:
    f.write("\n".join(all_activity))

print(f"Fetched activity for {len(peers)} peers")
PYEOF

    echo "$LOG_PREFIX  [org] Peer activity fetched" >> "$job_log"

    # Section 2: Workplace group posts (broader monitoring)
    echo "$LOG_PREFIX  [org 2/3] Fetching workplace group posts..." >> "$job_log"

    GROUP_IDS=$(python3 -c "
import json, sys
c = json.load(open('$CONFIG'))
for g in c.get('workplace_groups', []):
    gid = g.get('id', '').strip()
    if gid:
        print(gid)
    else:
        print(f'  [WARN] No ID for group \"{g.get(\"name\", \"unknown\")}\" — skipping (discovery failed)', file=sys.stderr)
")

    GROUP_POSTS="$WORK_DIR/group_posts.txt"
    : > "$GROUP_POSTS"

    local group_post_count=0
    for gid in $GROUP_IDS; do
        result=$(meta search.doc search -q " " \
            --doc-type=GROUP_POST \
            --workplace-group="$gid" \
            --start-creation-time="$START_DATE" \
            --limit=15 \
            -o json 2>/dev/null || echo "[]")
        echo "$result" > "$WORK_DIR/group_${gid}.json"
        count=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)
        group_post_count=$((group_post_count + count))
    done

    # Combine group posts
    python3 - "$WORK_DIR" "$CONFIG" << 'PYEOF' > "$GROUP_POSTS"
import json, sys, os, glob

work_dir = sys.argv[1]
config_path = sys.argv[2]

with open(config_path) as f:
    config = json.load(f)

group_map = {g["id"]: g["name"] for g in config.get("workplace_groups", [])}
posts = []

for f_path in sorted(glob.glob(os.path.join(work_dir, "group_*.json"))):
    gid = os.path.basename(f_path).replace("group_", "").replace(".json", "")
    group_name = group_map.get(gid, gid)
    try:
        with open(f_path) as fh:
            data = json.load(fh)
        if isinstance(data, list):
            for item in data:
                if isinstance(item, dict):
                    title = item.get("title", "Untitled")
                    url = item.get("url", "")
                    snippet = item.get("snippet", item.get("body", ""))[:400]
                    author = item.get("author", item.get("owner", "Unknown"))
                    created = item.get("created_time", item.get("creation_time", ""))
                    posts.append(f"[{group_name}] {title}\nAuthor: {author} | Date: {created}\nURL: {url}\n{snippet}\n")
    except Exception:
        pass

if posts:
    print(f"Found {len(posts)} group posts:\n")
    print("\n---\n".join(posts))
else:
    print("No group posts found in the lookback window.")
PYEOF

    echo "$LOG_PREFIX  [org] Group posts fetched ($group_post_count total)" >> "$job_log"

    # Section 3: SEV activity for oncall teams
    echo "$LOG_PREFIX  [org 3/3] Fetching SEV activity..." >> "$job_log"

    ONCALL_TEAMS=$(python3 -c "
import json
c = json.load(open('$CONFIG'))
for t in c.get('oncall_teams', []):
    print(t)
")

    SEV_DATA="$WORK_DIR/sev_activity.txt"
    SEV_START=$(date -d "-14 days" '+%Y-%m-%dT00:00:00Z')

    sev_results=""
    for team in $ONCALL_TEAMS; do
        result=$(meta search.doc search -q "$team" \
            --doc-type=SEV \
            --start-creation-time="$SEV_START" \
            --limit=10 \
            -o json 2>/dev/null || echo "[]")
        if [ "$result" != "[]" ]; then
            sev_results="${sev_results}${result}"
        fi
    done

    python3 - "$WORK_DIR" << PYEOF > "$SEV_DATA"
import json, sys

work_dir = sys.argv[1]
raw = '''$sev_results'''

# Try to parse concatenated JSON arrays
sevs = []
try:
    cleaned = raw.replace("][", ",")
    if cleaned.strip():
        sevs = json.loads(cleaned)
except Exception:
    pass

if not isinstance(sevs, list):
    sevs = []

if sevs:
    print(f"Found {len(sevs)} SEVs in the last 14 days:\\n")
    for s in sevs[:15]:
        title = s.get("title", "Untitled")
        url = s.get("url", "")
        snippet = s.get("snippet", "")[:300]
        print(f"- {title}\\n  URL: {url}\\n  {snippet}\\n")
else:
    print("No SEVs found for monitored oncall teams in the last 14 days.")
PYEOF

    echo "$LOG_PREFIX  [org] SEV activity fetched" >> "$job_log"
    echo "$LOG_PREFIX  [org] Collection complete" >> "$job_log"
}

# --- Background Job B: AI Skill Track ---
collect_ai_skill() {
    local job_log="$WORK_DIR/skill_collect.log"

    echo "$LOG_PREFIX  [skill 1/3] Fetching skill group posts..." >> "$job_log"

    # Read AI skill config from AREA-MONITOR.json
    local skill_lookback
    skill_lookback=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('ai_skill',{}).get('lookback_days', 7))")
    local skill_start
    skill_start=$(date -d "-${skill_lookback} days" '+%Y-%m-%dT00:00:00Z')

    # Fetch posts from skill-related Workplace groups
    python3 - "$CONFIG" "$WORK_DIR" "$skill_start" << 'PYEOF'
import json, sys, subprocess, os

config_path = sys.argv[1]
work_dir = sys.argv[2]
start_date = sys.argv[3]

with open(config_path) as f:
    config = json.load(f)

ai_skill = config.get("ai_skill", {})
groups = ai_skill.get("workplace_groups", [])
keywords = ai_skill.get("keywords_en", [])
keyword_str = " ".join(keywords[:5])  # Use top keywords for search

all_posts = []

for group in groups:
    gid = group.get("id", "").strip()
    gname = group.get("name", "")
    priority = group.get("priority", "low")

    if not gid:
        print(f"Skipping group '{gname}' — no ID (discovery failed)")
        continue

    try:
        result = subprocess.run(
            ["meta", "search.doc", "search", "-q", keyword_str,
             "--doc-type=GROUP_POST",
             "--workplace-group", gid,
             "--start-creation-time", start_date,
             "--limit", "20", "-o", "json"],
            capture_output=True, text=True, timeout=30
        )
        posts = json.loads(result.stdout) if result.returncode == 0 else []
        if not isinstance(posts, list):
            posts = []
    except Exception:
        posts = []

    for p in posts:
        if isinstance(p, dict):
            p["_source_group"] = gname
            p["_priority"] = priority
            all_posts.append(p)

output_path = os.path.join(work_dir, "skill_group_posts.json")
with open(output_path, "w") as f:
    json.dump(all_posts, f, indent=2)

print(f"Fetched {len(all_posts)} skill group posts from {len(groups)} groups")
PYEOF

    echo "$LOG_PREFIX  [skill] Group posts fetched" >> "$job_log"

    # Fetch posts from power users
    echo "$LOG_PREFIX  [skill 2/3] Fetching power user posts..." >> "$job_log"

    python3 - "$CONFIG" "$WORK_DIR" "$skill_start" << 'PYEOF'
import json, sys, subprocess, os

config_path = sys.argv[1]
work_dir = sys.argv[2]
start_date = sys.argv[3]

with open(config_path) as f:
    config = json.load(f)

ai_skill = config.get("ai_skill", {})
power_users = ai_skill.get("power_users", [])

all_posts = []
for user in power_users:
    try:
        result = subprocess.run(
            ["meta", "search.doc", "search", "-q", "claude code",
             "--doc-type=GROUP_POST",
             "--start-creation-time", start_date,
             "--limit", "10", "-o", "json"],
            capture_output=True, text=True, timeout=30
        )
        posts = json.loads(result.stdout) if result.returncode == 0 else []
        if not isinstance(posts, list):
            posts = []
    except Exception:
        posts = []

    for p in posts:
        if isinstance(p, dict):
            # Check if post author matches the power user
            author = str(p.get("author", p.get("owner", ""))).lower()
            if user.lower() in author:
                p["_source"] = f"power_user:{user}"
                all_posts.append(p)

output_path = os.path.join(work_dir, "skill_power_user_posts.json")
with open(output_path, "w") as f:
    json.dump(all_posts, f, indent=2)

print(f"Found {len(all_posts)} posts from {len(power_users)} power users")
PYEOF

    echo "$LOG_PREFIX  [skill] Power user posts fetched" >> "$job_log"

    # Check fbcode templates for new/modified skills
    echo "$LOG_PREFIX  [skill 3/3] Checking fbcode templates..." >> "$job_log"

    local templates_data="$WORK_DIR/skill_templates.txt"
    if [ -d "$HOME/fbsource/fbcode/claude-templates" ]; then
        find "$HOME/fbsource/fbcode/claude-templates" \
            -name '*.md' -o -name '*.yaml' -o -name '*.json' \
            -newer "$WORK_DIR" -mtime "-${skill_lookback}" \
            2>/dev/null | head -50 > "$templates_data" || true
        local template_count
        template_count=$(wc -l < "$templates_data" 2>/dev/null || echo 0)
        echo "$LOG_PREFIX  [skill] Found $template_count recently modified templates" >> "$job_log"
    else
        echo "fbsource mount not available — skipping template scan" > "$templates_data"
        echo "$LOG_PREFIX  [skill] fbsource not mounted, skipping templates" >> "$job_log"
    fi

    # Section 4: AI practice GChat spaces
    echo "$LOG_PREFIX  [skill 4/4] Scanning AI practice GChat spaces..." >> "$job_log"

    local gchat_data="$WORK_DIR/ai_practice_gchat.txt"
    python3 - "$CONFIG" "$WORK_DIR" << 'PYEOF_GCHAT'
import json, sys, subprocess, os
from datetime import datetime, timedelta

config_path = sys.argv[1]
work_dir = sys.argv[2]

with open(config_path) as f:
    config = json.load(f)

spaces = config.get("ai_practice_gchat_spaces", [])
lookback_days = config.get("ai_skill", {}).get("lookback_days", 7)
cutoff = datetime.utcnow() - timedelta(days=lookback_days)
output_lines = []

for space in spaces:
    sid = space.get("id", "").strip()
    sname = space.get("name", sid)
    if not sid:
        continue

    # Fetch recent messages using google-mux user-auth API
    try:
        result = subprocess.run(
            ["bash", "-c",
             f'echo "" | google-mux api call GET '
             f'"https://chat.googleapis.com/v1/spaces/{sid}/messages?pageSize=25&orderBy=createTime%20desc" '
             f'--token-class GoogleChatAuthTokenAsUser --json'],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            output_lines.append(f"### {sname} ({sid})\nFailed to fetch messages: {result.stderr[:200]}\n")
            continue

        data = json.loads(result.stdout)
        messages = data.get("data", {}).get("messages", [])
    except Exception as e:
        output_lines.append(f"### {sname} ({sid})\nError: {e}\n")
        continue

    # Filter to messages within lookback window
    recent = []
    for msg in messages:
        ct = msg.get("createTime", "")
        try:
            msg_time = datetime.fromisoformat(ct.replace("Z", "+00:00")).replace(tzinfo=None)
            if msg_time >= cutoff:
                recent.append(msg)
        except Exception:
            recent.append(msg)

    entry = f"### {sname} ({sid}) — {len(recent)} recent messages\n"
    for msg in recent[:15]:
        text = (msg.get("text") or "")[:400]
        sender = msg.get("sender", {}).get("name", "unknown")
        created = msg.get("createTime", "")
        entry += f"  [{created}] {sender}: {text}\n"

    if not recent:
        entry += "  No messages in the lookback window.\n"

    output_lines.append(entry)

output_path = os.path.join(work_dir, "ai_practice_gchat.txt")
with open(output_path, "w") as f:
    f.write("\n".join(output_lines))

print(f"Scanned {len(spaces)} AI practice GChat spaces, found {sum(1 for l in output_lines if 'recent messages' in l)} with activity")
PYEOF_GCHAT

    echo "$LOG_PREFIX  [skill] AI practice GChat spaces scanned" >> "$job_log"

    # Combine all skill data into a single readable file for Claude synthesis
    local combined="$WORK_DIR/skill_raw_data.txt"
    {
        echo "=== AI Skill Group Posts ==="
        python3 -c "
import json
try:
    with open('$WORK_DIR/skill_group_posts.json') as f:
        posts = json.load(f)
    for p in posts:
        group = p.get('_source_group', 'Unknown')
        title = p.get('title', 'Untitled')
        url = p.get('url', '')
        snippet = p.get('snippet', p.get('body', ''))[:400]
        author = p.get('author', p.get('owner', 'Unknown'))
        created = p.get('created_time', p.get('creation_time', ''))
        print(f'[{group}] {title}')
        print(f'Author: {author} | Date: {created}')
        print(f'URL: {url}')
        print(f'{snippet}')
        print('---')
except Exception:
    print('No group posts available.')
"
        echo ""
        echo "=== Power User Posts ==="
        python3 -c "
import json
try:
    with open('$WORK_DIR/skill_power_user_posts.json') as f:
        posts = json.load(f)
    for p in posts:
        source = p.get('_source', 'unknown')
        title = p.get('title', 'Untitled')
        url = p.get('url', '')
        snippet = p.get('snippet', p.get('body', ''))[:400]
        print(f'[{source}] {title}')
        print(f'URL: {url}')
        print(f'{snippet}')
        print('---')
except Exception:
    print('No power user posts available.')
"
        echo ""
        echo "=== fbcode Template Changes ==="
        cat "$templates_data"
        echo ""
        echo "=== AI Practice GChat Spaces ==="
        cat "$WORK_DIR/ai_practice_gchat.txt" 2>/dev/null || echo "No AI practice GChat data available."
        echo ""
        echo "=== Notes Repo Power User CLAUDE.md Files ==="
        # Scan power users' CLAUDE.md files from the shared notes repo
        if [ -d "$HOME/notes/users" ]; then
            python3 - "$SKILL_CONFIG" << 'PYEOF_NOTES'
import os, sys, re

config_path = sys.argv[1]
with open(config_path) as f:
    content = f.read()

# Parse power_users from notes_scan section (simple regex, no pyyaml needed)
in_notes_scan = False
power_users = []
keywords = []
exclude = []
for line in content.split('\n'):
    s = line.strip()
    if 'notes_scan:' in line and not s.startswith('#'):
        in_notes_scan = True
        continue
    if in_notes_scan:
        if re.match(r'^[a-z_]+:', line) and not line.startswith(' '):
            break  # Left notes_scan section
        if '  power_users:' in line:
            section = 'pu'
            continue
        if '  keywords:' in line:
            section = 'kw'
            continue
        if '  exclude_users:' in line:
            section = 'ex'
            continue
        if s.startswith('- "') or s.startswith("- '"):
            val = s.split('"')[1] if '"' in s else s.split("'")[1]
            if section == 'pu': power_users.append(val)
            elif section == 'kw': keywords.append(val)
            elif section == 'ex': exclude.append(val)

notes_dir = os.path.expanduser("~/notes/users")
found = 0

for user in power_users:
    if user in exclude:
        continue
    for path in [os.path.join(notes_dir, user, "CLAUDE.md"),
                 os.path.join(notes_dir, user, "claude", "CLAUDE.md")]:
        if os.path.exists(path):
            with open(path) as f:
                ct = f.read()
            size = len(ct)
            hits = [kw for kw in keywords if kw.lower() in ct.lower()]
            if hits or size > 3000:
                print(f"### {user} ({size}B, {len(hits)} keyword hits: {', '.join(hits[:5])})")
                preview = ct[:500].replace('\n', '\n> ')
                print(f"> {preview}")
                print("---")
                found += 1
            break

# Discovery: large CLAUDE.md from non-tracked users
all_new = []
for entry in os.listdir(notes_dir):
    if entry in exclude or entry in power_users:
        continue
    for subpath in [os.path.join(notes_dir, entry, "CLAUDE.md"),
                    os.path.join(notes_dir, entry, "claude", "CLAUDE.md")]:
        if os.path.exists(subpath):
            size = os.path.getsize(subpath)
            if size > 5000:
                all_new.append((entry, size))
            break

all_new.sort(key=lambda x: x[1], reverse=True)
if all_new:
    print(f"\n### Discovery: {len(all_new)} non-tracked users with large CLAUDE.md (>5KB)")
    for user, size in all_new[:10]:
        print(f"  - {user}: {size}B")

print(f"\nTotal power user files scanned: {found}")
PYEOF_NOTES
        else
            echo "Notes repo not mounted at ~/notes/users — run: sl clone mononoke://mononoke.internmc.facebook.com/notes ~/notes"
        fi
    } > "$combined"

    echo "$LOG_PREFIX  [skill] Collection complete" >> "$job_log"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 0: Auto-discover missing Workplace group IDs
# ═══════════════════════════════════════════════════════════════════════════════
echo "$LOG_PREFIX  Auto-discovering missing group IDs..."

python3 - "$CONFIG" << 'PYEOF_DISCOVER'
import json, sys, subprocess

config_path = sys.argv[1]
with open(config_path) as f:
    config = json.load(f)

changed = False

# Check both workplace_groups and ai_skill.workplace_groups
group_lists = [
    ("workplace_groups", config.get("workplace_groups", [])),
    ("ai_skill.workplace_groups", config.get("ai_skill", {}).get("workplace_groups", [])),
]

for list_name, groups in group_lists:
    for group in groups:
        gid = group.get("id", "").strip()
        gname = group.get("name", "").strip()
        if gid or not gname:
            continue  # Already has ID or no name to search

        print(f"  Discovering ID for '{gname}' ({list_name})...")
        try:
            result = subprocess.run(
                ["meta", "workplace.group", "search",
                 "--query", gname, "-o", "json", "--limit", "5"],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode != 0:
                print(f"    Search failed (exit={result.returncode}): {result.stderr[:200]}")
                continue

            candidates = json.loads(result.stdout)
            if not isinstance(candidates, list) or not candidates:
                print(f"    No results found for '{gname}' — content unavailable")
                continue

            # Exact name match preferred, then first result
            best = None
            for c in candidates:
                if c.get("name", "").lower() == gname.lower():
                    best = c
                    break
            if not best:
                best = candidates[0]

            discovered_id = str(best.get("id", ""))
            discovered_name = best.get("name", "")
            if discovered_id:
                group["id"] = discovered_id
                changed = True
                print(f"    Found: '{discovered_name}' (id={discovered_id})")
            else:
                print(f"    No ID in search result for '{gname}' — content unavailable")
        except subprocess.TimeoutExpired:
            print(f"    Discovery timed out for '{gname}'")
        except json.JSONDecodeError:
            print(f"    Could not parse search results for '{gname}'")
        except Exception as e:
            print(f"    Discovery failed for '{gname}': {e}")

if changed:
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=4)
    print("  Config updated with discovered group IDs")
else:
    print("  No groups needed discovery")
PYEOF_DISCOVER

# Launch both collection jobs in parallel
echo "$LOG_PREFIX  Starting parallel data collection..."
collect_org &
ORG_PID=$!
collect_ai_skill &
SKILL_PID=$!

# Wait for both to finish
org_exit=0
skill_exit=0
wait $ORG_PID || org_exit=$?
wait $SKILL_PID || skill_exit=$?

echo "$LOG_PREFIX  Collection done (org=$org_exit, skill=$skill_exit)"

if [ "$org_exit" -ne 0 ]; then
    echo "$LOG_PREFIX  [WARN] Org collection failed (exit=$org_exit)"
fi
if [ "$skill_exit" -ne 0 ]; then
    echo "$LOG_PREFIX  [WARN] Skill collection failed (exit=$skill_exit)"
fi

# Print collection logs
cat "$WORK_DIR/org_collect.log" 2>/dev/null || true
cat "$WORK_DIR/skill_collect.log" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Parallel Claude synthesis — org digest + AI skill digest
# ═══════════════════════════════════════════════════════════════════════════════

# --- Read context files for org synthesis ---
STRATEGY_SNIPPET=$(head -70 "$REPO_DIR/context/STRATEGY.md" 2>/dev/null || echo "No strategy file")
EXPERTISE_DOMAINS=$(python3 -c "
import json
c = json.load(open('$CONFIG'))
print(', '.join(c.get('expertise_domains', [])))
")
TEMPLATE="$REPO_DIR/workflows/templates/AREA-MONITOR-TEMPLATE.md"
SKILL_TEMPLATE="$REPO_DIR/workflows/templates/AI-SKILL-TEMPLATE.md"

# --- Org synthesis prompt ---
ORG_PROMPT_FILE="$WORK_DIR/org_prompt.txt"
cat > "$ORG_PROMPT_FILE" << PROMPTEOF
You are an area intelligence analyst for Denny Zhang, a TL on MRS Training Infra Reliability at Meta.

Your job: surface things Denny should know about but might miss. Focus on EM and TL activity, broader peer work, and opportunities where Denny could help or should be aware.

## Peer Activity (last $LOOKBACK days)
$(cat "$WORK_DIR/peer_activity.txt" 2>/dev/null || echo "No peer data available.")

## Workplace Group Posts
$(cat "$WORK_DIR/group_posts.txt" 2>/dev/null || echo "No group posts available.")

## SEV Activity (last 14 days)
$(cat "$WORK_DIR/sev_activity.txt" 2>/dev/null || echo "No SEV data available.")

## Denny's Expertise Domains
$EXPERTISE_DOMAINS

## Denny's Strategy Context
$STRATEGY_SNIPPET

## Peer Circles
People are organized into circles in the config:
- "management" = Denny's EM (Shumin), TLs (Catalin, Nick) — report to same EM
- "team" = immediate teammates under same EM (Harry, Akshay, Gaurav)
- "leadership" = skip manager and above (Nan Gao, Pete Kocks, Syamla, Santosh)
- "adjacent" = people in related teams (Rui Jian in AI4P)
- "collaborator" = cross-team collaborators (Shuguang in SilverTorch)

**ALL circles go into ONE {{TEAM_ACTIVITY}} table**, sorted by importance. There is NO separate skip manager section.

## Departed Employees (DO NOT render — added 2026-06-21)
The following peers have status=former in Workday and MUST be omitted from {{TEAM_ACTIVITY}} entirely (no row, not even in "Others"). Treat them as if they did not exist in the peer list:
$(python3 -c "import json,os; p=os.path.join('$WORK_DIR','departed-peers.json'); d=json.load(open(p)).get('departed',[]) if os.path.exists(p) else []; print('\n'.join(f\"- {x['name']} ({x['unixname']})\" for x in d) if d else '- (none — all peers active this run)')" 2>/dev/null)

## Yesterday's Report (for deduplication)
$(cat "$CACHE" 2>/dev/null | head -80 || echo "No prior report available.")

## Output Template
Fill in the placeholders in this fixed template. Output ONLY the filled template — no wrapper tags, no preamble.

$(cat "$TEMPLATE")

## Placeholder Instructions
Each {{PLACEHOLDER}} = markdown TABLE ROWS only (no header). Links IN first column. Keep cells compact.

- **{{KEY_MESSAGE_LINE}}**: ONE sentence ≤200 chars — the single most-leverage org/peer signal Denny needs to act on today, picked from the data below. Name the person/team + the concrete next step (verb-first). NO bullet, NO label, NO link markdown brackets visible — just the sentence. Daily brief reads this verbatim. Examples: "Reply to Paul Lu on SEV S646785 thread — he's blocked on TMS state matrix question (Workplace MRS OT Users)." or "Catch Catalin in #mrs-ot-reliability today re: D107879131 — his magic-number cleanup pattern overlaps your TBE work."
- **{{ORG_PULSE}}**: 2-3 rows. **3 COLUMNS:** \`| [signal description](source_URL) | Summary: Problem → what's wrong; Outcome → what happened/result; Solution → how it was resolved or what's needed | how Denny can help |\`. **Signal MUST be a clickable hyperlink** to the source post, diff, SEV, or workplace thread. Items without links are not actionable — omit them. The Summary column MUST use the structured format: "Problem: [1 sentence]. Outcome: [1 sentence]. Solution: [1 sentence]." — not a free-form paragraph. This lets Denny pre-read the post in 5 seconds without opening it. **ORG-LEVEL BAR**: Only include signals with multi-team or org-wide impact — leadership decisions, cross-team initiatives, strategic direction changes, org-wide wins. Individual IC task completions (shipping a CLI, fixing a bug, closing a task) belong in People & Opportunities, NOT here. Ask: "Would a director care about this?" If no, move it to People & Opportunities. **WORKPLACE GROUP COVERAGE**: ALL configured workplace groups that have posts MUST have at least one signal represented in Org Pulse or People & Opportunities. Do NOT silently drop an entire group's posts — if MVAI FYI has posts, at least one must appear.
- **{{TEAM_ACTIVITY}}**: People-oriented table — ONE row per peer (or "Others (low activity)" catch-all at bottom). **3 COLUMNS:** \`| [Person](URL) | activity + benefit (one sentence) | opportunity: concrete action incl. who to contact and what to say (one sentence) |\`. **DIFF LINK FORMAT (MANDATORY):** Every diff reference MUST be a markdown link: \`[D12345678](https://www.internalfb.com/diff/D12345678)\`. Plain text like "D100220762" without a link is a formatting violation — wrap EVERY D-number. Sort by importance (most active/relevant first). No activity: \`| Person | No visible activity. Monitor. | — |\`. The Opportunity column is the merged "cross-team opportunity / how to act" — name a specific next step (ping in #channel, DM about X, review their D-number) or \`—\` if none. **HARD RULE: NO reach-out suggestions for VP/Director level (Nan, Pete, Syamla, Santosh).** VPs will NOT engage with IC-level tactical details — Opportunity column is \`—\` for them. **P0 priority peers (Paul Lu, Li Lu) must always appear first in the table if they have any activity.** **FORCE-SEPARATE ROWS (always their own row, never bundled into a catch-all even with thin activity)**: Shumin Wu (EM), Catalin Toda (TL), Nick Pallanez (TL), Shuguang Ye (SilverTorch EM). These four must each get their own row in every run. **NO COMMA-JOINED NAMES IN THE PERSON COLUMN — EVER.** The Person column contains exactly ONE name (or a single bracketed-link). Strings like "Gaurav Mitra, Trevor Mathisen, Shuguang Ye, Catalin Toda" or "all leadership" or "Shumin and Catalin" are FORMAT VIOLATIONS — split into N rows, one per person. The "Others (low activity)" catch-all is the ONLY exception, and it MUST exclude every person already named in {{TEAM_ACTIVITY}} above and the FORCE-SEPARATE list. **DEPARTED-EMPLOYEE EXCLUSION**: never render a row for anyone listed in the "Departed Employees" section above — not in their own row, not in "Others", not anywhere.
- **{{SEV_RADAR}}**: **CONDITIONAL.** If there are active SEVs for \`pe_mrs_ml\` or \`mrs_online_training\`, output: \`## 4. SEV Radar\n\n| SEV | Status & My Benefit |\n|-----|-------------------|\n| [SEV](URL) | status + benefit |\`. If there are NO active SEVs, replace {{SEV_RADAR}} with an empty string — do NOT output the section header or "Nothing notable."

Rules:
- **Compact.** One sentence per cell. No filler.
- **Links in first column. ALL diff IDs must be clickable links — [D12345678](https://www.internalfb.com/diff/D12345678).**
- **STRICTLY follow the template columns.** Org Pulse = 3 columns. People & Opportunities = 3 columns (Person | Activity | Opportunity). No exceptions.
- **No boilerplate.** The \`> Source:\` lines are part of the template structure — keep them exactly as-is in the output. Do NOT add extra Source lines, but do NOT remove the ones in the template either. Keep the content lean.
- Cap 5 rows per section. Replace {{DATE}} with $TODAY.
- **DEDUPLICATION — CRITICAL:**
  1. Read "Yesterday's Report" above. Do NOT repeat signals that appeared yesterday unless there is a meaningful UPDATE (new status, new data, escalation). "Syamla posted about overdue tasks" appearing 5 days in a row is a failure. If the signal is the same, skip it.
  2. For Team Activity: only report NEW diffs/posts since the last scan. If Harry had 8 diffs yesterday and still has 8 diffs today (no new ones), write "No new activity." Do NOT re-report the same diffs.
- **CRITICAL STRUCTURE RULES — VIOLATING ANY OF THESE MAKES THE OUTPUT UNUSABLE:**
  1. The output MUST have EXACTLY 2 sections (Org Pulse, People & Opportunities) PLUS optional SEV Radar. NO section 4. NO "Skip Manager" section. NO "Leadership" section. NO separate "Opportunities to Act" section — the opportunity now lives as a column inside People & Opportunities.
  2. Column counts are FIXED: Org Pulse = 3 columns (Signal | Summary | How I Can Help), People & Opportunities = 3 columns (Person | Activity & My Benefit | Opportunity). Do NOT add or remove columns from any table.
  3. People & Opportunities MUST include ALL people — managers, teammates, leadership, adjacent, collaborators — in ONE table. Do NOT split by circle.
PROMPTEOF

# --- Pre-render §5 (My Validated AI Practices) from config ---
# AREA RULE 10: rolling 14-day window — only show entries with first_applied >= 14 days ago
python3 - "$CONFIG" > "$WORK_DIR/skill_practices_rows.txt" << 'PYEOF_PRACTICES'
import json, sys
from datetime import datetime, timedelta

with open(sys.argv[1]) as f:
    config = json.load(f)
practices = config.get("ai_practices", [])
cutoff = (datetime.now() - timedelta(days=14)).strftime("%Y-%m-%d")
filtered = [p for p in practices if p.get("first_applied", "9999-99-99") >= cutoff]
if filtered:
    for p in filtered:
        name = p.get("name", "Unknown")
        desc = p.get("description", "")
        first = p.get("first_applied", "—")
        print(f"| **{name}** | {desc} | {first} |")
else:
    print("| — | No practices in the last 14 days | — |")
PYEOF_PRACTICES

# --- Pre-render §6 (Auto-discover power users) from group posts ---
python3 - "$CONFIG" "$WORK_DIR/skill_group_posts.json" > "$WORK_DIR/skill_autodiscover_rows.txt" << 'PYEOF_AUTODISCOVER'
import json, sys, collections
with open(sys.argv[1]) as f:
    config = json.load(f)
try:
    with open(sys.argv[2]) as f:
        posts = json.load(f)
except Exception:
    posts = []

power_users = set(config.get("ai_skill", {}).get("power_users", []))

author_counts = collections.Counter()
author_posts = collections.defaultdict(list)
for p in posts:
    # Try to extract username from author field
    raw = str(p.get("author", p.get("owner", p.get("unixname", "")))).strip()
    # Take the last token if it looks like a unixname (no spaces, lowercase)
    parts = raw.split()
    for part in parts:
        if part and part.islower() and len(part) >= 3 and part not in power_users:
            author_counts[part] += 1
            url = p.get("url", "")
            if url:
                author_posts[part].append(url)
            break

top = [(u, c) for u, c in author_counts.most_common(8) if c >= 2]
if top:
    for author, count in top:
        profile_url = f"https://www.internalfb.com/profile/view/{author}"
        print(f"| [{author}]({profile_url}) | {count} posts in AI skill groups | Yes — add to `ai_skill.power_users` |")
else:
    print("| — | No new candidates with 2+ posts this week | — |")
PYEOF_AUTODISCOVER

# --- Pre-render template with §5 and §6 substituted ---
python3 - "$SKILL_TEMPLATE" "$WORK_DIR/skill_practices_rows.txt" "$WORK_DIR/skill_autodiscover_rows.txt" > "$WORK_DIR/skill_template_rendered.txt" << 'PYEOF_RENDER'
import sys
with open(sys.argv[1]) as f:
    template = f.read()
with open(sys.argv[2]) as f:
    practices = f.read().strip()
with open(sys.argv[3]) as f:
    autodiscover = f.read().strip()
rendered = template.replace("{{MY_PRACTICES}}", practices).replace("{{AUTO_DISCOVER}}", autodiscover)
print(rendered)
PYEOF_RENDER

# --- AI skill synthesis prompt ---
SKILL_PROMPT_FILE="$WORK_DIR/skill_prompt.txt"
cat > "$SKILL_PROMPT_FILE" << SKILLPROMPTEOF
You are an AI skill scout for Denny Zhang, a TL on MRS Training Infra Reliability at Meta.

Your job: find new Claude Code skills, techniques, hooks, plugins, and automation patterns from the Meta community that Denny could adopt.

## Source Data
$(cat "$WORK_DIR/skill_raw_data.txt" 2>/dev/null || echo "No skill data available.")

## Existing Skill Scout Digest (for deduplication)
$(head -100 "$SCOUT_DIGEST" 2>/dev/null || echo "No existing digest.")

## Output Template
Fill in the placeholders in this fixed template. Output ONLY the filled template — no wrapper tags, no preamble.
**Sections 5 (My Validated AI Practices) and 6 (Power User Discovery) are PRE-RENDERED — pass them through EXACTLY as written.**

$(cat "$WORK_DIR/skill_template_rendered.txt" 2>/dev/null || cat "$SKILL_TEMPLATE")

## Placeholder Instructions
Each {{PLACEHOLDER}} = markdown TABLE ROWS only (no header). Links IN first column.

**IMPORTANT: My Validated AI Practices is FIRST in the template (§1). Output sections in template order.**

- **{{KEY_MESSAGE_LINE}}**: ONE sentence ≤200 chars — the single highest-priority AI technique, post, or skill Denny should adopt or read today, picked from the data below. Name the technique + the concrete action (verb-first). NO bullet, NO label, NO link markdown brackets visible — just the sentence. Daily brief reads this verbatim. Examples: "Adopt simonmar's `/loop` skill — replaces 3 of your cron-poll bash loops with one declarative command (workplace post, Jun 17)." or "Read travisbarton's CCSDK agent post — directly maps to the master-agent pattern you're building for OT."
- **§1 (My Validated AI Practices)**: PRE-RENDERED from config — do NOT modify. Pass through exactly as it appears in the template.
- **{{COMMUNITY_PULSE}}**: \`| [Trend](source_URL) | how it works (mechanism) | what's changing |\`. **3 columns.** Trend MUST be a clickable [link](URL) to the source post, diff, or thread. "How It Works" explains the mechanism briefly.
- **{{TECHNIQUES}}**: Merged list of all techniques + adoption candidates, sorted by relevance score desc. \`| [Name by Author](URL) | how it works + how it helps Denny (one sentence) | **Priority** |\`. Priority column values: score +3 (SEV/OT/training) → \`**High**\`; score +2 (daily ops) → \`**Medium**\`; score +1 (team/skill) → \`**Low**\`. Only items with score >= 1. **Every technique name MUST be a clickable [link](URL) to the source post.** If no URL exists, omit the item. NEVER output literal "pending" — it's dead weight that never changes.
- **{{POWER_USER_ACTIVITY}}**: \`| [User](profile_URL) | what they shared + how it helps Denny |\`. **2 columns — NO reach-out column.** If NO tracked power users posted during the scan window, render EXACTLY ONE fallback row: \`| **No tracked power user posts** | See §5 Power User Discovery for new candidates, or broaden config/AREA-MONITOR.json → ai_skill.power_users. |\`. Never emit row with fragment "had no new posts..." in column 2.
- **{{NOTES_USER_ACTIVITY}}**: Power users whose CLAUDE.md files in the shared notes repo have been recently updated. \`| [User](notes_repo_URL) | what changed in their Claude setup | cherry-pick candidate (yes/no + what to adopt) |\`. If notes_scan is disabled or no data available, write \`| Notes scan disabled. | Enable in context/SKILL-SCOUT.yaml → notes_scan.enabled | — |\`.
- **§5 (Power User Discovery)**: Pass through exactly as it appears in the template.

Rules:
- **Compact.** One sentence per cell. Merge related info into fewer columns.
- **Links in first column.**
- **Bold first column.** Every data row's first cell must be bolded: \`| [**Name**](URL) |\` for links, or \`| **Plain text** |\` without links. Scannability rule.
- **STRICTLY follow the template columns.** Do NOT add extra columns. Match the template exactly.
- **No boilerplate.** Do NOT output Purpose paragraphs, Source attribution lines (e.g. "Source: config/..."), metadata blocks, or "Monitored power users:" prefix text. The template is lean — keep it lean.
- Deduplicate against existing skill scout digest.
- Cap 7 rows for Techniques, 5 for others. Replace {{DATE}} with $TODAY.
SKILLPROMPTEOF

echo "$LOG_PREFIX  Running parallel Claude synthesis..."

# Launch both synthesis calls in parallel
ORG_MD_RAW="$WORK_DIR/org_raw.md"
SKILL_MD_RAW="$WORK_DIR/skill_raw.md"

run_llm "area-monitor-org" 900 "$ORG_MD_RAW" "$(cat "$ORG_PROMPT_FILE")" -- --allowedTools Read --output-format text --model claude-sonnet-4-6 &
ORG_SYNTH_PID=$!

run_llm "area-monitor-skill" 900 "$SKILL_MD_RAW" "$(cat "$SKILL_PROMPT_FILE")" -- --allowedTools Read --output-format text --model claude-sonnet-4-6 &
SKILL_SYNTH_PID=$!

# Wait for both
org_synth_exit=0
skill_synth_exit=0
wait $ORG_SYNTH_PID || org_synth_exit=$?
wait $SKILL_SYNTH_PID || skill_synth_exit=$?

echo "$LOG_PREFIX  Synthesis done (org=$org_synth_exit, skill=$skill_synth_exit)"

# --- Step 2.4: Peer profile drift check (Mondays only) ---
# Calls `meta workplace.user lookup` on each peer's unixname. If status != "Current"
# (departed, role changed, etc.), append to PEER-STATUS-DRIFT.md and raise a cron_alert
# so Denny can review and prune config/AREA-MONITOR.json. Does NOT auto-remove — Workplace
# lookups can lag actual departures, so the human confirms.
if [ "$DOW" -eq 1 ]; then
    echo "$LOG_PREFIX  Peer profile drift check (weekly)"
    DRIFT_FILE="$REPO_DIR/context/cache/PEER-STATUS-DRIFT.md"
    drift_lines=""

    while read -r unixname name; do
        [ -z "$unixname" ] && continue
        status=$(meta workplace.user lookup -u "$unixname" -o json 2>/dev/null \
            | python3 -c "import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get('status','UNKNOWN'))
except Exception:
    print('LOOKUP_FAILED')" </dev/null)
        if [ "$status" != "Current" ] && [ "$status" != "LOOKUP_FAILED" ]; then
            drift_lines="${drift_lines}- ${name} (\`${unixname}\`): status=${status} — consider removing from config/AREA-MONITOR.json"$'\n'
        fi
    done < <(python3 -c "
import json
c = json.load(open('$CONFIG'))
for p in c.get('peers', []):
    u = p.get('unixname','').strip()
    n = p.get('name','?')
    if u:
        print(f'{u} {n}')
")

    if [ -n "$drift_lines" ]; then
        {
            echo "# Peer Status Drift — $TODAY"
            echo ""
            echo "Peers whose Workplace status is no longer 'Current'. Review and prune \`config/AREA-MONITOR.json\` if confirmed."
            echo ""
            echo "$drift_lines"
        } > "$DRIFT_FILE"
        cron_alert "area-monitor" "$(echo "$drift_lines" | wc -l) peer(s) no longer 'Current' — see context/cache/PEER-STATUS-DRIFT.md"
    else
        # Clean state — write a stamp so we know the check ran
        echo "# Peer Status Drift — $TODAY"$'\n\nAll peers still show status=Current.' > "$DRIFT_FILE"
    fi
fi

# --- Step 2.5: Cheatsheet drift check (Mondays only) ---
if [ "$DOW" -eq 1 ]; then
    echo "$LOG_PREFIX  Cheatsheet drift check (weekly)"
    DRIFT_REPORT="$REPO_DIR/context/cache/CHEATSHEET-DRIFT.md"

    cheatsheet_manifest=""
    for cs in "$REPO_DIR"/cheatsheets/cheatsheet-*.md; do
        [ -f "$cs" ] || continue
        name=$(basename "$cs" .md | sed 's/^cheatsheet-//')
        desc=$(head -3 "$cs" | grep -v '^#' | grep -v '^$' | head -1 | cut -c1-120)
        cheatsheet_manifest="$cheatsheet_manifest
$name: $desc"
    done

    drift_exit=0
    run_llm "area-monitor-drift" 600 /dev/stdout "You are running as a cron job. Compare Denny's local cheatsheets against the latest Meta Claude marketplace skills.

LOCAL CHEATSHEETS (~/work/claude/cheatsheets/):
$cheatsheet_manifest

STEPS:
1. List all available skills from the claude-templates marketplace. Also check installed plugins at ~/.claude/plugins/.
2. For each local cheatsheet, check if a marketplace skill covers the same domain.
3. Classify each: UPGRADE / COMPLEMENT / LOCAL-ONLY / STALE.
4. Write findings to $DRIFT_REPORT.

Be specific about WHAT the skill has that the cheatsheet lacks. Do NOT install or modify anything. Read-only analysis." \
        -- --allowedTools Read Glob Grep \
        --model claude-sonnet-4-6 --effort high \
        --max-turns 50 || drift_exit=$?
fi

# Check org synthesis succeeded
if [ "$org_synth_exit" -ne 0 ]; then
    echo "$LOG_PREFIX  [WARN] Org Claude synthesis failed"
    cron_alert "area-monitor" "Org Claude synthesis failed (exit=$org_synth_exit)"
fi

if [ "$skill_synth_exit" -ne 0 ]; then
    echo "$LOG_PREFIX  [WARN] Skill Claude synthesis failed"
    # Non-fatal: org monitor can still proceed
fi

# Clean org output — strip preamble before first heading
ORG_MD="$WORK_DIR/org_clean.md"
if [ -f "$ORG_MD_RAW" ] && [ -s "$ORG_MD_RAW" ]; then
    python3 - "$ORG_MD_RAW" "$ORG_MD" "$TODAY" "Org Monitor" << 'PYEOF2'
import sys, re
with open(sys.argv[1]) as f:
    content = f.read()
match = re.search(r'^# ', content, re.MULTILINE)
if match:
    content = content[match.start():]
else:
    # No heading found — synthesis produced garbage (e.g., Claude warning banner)
    preview = content[:500].strip().replace('\n', '\n> ')
    content = (
        f"# {sys.argv[3]} — {sys.argv[4]}\n\n"
        f"**Synthesis failed**: Claude output did not start with a markdown heading.\n\n"
        f"**Raw output preview** (first 500 chars):\n> {preview}\n\n"
        f"**Possible causes**: (1) Claude returned a warning/disclaimer banner instead of content, "
        f"(2) prompt did not enforce heading-first output, (3) input data was empty or malformed.\n\n"
        f"**Debug**: Check `~/logs/cron-area-monitor-*.log` and `$WORK_DIR/org_raw.md` for full output.\n"
    )
with open(sys.argv[2], 'w') as f:
    f.write(content.strip() + '\n')
PYEOF2
    # Post-process: convert plain-text D-numbers to clickable links (T264494728)
    python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
# Match D followed by 6-10 digits that are NOT already inside a markdown link or URL path
# Negative lookbehind for / or > to avoid already-linked IDs in URLs/HTML
# Negative lookahead to skip IDs already wrapped in [D...](...)
content = re.sub(r'(?<![/>\w])D(\d{6,10})(?!\d)(?![^[]*\])', r'[D\1](https://www.internalfb.com/diff/D\1)', content)
with open(sys.argv[1], 'w') as f:
    f.write(content)
" "$ORG_MD" 2>/dev/null || true
else
    printf "# %s — Org Monitor\n\n**Synthesis failed**: No raw output file found. Claude process may have crashed or timed out.\n\n**Debug**: Check ~/logs/cron-area-monitor-*.log for errors.\n" "$TODAY" > "$ORG_MD"
fi

# Clean skill output — strip preamble before first heading
SKILL_MD="$WORK_DIR/skill_clean.md"
if [ -f "$SKILL_MD_RAW" ] && [ -s "$SKILL_MD_RAW" ]; then
    python3 - "$SKILL_MD_RAW" "$SKILL_MD" "$TODAY" "AI Skill Monitor" << 'PYEOF3'
import sys, re
with open(sys.argv[1]) as f:
    content = f.read()
match = re.search(r'^# ', content, re.MULTILINE)
if match:
    content = content[match.start():]
else:
    preview = content[:500].strip().replace('\n', '\n> ')
    content = (
        f"# {sys.argv[3]} — {sys.argv[4]}\n\n"
        f"**Synthesis failed**: Claude output did not start with a markdown heading.\n\n"
        f"**Raw output preview** (first 500 chars):\n> {preview}\n\n"
        f"**Possible causes**: (1) Claude returned a warning/disclaimer banner instead of content, "
        f"(2) prompt did not enforce heading-first output, (3) input data was empty or malformed.\n\n"
        f"**Debug**: Check `~/logs/cron-area-monitor-*.log` and `$WORK_DIR/skill_raw.md` for full output.\n"
    )
with open(sys.argv[2], 'w') as f:
    f.write(content.strip() + '\n')
PYEOF3
else
    printf "# %s — AI Skill Monitor\n\n**Synthesis failed**: No raw output file found. Claude process may have crashed or timed out.\n\n**Debug**: Check ~/logs/cron-area-monitor-*.log for errors.\n" "$TODAY" > "$SKILL_MD"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Sequential Google Doc push — tab t.7p1pm5er8oet (Org) + tab t.n3cgnazi5bxp (Skill)
# ═══════════════════════════════════════════════════════════════════════════════

# Helper: convert markdown to ghtml
md_to_ghtml() {
    local input_file="$1"
    local output_file="$2"
    python3 - "$input_file" "$output_file" << 'PYEOF_HTML'
import re, sys

with open(sys.argv[1]) as f:
    md = f.read()

# First pass: convert markdown tables to HTML tables
lines = md.split('\n')
result_lines = []
in_table = False

for line in lines:
    stripped = line.strip()
    # Detect table rows (start with |)
    if stripped.startswith('|') and stripped.endswith('|'):
        cells = [c.strip() for c in stripped.strip('|').split('|')]
        # Skip separator rows (|---|---|)
        if all(re.match(r'^[-:]+$', c) for c in cells):
            continue
        if not in_table:
            result_lines.append('<table>')
            # First row is header — use <td><b> not <th> (ghtml drops <th> content)
            result_lines.append('<tr style="background-color:#C9DAF8">' + ''.join(f'<td style="font-size:11pt"><b>{c}</b></td>' for c in cells) + '</tr>')
            in_table = True
        else:
            # Single-line cells — strip inner newlines/br
            result_lines.append('<tr>' + ''.join(f'<td style="font-size:11pt">{c.replace(chr(10)," ")}</td>' for c in cells) + '</tr>')
    else:
        if in_table:
            result_lines.append('</table>')
            in_table = False
        result_lines.append(line)

if in_table:
    result_lines.append('</table>')

html = '\n'.join(result_lines)

# Second pass: convert other markdown elements
html = re.sub(r'^# (.+)$', r'<h1>\1</h1>', html, flags=re.MULTILINE)
html = re.sub(r'^## (.+)$', r'<h2>\1</h2>', html, flags=re.MULTILINE)
# Convert blockquotes: > text → styled gray italic paragraph
html = re.sub(r'^> (.+)$', r'<p style="color:#666;font-size:9pt"><i>\1</i></p>', html, flags=re.MULTILINE)
html = re.sub(r'^---$', r'<hr/>', html, flags=re.MULTILINE)
# Convert bullet items: - **X**: Y → <li><b>X</b>: Y</li>
html = re.sub(r'^- \*\*(.+?)\*\*(.*)$', r'<li style="font-size:11pt"><b>\1</b>\2</li>', html, flags=re.MULTILINE)
# Convert bare bullets: - text → <li>text</li>
html = re.sub(r'^- (.+)$', r'<li style="font-size:11pt">\1</li>', html, flags=re.MULTILINE)
# Convert markdown links [text](url) → <a href="url">text</a>
html = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', html)
# Convert remaining bold **text** → <b>text</b>
html = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', html)
# Wrap consecutive <li> items in <ul></ul>
lines = html.split('\n')
result = []
in_list = False
for line in lines:
    stripped = line.strip()
    if stripped.startswith('<li'):
        if not in_list:
            result.append('<ul>')
            in_list = True
        result.append(stripped)
    else:
        if in_list:
            result.append('</ul>')
            in_list = False
        if stripped:
            # Skip empty paragraphs that create blank lines
            if stripped in ('<p></p>', '<p> </p>'):
                continue
            # Wrap plain text (not already in block-level HTML tags) with font-size
            if not re.match(r'^<(h[1-6]|table|/table|tr|/tr|td|/td|ul|/ul|li|hr|p )', stripped):
                result.append(f'<p style="font-size:11pt">{stripped}</p>')
            else:
                result.append(stripped)
if in_list:
    result.append('</ul>')
with open(sys.argv[2], 'w') as f:
    f.write('\n'.join(result))
PYEOF_HTML
}

# Helper: push markdown content to a specific Google Doc tab.
# Preserves previous days' content by detecting date-based H1 headings:
#   - REPLACE: if today's date heading exists, delete only that section and re-insert
#   - PREPEND: if today is new, insert at top — previous days stay below
#   - FRESH:   empty doc or no date headings — insert from scratch
push_to_tab() {
    local tab_id="$1"
    local md_file="$2"
    local tab_label="$3"

    echo "$LOG_PREFIX  Pushing to Google Doc tab $tab_label ($tab_id)..."

    # Get current doc structure to find date-based sections
    local struct_file="$WORK_DIR/tab_structure_${tab_id//\./_}.txt"
    gdocs content get-structure "$GDOC_ID" --tab-id "$tab_id" > "$struct_file" 2>/dev/null || true

    # Determine strategy based on existing content
    local range_info
    range_info=$(python3 - "$struct_file" "$TODAY" << 'PYEOF'
import sys, re

with open(sys.argv[1]) as f:
    structure = f.read()
today = sys.argv[2]

if not structure.strip():
    print("FRESH")
    sys.exit(0)

lines = structure.strip().split('\n')
date_headings = []  # (start_index, date_str)
max_index = 1

for line in lines:
    # Track doc end via end indices in [START-END] format
    for idx_str in re.findall(r'\d+(?=\])', line):
        idx = int(idx_str)
        if idx > max_index:
            max_index = idx

    # Find HEADING_1 lines containing YYYY-MM-DD dates
    idx_match = re.match(r'^\[(\d+)', line)
    if idx_match and 'HEADING_1' in line:
        date_match = re.search(r'(\d{4}-\d{2}-\d{2})', line)
        if date_match:
            date_headings.append((int(idx_match.group(1)), date_match.group(1)))

doc_end = max_index

if not date_headings:
    if doc_end > 2:
        print(f"FRESH {doc_end}")
    else:
        print("FRESH")
    sys.exit(0)

# Check if today's section already exists
for i, (idx, date_str) in enumerate(date_headings):
    if date_str == today:
        today_end = date_headings[i + 1][0] if i + 1 < len(date_headings) else doc_end
        print(f"REPLACE {idx} {today_end}")
        sys.exit(0)

print(f"PREPEND {doc_end}")
PYEOF
)

    local action
    action=$(echo "$range_info" | awk '{print $1}')
    local insert_ok=false
    local insert_attempt=0

    case "$action" in
        REPLACE)
            local start_idx end_idx
            start_idx=$(echo "$range_info" | awk '{print $2}')
            end_idx=$(echo "$range_info" | awk '{print $3}')

            echo "$LOG_PREFIX  Replacing today's section ($tab_label: $start_idx to $end_idx)..."

            # deleteContentRange fails on ranges containing tables ("Invalid deletion range").
            # Remove tables row-by-row first (highest index first), then deleteContentRange
            # the remaining text. Per gdocs/rules.md Common Mistakes line 168.
            local table_ops
            table_ops=$(python3 - "$struct_file" "$start_idx" "$end_idx" "$tab_id" << 'PYEOF_TABLE_OPS'
import sys, re, json

with open(sys.argv[1]) as f:
    lines = f.read().strip().split('\n')
s_idx = int(sys.argv[2])
e_idx = int(sys.argv[3])
tab_id = sys.argv[4]

tables = []  # (table_start_char_idx, row_count)
for line in lines:
    m = re.match(r'^\[(\d+)-\d+\] TABLE: (\d+)x\d+', line)
    if not m:
        continue
    tidx = int(m.group(1))
    if tidx < s_idx or tidx >= e_idx:
        continue
    tables.append((tidx, int(m.group(2))))

tables.sort(reverse=True)
ops = []
for t_idx, rows in tables:
    for _ in range(rows):
        ops.append({"deleteTableRow": {"tableCellLocation": {
            "tableStartLocation": {"index": t_idx, "tabId": tab_id},
            "rowIndex": 0, "columnIndex": 0}}})
if ops:
    print(json.dumps(ops))
PYEOF_TABLE_OPS
)
            if [ -n "$table_ops" ] && [ "$table_ops" != "null" ]; then
                echo "$LOG_PREFIX   Deleting tables in today's section before deleteContentRange..."
                if ! echo "$table_ops" | gdocs batch-update "$GDOC_ID" --data - > /dev/null 2>&1; then
                    gdocs_track_error "batch-update failed (delete-tables-$tab_label) at $0:$LINENO"
                fi
                # Re-fetch structure — table deletions shifted indices
                gdocs content get-structure "$GDOC_ID" --tab-id "$tab_id" > "$struct_file" 2>/dev/null || true
                local new_range
                new_range=$(python3 - "$struct_file" "$TODAY" << 'PYEOF_NEW_RANGE'
import sys, re
with open(sys.argv[1]) as f:
    lines = f.read().strip().split('\n')
today = sys.argv[2]
start_idx = None
end_idx = None
max_idx = 1
for line in lines:
    for m in re.findall(r'\d+(?=\])', line):
        v = int(m)
        if v > max_idx:
            max_idx = v
    h = re.match(r'^\[(\d+)-\d+\] HEADING_1: "(.+)"', line)
    if not h:
        continue
    dm = re.search(r'(\d{4}-\d{2}-\d{2})', h.group(2))
    if not dm:
        continue
    if start_idx is None and dm.group(1) == today:
        start_idx = int(h.group(1))
        continue
    if start_idx is not None and end_idx is None:
        end_idx = int(h.group(1))
if start_idx is not None:
    print(f"{start_idx} {end_idx if end_idx is not None else max_idx}")
PYEOF_NEW_RANGE
)
                if [ -n "$new_range" ]; then
                    start_idx=$(echo "$new_range" | awk '{print $1}')
                    end_idx=$(echo "$new_range" | awk '{print $2}')
                fi
            fi

            if [ "$end_idx" -gt "$start_idx" ]; then
                if ! echo "[{\"deleteContentRange\":{\"range\":{\"startIndex\":$start_idx,\"endIndex\":$((end_idx - 1)),\"tabId\":\"$tab_id\"}}}]" \
                    | gdocs batch-update "$GDOC_ID" --data - 2>/dev/null; then
                    gdocs_track_error "batch-update failed (delete-range-$tab_label) at $0:$LINENO"
                fi
            fi

            # Insert with retry — if delete succeeded but insert fails, retry
            # to avoid leaving the doc in a shrunken state.
            while [ "$insert_attempt" -lt 3 ] && [ "$insert_ok" = false ]; do
                insert_attempt=$((insert_attempt + 1))
                if gdocs content insert-markdown "$GDOC_ID" "@${md_file}" --index "$start_idx" --tab-id "$tab_id" 2>&1; then
                    insert_ok=true
                else
                    echo "$LOG_PREFIX  Insert attempt $insert_attempt/3 failed for $tab_label, retrying in 5s..."
                    sleep 5
                fi
            done
            ;;

        PREPEND)
            echo "$LOG_PREFIX  Prepending new day to $tab_label (preserving previous days)..."

            while [ "$insert_attempt" -lt 3 ] && [ "$insert_ok" = false ]; do
                insert_attempt=$((insert_attempt + 1))
                if gdocs content insert-markdown "$GDOC_ID" "@${md_file}" --index 1 --tab-id "$tab_id" 2>&1; then
                    insert_ok=true
                else
                    echo "$LOG_PREFIX  Insert attempt $insert_attempt/3 failed for $tab_label, retrying in 15s..."
                    sleep 15
                fi
            done
            ;;

        FRESH|*)
            echo "$LOG_PREFIX  Fresh insert for $tab_label..."

            local doc_end
            doc_end=$(echo "$range_info" | awk '{print $2}')
            if [ -n "$doc_end" ] && [ "$doc_end" -gt 2 ] 2>/dev/null; then
                if ! echo "[{\"deleteContentRange\":{\"range\":{\"startIndex\":1,\"endIndex\":$((doc_end - 1)),\"tabId\":\"$tab_id\"}}}]" \
                    | gdocs batch-update "$GDOC_ID" --data - 2>/dev/null; then
                    gdocs_track_error "batch-update failed (fresh-delete-$tab_label) at $0:$LINENO"
                fi
            fi

            while [ "$insert_attempt" -lt 3 ] && [ "$insert_ok" = false ]; do
                insert_attempt=$((insert_attempt + 1))
                if gdocs content insert-markdown "$GDOC_ID" "@${md_file}" --index 1 --tab-id "$tab_id" 2>&1; then
                    insert_ok=true
                else
                    echo "$LOG_PREFIX  Insert attempt $insert_attempt/3 failed for $tab_label, retrying in 15s..."
                    sleep 15
                fi
            done
            ;;
    esac

    if $insert_ok; then
        echo "$LOG_PREFIX  Tab $tab_label updated successfully"

        # Post-insert cleanup: insert-markdown creates empty HEADING_1 paragraphs
        # between every element. Use shared cleanup — deletes empties, downgrades
        # table-preceding headings. The previous inline version only restyled empty
        # HEADING_N to NORMAL_TEXT without deleting, leaving the blank lines visible.
        source ~/work/claude/scripts/gdocs-cleanup-empty-lines.sh
        gdocs_cleanup_empty_lines "$GDOC_ID" --tab-id "$tab_id" --log-prefix "$LOG_PREFIX "
    else
        echo "$LOG_PREFIX  [WARN] Tab $tab_label push failed after 3 attempts"
        return 1
    fi
}

echo "$LOG_PREFIX  Pushing to Google Doc..."

# Tier 3: capture pre-push revision so we can alert with rollback instructions if validation fails
gdocs_capture_prepush_revision "$GDOC_ID" "org_monitor" || true

# Push markdown directly to tabs (insert-markdown handles tables + links natively)
# Skip push if synthesis failed — don't overwrite good content with error placeholders
org_push_ok=true
if [ "$org_synth_exit" -ne 0 ]; then
    org_push_ok=false
    echo "$LOG_PREFIX  Skipping Org Monitor push — synthesis failed (exit=$org_synth_exit)"
else
    push_to_tab "t.7p1pm5er8oet" "$ORG_MD" "Org Monitor" || org_push_ok=false
    $org_push_ok && tab_freshness_mark "area-org-monitor"
fi

# AREA RULE 10 CODE ENFORCEMENT: hard-abort if any practice entry older than 14 days
# would be included in the push. Belt-and-suspenders check — the pre-render filter
# should have already excluded them, but this catches template pass-through failures.
skill_push_ok=true
if [ "$skill_synth_exit" -eq 0 ] && [ -f "$SKILL_MD" ]; then
    stale_count=$(python3 - "$SKILL_MD" << 'PYEOF_STALE_CHECK'
import sys, re
from datetime import datetime, timedelta

with open(sys.argv[1]) as f:
    content = f.read()
cutoff = (datetime.now() - timedelta(days=14)).strftime("%Y-%m-%d")
# Find date patterns in the Validated AI Practices section
in_section = False
stale = 0
for line in content.split('\n'):
    if 'My Validated AI Practices' in line:
        in_section = True
        continue
    if in_section and line.startswith('## '):
        break
    if in_section:
        dates = re.findall(r'\b(\d{4}-\d{2}-\d{2})\b', line)
        for d in dates:
            if d < cutoff:
                stale += 1
print(stale)
PYEOF_STALE_CHECK
    )
    if [ "${stale_count:-0}" -gt 0 ]; then
        echo "$LOG_PREFIX  HARD ABORT: $stale_count practice entries older than 14 days in skill output — AREA RULE 10 violation"
        cron_alert "area-monitor" "AREA RULE 10 violation: $stale_count stale practice entries (>14d) in AI Skill Monitor output"
        skill_push_ok=false
    fi
fi

# AREA RULE 16 CODE ENFORCEMENT: description must appear ≤ 1 time in generated content.
# The description was removed from per-day templates — this catches regressions.
if [ "$skill_synth_exit" -eq 0 ] && [ -f "$SKILL_MD" ] && $skill_push_ok; then
    scout_count=$(grep -c 'Nightly scout' "$SKILL_MD" || echo "0")
    if [ "${scout_count:-0}" -gt 1 ]; then
        echo "$LOG_PREFIX  HARD ABORT: 'Nightly scout' appears $scout_count times in AI Skill output — AREA RULE 16 violation"
        cron_alert "area-monitor" "AREA RULE 16 violation: 'Nightly scout' appears $scout_count times (expected ≤ 1) — description leaked into per-day template"
        echo "- **$(date '+%Y-%m-%d %H:%M')** [area-monitor] AREA RULE 16: 'Nightly scout' ×${scout_count} in generated content — description must be one-time at doc top" >> "$REPO_DIR/ALERTS.md"
        skill_push_ok=false
    fi
fi
if [ "$org_synth_exit" -eq 0 ] && [ -f "$ORG_MD" ] && $org_push_ok; then
    scan_count=$(grep -c 'Nightly scan' "$ORG_MD" || echo "0")
    if [ "${scan_count:-0}" -gt 1 ]; then
        echo "$LOG_PREFIX  HARD ABORT: 'Nightly scan' appears $scan_count times in Org Monitor output — AREA RULE 16 violation"
        cron_alert "area-monitor" "AREA RULE 16 violation: 'Nightly scan' appears $scan_count times (expected ≤ 1) — description leaked into per-day template"
        echo "- **$(date '+%Y-%m-%d %H:%M')** [area-monitor] AREA RULE 16: 'Nightly scan' ×${scan_count} in generated content — description must be one-time at doc top" >> "$REPO_DIR/ALERTS.md"
        org_push_ok=false
    fi
fi

if [ "$skill_synth_exit" -ne 0 ]; then
    skill_push_ok=false
    echo "$LOG_PREFIX  Skipping AI Skill Monitor push — synthesis failed (exit=$skill_synth_exit)"
elif $skill_push_ok; then
    push_to_tab "t.n3cgnazi5bxp" "$SKILL_MD" "AI Skill Monitor" || skill_push_ok=false
    $skill_push_ok && tab_freshness_mark "area-ai-skill-monitor"
fi

if $org_push_ok && [ "$org_synth_exit" -eq 0 ]; then
    cron_alert_clear "area-monitor"
elif ! $org_push_ok && [ "$org_synth_exit" -eq 0 ]; then
    cron_alert "area-monitor" "Google Doc push failed — monitor written to local cache only"
fi

# Post-push formatting: column widths + 11pt body font + empty line cleanup
format_after_push() {
    local tab_id="$1"
    local tab_label="$2"
    echo "$LOG_PREFIX  Formatting $tab_label tables (font=11pt, cleanup empty lines)..."

    local structure
    structure=$(gdocs content get-structure "$GDOC_ID" --tab-id "$tab_id" 2>/dev/null || true)
    [ -z "$structure" ] && return 0

    # Extract table start and end indices for font sizing
    local table_ranges
    table_ranges=$(echo "$structure" | grep 'TABLE:' | grep -oP '^\[(\d+)-(\d+)' | tr -d '[' || true)

    # Build font-size requests for ALL tables (11pt body-font rule).
    # Use tend-1 to avoid bleeding 11pt into the first char of the next heading.
    # Table endIndex overlaps the next element's startIndex by 1 char.
    local font_json=""
    while IFS='-' read -r tstart tend; do
        [ -z "$tstart" ] && continue
        local tend_safe=$((tend - 1))
        [ "$tend_safe" -le "$tstart" ] && continue
        font_json+='{"updateTextStyle":{"range":{"startIndex":'$tstart',"endIndex":'$tend_safe',"tabId":"'$tab_id'"},"textStyle":{"fontSize":{"magnitude":11,"unit":"PT"}},"fields":"fontSize"}},'
    done <<< "$table_ranges"

    # Build font-size requests for ALL NORMAL_TEXT paragraphs (11pt body-font rule).
    # Skips empty paragraphs (start==end-1 zero-content separators) since those have
    # no text runs to style and batch-update rejects zero-length ranges.
    local normal_ranges
    normal_ranges=$(echo "$structure" | grep -oP '^\[\K\d+-\d+(?=\] NORMAL_TEXT: ".+")' || true)
    while IFS='-' read -r nstart nend; do
        [ -z "$nstart" ] && continue
        [ "$nend" -le "$nstart" ] && continue
        font_json+='{"updateTextStyle":{"range":{"startIndex":'$nstart',"endIndex":'$nend',"tabId":"'$tab_id'"},"textStyle":{"fontSize":{"magnitude":11,"unit":"PT"}},"fields":"fontSize"}},'
    done <<< "$normal_ranges"

    if [ -n "$font_json" ]; then
        if echo "[${font_json%,}]" | gdocs batch-update "$GDOC_ID" --data - 2>/dev/null; then
            echo "$LOG_PREFIX   Body font set to 11pt ($tab_label)"
        else
            gdocs_track_error "batch-update failed (body-font-$tab_label) at $0:$LINENO"
        fi
    fi

    # Shrink empty NORMAL_TEXT paragraphs to ~0 height (can't delete — Docs requires them)
    # insert-markdown creates empty paragraphs between headings and tables.
    # Google Docs API rejects deleteContentRange on these structural separators.
    # Fix: set font to 1pt + line spacing to 1pt so they're visually invisible.
    # NOTE: combining here-string (<<<) with heredoc (<<) is broken — heredoc wins,
    # structure never reaches python. Pass structure via temp file instead.
    local shrink_struct_file
    shrink_struct_file=$(mktemp)
    printf '%s\n' "$structure" > "$shrink_struct_file"
    local shrink_json
    shrink_json=$(python3 - "$tab_id" "$shrink_struct_file" << 'PYEOF_CLEANUP'
import sys, re, json

tab_id = sys.argv[1] if len(sys.argv) > 1 else ""
with open(sys.argv[2]) as f:
    structure = f.read()

entries = []
for line in structure.strip().split('\n'):
    m = re.match(r'\[(\d+)-(\d+)\] (\S+)', line)
    if m:
        entries.append((int(m.group(1)), int(m.group(2)), m.group(3)))

requests = []
for i, (start, end, etype) in enumerate(entries):
    if etype != 'NORMAL_TEXT':
        continue
    if end - start != 1:
        continue  # not empty (has content)
    if i == len(entries) - 1:
        continue
    rng = {"startIndex": start, "endIndex": end}
    if tab_id:
        rng["tabId"] = tab_id
    # Set font size to 1pt
    requests.append({"updateTextStyle": {
        "range": rng,
        "textStyle": {"fontSize": {"magnitude": 1, "unit": "PT"}},
        "fields": "fontSize"
    }})
    # Set line spacing to minimum
    requests.append({"updateParagraphStyle": {
        "range": rng,
        "paragraphStyle": {
            "lineSpacing": 10,
            "spaceAbove": {"magnitude": 0, "unit": "PT"},
            "spaceBelow": {"magnitude": 0, "unit": "PT"}
        },
        "fields": "lineSpacing,spaceAbove,spaceBelow"
    }})

if requests:
    print(json.dumps(requests))
PYEOF_CLEANUP
)
    rm -f "$shrink_struct_file"
    if [ -n "$shrink_json" ] && [ "$shrink_json" != "null" ]; then
        local shrink_count
        shrink_count=$(echo "$shrink_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin))//2)" 2>/dev/null || echo 0)
        if echo "$shrink_json" | gdocs batch-update "$GDOC_ID" --data - 2>/dev/null; then
            echo "$LOG_PREFIX   Shrunk $shrink_count empty lines ($tab_label)"
        else
            gdocs_track_error "batch-update failed (shrink-empty-$tab_label) at $0:$LINENO"
        fi
    fi
}

# AREA RULE 8 CODE ENFORCEMENT: enforce Arial 12pt on all content after push
apply_font_style() {
    local tab_id="$1"
    local tab_label="$2"
    echo "$LOG_PREFIX  Enforcing Arial 12pt on $tab_label (AREA RULE 8)..."

    local structure
    structure=$(gdocs content get-structure "$GDOC_ID" --tab-id "$tab_id" 2>/dev/null || true)
    [ -z "$structure" ] && return 0

    # Find the full content range (1 to max index).
    # On helper failure, fall back to 1 (no-op) and track the error so it's
    # visible in ALERTS.md instead of silently swallowed.
    local max_index
    max_index=$(echo "$structure" | python3 "$GDOCS_HELPER_PY" max-index) \
        || { gdocs_track_error "max-index helper failed ($tab_label) at $0:$LINENO"; max_index=1; }

    if [ "$max_index" -le 1 ]; then
        echo "$LOG_PREFIX   No content to style in $tab_label"
        return 0
    fi

    # Apply Arial (font family only) to entire content range. Do NOT set fontSize here —
    # body font sizing is handled by format_after_push (11pt for tables + NORMAL_TEXT),
    # and headings must keep their default Google Docs sizes (H1=20pt, H2=16pt, H3=14pt).
    if echo '[{"updateTextStyle":{"range":{"startIndex":1,"endIndex":'"$max_index"',"tabId":"'"$tab_id"'"},"textStyle":{"weightedFontFamily":{"fontFamily":"Arial"}},"fields":"weightedFontFamily"}}]' \
        | gdocs batch-update "$GDOC_ID" --data - 2>/dev/null; then
        echo "$LOG_PREFIX   Arial font applied to $tab_label"
    else
        gdocs_track_error "batch-update failed (arial-font-$tab_label) at $0:$LINENO"
    fi

    # Explicitly restore default heading sizes (H1=20pt through H6=11pt).
    # Defensive: even without prior fontSize pollution, prior runs or inherited inline
    # styles from insert-markdown can leave headings at the wrong size.
    local heading_ops
    heading_ops=$(gdocs content get-structure "$GDOC_ID" --tab-id "$tab_id" 2>/dev/null \
        | python3 "$GDOCS_HELPER_PY" heading-sizes --tab-id "$tab_id") \
        || gdocs_track_error "heading-sizes helper failed ($tab_label) at $0:$LINENO"
    if [ -n "${heading_ops:-}" ] && [ "$heading_ops" != "[]" ]; then
        if echo "$heading_ops" | gdocs batch-update "$GDOC_ID" --data - 2>/dev/null; then
            echo "$LOG_PREFIX   Heading sizes restored to defaults in $tab_label"
        else
            gdocs_track_error "batch-update failed (heading-sizes-$tab_label) at $0:$LINENO"
        fi
    fi
}

# Post-push lint: verify no non-Arial or non-12pt paragraphs remain outside tables
lint_font_style() {
    local tab_id="$1"
    local tab_label="$2"
    echo "$LOG_PREFIX  Linting font style on $tab_label..."

    # Fetch raw doc JSON to a temp file. Heredoc + echo-pipe to python3 is SIGPIPE-
    # prone on large JSON (8MB+) because heredoc overrides stdin — the echo buffer
    # fills and the shell gets exit 141, killing the rest of the pipeline.
    local raw_json_file
    raw_json_file=$(mktemp)
    timeout 30 gdocs get "$GDOC_ID" --tab-id "$tab_id" --raw-json > "$raw_json_file" 2>/dev/null || true

    if [ ! -s "$raw_json_file" ]; then
        echo "$LOG_PREFIX   [WARN] Could not fetch raw JSON for font lint ($tab_label) — skipping"
        rm -f "$raw_json_file"
        return 0
    fi

    local violations
    violations=$(python3 - "$tab_id" "$raw_json_file" << 'PYEOF_FONT_LINT'
import json, sys

tab_id = sys.argv[1]
json_path = sys.argv[2]

try:
    with open(json_path) as f:
        doc = json.load(f)
except Exception:
    print("PARSE_ERROR")
    sys.exit(0)

# Navigate to the tab body content
body = None
for tab in doc.get("tabs", []):
    if tab.get("tabProperties", {}).get("tabId") == tab_id:
        body = tab.get("documentTab", {}).get("body", {})
        break
if not body:
    body = doc.get("body", {})
if not body:
    print("NO_BODY")
    sys.exit(0)

violations = []
# Body-font rule: body paragraphs = 11pt, headings = Google Docs defaults (H1=20pt, H2=16pt, H3=14pt)
HEADING_SIZES = {"HEADING_1": 20, "HEADING_2": 16, "HEADING_3": 14, "TITLE": 26, "SUBTITLE": 14}
for element in body.get("content", []):
    # Skip tables — their font is managed separately by format_after_push (11pt)
    if "table" in element:
        continue
    paragraph = element.get("paragraph")
    if not paragraph:
        continue
    para_style = paragraph.get("paragraphStyle", {}) or {}
    named_style = para_style.get("namedStyleType", "") or ""
    is_heading = named_style.startswith("HEADING_") or named_style in ("TITLE", "SUBTITLE")
    expected_size = HEADING_SIZES.get(named_style, 14) if is_heading else 11
    for pe in paragraph.get("elements", []):
        text_run = pe.get("textRun")
        if not text_run:
            continue
        text = text_run.get("content", "").strip()
        if not text:
            continue
        style = text_run.get("textStyle", {})
        font_family = style.get("weightedFontFamily", {}).get("fontFamily", "")
        font_size = style.get("fontSize", {})
        magnitude = font_size.get("magnitude", 0) if font_size else 0
        if font_family and font_family != "Arial":
            violations.append(f"Non-Arial font '{font_family}': '{text[:40]}'")
        if magnitude and magnitude != expected_size:
            kind = "heading" if is_heading else "body"
            violations.append(f"Non-{expected_size}pt {kind} ({magnitude}pt): '{text[:40]}'")

if violations:
    for v in violations[:10]:
        print(v)
    if len(violations) > 10:
        print(f"... and {len(violations) - 10} more violations")
else:
    print("PASS")
PYEOF_FONT_LINT
)
    rm -f "$raw_json_file"

    if [ "$violations" = "PASS" ]; then
        echo "$LOG_PREFIX   Font lint PASSED ($tab_label)"
    elif [ "$violations" = "PARSE_ERROR" ] || [ "$violations" = "NO_BODY" ]; then
        echo "$LOG_PREFIX   [WARN] Font lint could not parse doc ($tab_label)"
    else
        echo "$LOG_PREFIX   [WARN] Font lint found violations in $tab_label:"
        echo "$violations" | while read -r line; do
            echo "$LOG_PREFIX     $line"
        done
    fi
}

# Set proportional column widths on Org Monitor tables (config-driven)
if $org_push_ok; then
    echo "$LOG_PREFIX  Setting table column widths on Org Monitor tab (from config)..."
    gdocs_apply_table_widths "$GDOC_ID" "t.7p1pm5er8oet" "area_monitor"
    apply_font_style "t.7p1pm5er8oet" "Org Monitor"
    format_after_push "t.7p1pm5er8oet" "Org Monitor"
    lint_font_style "t.7p1pm5er8oet" "Org Monitor"

    # Tier 3 post-push validation: did the push actually produce today's content?
    # On fail: logs rollback-ready alert with pre-push revision ID.
    gdocs_validate_post_push "$GDOC_ID" "t.7p1pm5er8oet" "org_monitor" gdocs_validate_h1_today || true
fi
if $skill_push_ok; then
    echo "$LOG_PREFIX  Setting table column widths + header bg on AI Skill Monitor tab (config-driven)..."
    gdocs_apply_table_widths "$GDOC_ID" "t.n3cgnazi5bxp" "area_monitor"
    gdocs_apply_header_row_bg "$GDOC_ID" "t.n3cgnazi5bxp" "AI Skill Monitor"
    apply_font_style "t.n3cgnazi5bxp" "AI Skill Monitor"
    format_after_push "t.n3cgnazi5bxp" "AI Skill Monitor"
    lint_font_style "t.n3cgnazi5bxp" "AI Skill Monitor"
fi
archive_old_entries() {
    local tab_id="$1"
    local tab_label="$2"

    local struct_file="$WORK_DIR/archive_structure_${tab_id//\./_}.txt"
    gdocs content get-structure "$GDOC_ID" --tab-id "$tab_id" > "$struct_file" 2>/dev/null || true

    local archive_range
    archive_range=$(python3 - "$struct_file" "$TODAY" << 'PYEOF_ARCHIVE'
import sys, re
from datetime import datetime, timedelta

with open(sys.argv[1]) as f:
    structure = f.read()
today = datetime.strptime(sys.argv[2], '%Y-%m-%d')
cutoff = today - timedelta(days=7)

if not structure.strip():
    sys.exit(0)

lines = structure.strip().split('\n')
date_headings = []
max_index = 1

for line in lines:
    for idx_str in re.findall(r'\d+(?=\])', line):
        idx = int(idx_str)
        if idx > max_index:
            max_index = idx
    idx_match = re.match(r'^\[(\d+)', line)
    if idx_match and 'HEADING_1' in line:
        date_match = re.search(r'(\d{4}-\d{2}-\d{2})', line)
        if date_match:
            date_headings.append((int(idx_match.group(1)), date_match.group(1)))

doc_end = max_index

# Entries are newest-first. Find the first heading older than cutoff.
for i, (idx, date_str) in enumerate(date_headings):
    try:
        heading_date = datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        continue
    if heading_date < cutoff:
        # Delete from this heading to doc_end
        print(f"{idx} {doc_end}")
        sys.exit(0)
PYEOF_ARCHIVE
)

    if [ -n "$archive_range" ]; then
        local start_idx end_idx
        start_idx=$(echo "$archive_range" | awk '{print $1}')
        end_idx=$(echo "$archive_range" | awk '{print $2}')
        if [ "$end_idx" -gt "$start_idx" ]; then
            echo "$LOG_PREFIX  Archiving old entries from $tab_label (index $start_idx to $end_idx)..."
            if echo "[{\"deleteContentRange\":{\"range\":{\"startIndex\":$start_idx,\"endIndex\":$((end_idx - 1)),\"tabId\":\"$tab_id\"}}}]" \
                | gdocs batch-update "$GDOC_ID" --data - 2>/dev/null; then
                echo "$LOG_PREFIX   Archived old entries from $tab_label"
            else
                gdocs_track_error "batch-update failed (archive-$tab_label) at $0:$LINENO"
            fi
        fi
    else
        echo "$LOG_PREFIX  No old entries to archive in $tab_label"
    fi
}

if $org_push_ok; then
    archive_old_entries "t.7p1pm5er8oet" "Org Monitor"
fi
if $skill_push_ok; then
    archive_old_entries "t.n3cgnazi5bxp" "AI Skill Monitor"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Local cache + config update + skill scout maintenance
# ═══════════════════════════════════════════════════════════════════════════════

# Copy org markdown to local cache
cp "$ORG_MD" "$CACHE"
echo "$LOG_PREFIX  Org cache written to $CACHE"

# Write skill findings summary to UPSTREAM-TODAY.md
if [ -f "$SKILL_MD" ] && [ -s "$SKILL_MD" ]; then
    # Extract adoption candidates as summary lines
    python3 - "$SKILL_MD" "$SKILL_CACHE" << 'PYEOF_SKILL_SUMMARY'
import sys, re

with open(sys.argv[1]) as f:
    content = f.read()

# Extract items from Adoption Candidates section
candidates = []
in_section = False
for line in content.split('\n'):
    if '## Adoption Candidates' in line:
        in_section = True
        continue
    if line.startswith('## ') and in_section:
        break
    if in_section and line.startswith('- '):
        # Parse: - **Name** (score: N, effort: level): why. [Link](URL)
        match = re.match(r'- \*\*(.+?)\*\*.*?(?:score:\s*(\d+))?.*?(?:effort:\s*(\w+))?.*', line)
        if match:
            name = match.group(1)
            score = match.group(2) or '?'
            effort = match.group(3) or '?'
            candidates.append(f"| skill_group | {name} | {score} | {effort} |")

with open(sys.argv[2], 'w') as f:
    if candidates:
        f.write(f"# Upstream findings {sys.argv[1].split('/')[-1].replace('_clean.md','')}\n\n")
        for c in candidates:
            f.write(c + '\n')
    else:
        f.write('No new upstream findings today.\n')
PYEOF_SKILL_SUMMARY
    echo "$LOG_PREFIX  Skill cache written to $SKILL_CACHE"
else
    echo "No new upstream findings today." > "$SKILL_CACHE"
    echo "$LOG_PREFIX  No skill findings today"
fi

# Update CLAUDE-SKILL-SCOUT.md — append new findings, auto-decline stale items
if [ -f "$SKILL_MD" ] && [ -s "$SKILL_MD" ] && [ -f "$SCOUT_DIGEST" ]; then
    python3 - "$SKILL_MD" "$SCOUT_DIGEST" "$TODAY" << 'PYEOF_SCOUT_UPDATE'
import sys, re
from datetime import datetime, timedelta

skill_output = sys.argv[1]
scout_path = sys.argv[2]
today = sys.argv[3]

with open(skill_output) as f:
    new_content = f.read()

with open(scout_path) as f:
    existing = f.read()

# Auto-decline stale items (>14 days old)
today_dt = datetime.strptime(today, '%Y-%m-%d')
stale_cutoff = today_dt - timedelta(days=14)

lines = existing.split('\n')
updated_lines = []
declined_count = 0
in_pending = False
current_item_lines = []
current_item_date = None

for line in lines:
    if '## Pending' in line:
        in_pending = True
        updated_lines.append(line)
        continue
    if line.startswith('## ') and in_pending:
        in_pending = False

    if in_pending and line.startswith('### '):
        # Check date in item header
        date_match = re.search(r'(\d{4}-\d{2}-\d{2})', line)
        if date_match:
            item_date = datetime.strptime(date_match.group(1), '%Y-%m-%d')
            if item_date < stale_cutoff:
                declined_count += 1
                continue  # Skip stale item

    updated_lines.append(line)

# Enforce pending cap (15)
pending_items = [l for l in updated_lines if l.startswith('### ') and '## Pending' in '\n'.join(updated_lines[:updated_lines.index(l)])]

with open(scout_path, 'w') as f:
    f.write('\n'.join(updated_lines))

if declined_count > 0:
    print(f"Auto-declined {declined_count} stale items")
PYEOF_SCOUT_UPDATE
fi

# ── Auto-P0 tagging: OT dev group + 30d diff volume ──────────────────────────
echo "$LOG_PREFIX  Running auto-P0 tagging..."

p0_exit=0
python3 - "$CONFIG" "$TODAY" << 'PYEOF_P0' || p0_exit=$?
import json, sys, subprocess
from datetime import datetime, timedelta

config_path = sys.argv[1]
today = sys.argv[2]

with open(config_path) as f:
    config = json.load(f)

peers = config.get("peers", [])

# Snapshot P0 count before any changes
p0_before = sum(1 for p in peers if p.get("priority") == "P0")
prev_p0_count = config.get("p0_count", p0_before)
print(f"P0 count before: {p0_before} (persisted from last run: {prev_p0_count})")

added = []

# Rule 1: Auto-add P0 to peers in ot_dev_group (role contains "OT Dev")
for peer in peers:
    role = peer.get("role", "")
    if "OT Dev" in role and peer.get("priority") != "P0":
        peer["priority"] = "P0"
        added.append(f"{peer['name']} (ot_dev_group)")

# Rule 2: Auto-add P0 when 30d diff volume > 10
start_30d = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%dT00:00:00Z')
for peer in peers:
    if peer.get("priority") == "P0":
        continue  # Already P0 — skip API call
    fbid = peer.get("fbid", "")
    if not fbid:
        continue
    try:
        result = subprocess.run(
            ["meta", "search.doc", "search", "-q", " ",
             "--doc-type=DIFF", "--author", fbid,
             "--start-creation-time", start_30d,
             "--limit", "20", "-o", "json"],
            capture_output=True, text=True, timeout=30
        )
        diffs = json.loads(result.stdout) if result.returncode == 0 else []
        if not isinstance(diffs, list):
            diffs = []
        diff_count = len(diffs)
    except Exception:
        diff_count = 0

    if diff_count > 10:
        peer["priority"] = "P0"
        added.append(f"{peer['name']} (30d_volume={diff_count})")

# Rule 3: NEVER auto-remove P0 — enforced by only adding, never deleting

p0_after = sum(1 for p in peers if p.get("priority") == "P0")

if added:
    for a in added:
        print(f"  Auto-P0 added: {a}")
print(f"P0 count after: {p0_after}")

# Post-run assertion: P0 count must never decrease (vs both in-run and persisted)
if p0_after < p0_before:
    print(f"ASSERTION FAILED: P0 count decreased within run ({p0_before} -> {p0_after})")
    sys.exit(1)
if p0_after < prev_p0_count:
    print(f"ASSERTION FAILED: P0 count decreased vs last run ({prev_p0_count} -> {p0_after})")
    sys.exit(1)

print(f"P0 assertion passed: {prev_p0_count} -> {p0_after}")

# Persist updated peers and p0_count
config["peers"] = peers
config["p0_count"] = p0_after
with open(config_path, 'w') as f:
    json.dump(config, f, indent=4)
PYEOF_P0

if [ "$p0_exit" -ne 0 ]; then
    cron_alert "area-monitor" "P0 assertion failed — P0 count decreased"
    echo "$LOG_PREFIX  [ERROR] P0 tagging assertion failed"
fi

# Update last_scan in AREA-MONITOR.json
python3 -c "
import json
with open('$CONFIG') as f:
    config = json.load(f)
config['last_scan'] = '$TODAY'
with open('$CONFIG', 'w') as f:
    json.dump(config, f, indent=4)
"

# Update last_scan in SKILL-SCOUT.yaml (if it exists).
# File is marked linguist-generated=true in .gitattributes so timestamp bumps
# don't pollute review UIs while breadcrumb stays available.
if [ -f "$SKILL_CONFIG" ]; then
    sed -i "s/last_scan:.*/last_scan: \"${TODAY}T$(date +%H:%M:%S)Z\"/" "$SKILL_CONFIG"
fi

echo "$LOG_PREFIX  Config updated"

# Write heartbeat sentinel
write_heartbeat "area-monitor"

echo "$LOG_PREFIX === Area Monitor + AI Skill Scan Done ==="

# Exit non-zero if synthesis failed (prevents false-positive in cron-runtime.csv)
if [ "$org_synth_exit" -ne 0 ] || [ "$skill_synth_exit" -ne 0 ]; then
    echo "$LOG_PREFIX  [ERROR] Exiting non-zero: synthesis failed (org=$org_synth_exit, skill=$skill_synth_exit)"
    exit 1
fi

# Tier 1+3: propagate accumulated gdocs errors. Fires cron_alert if any batch-update
# or post-push validation failed during the run; exits non-zero so the cron-runtime
# dashboard marks this run as failed.
gdocs_exit_with_status "$(basename "$0" .sh)"
