#!/usr/bin/env bash
# setup-cron-jobs.sh — UPSERT all ot-team MyClaw cron jobs from fbcode.
#
# Reads cron-jobs/MANIFEST.json (sibling to this script) and, for each
# entry, UPSERTs the job into the ot-team MyClaw's per-space sqlite
# (jobs table). Prompt body comes from the sibling .md file referenced
# by `prompt_file`.
#
# Idempotent. Safe to re-run any time.
#
# Why fbcode (not ~/work/claude):
#   Same reasoning as CLAUDE.md / team_bot_config.yaml / SKILL.md:
#   audit via Phabricator, survives devserver reinstall via fbsource
#   checkout, single source of truth for the OT lane. Sqlite is the
#   runtime cache; this script re-asserts canonical state.
#
# Source-of-truth chain on devserver reinstall:
#   1. setup-claude.sh restores ot-team home from Manifold.
#   2. fbcode bootstrap.sh refreshes CLAUDE.md + team_bot_config.yaml
#      AND now invokes this script to re-assert all job rows.
#   3. THIS script re-asserts every job's prompt + schedule from the
#      git-tracked manifest, so even a stale Manifold backup recovers
#      to the canonical state.
#
# Manual:    bash <fbsource>/fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/setup-cron-jobs.sh
# Dry-run:   bash <fbsource>/fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/setup-cron-jobs.sh --dry-run
#
# Iteration loop (no diff land needed for testing):
#   1. Edit cron-jobs/<job>.md in fbcode.
#   2. Re-run this script — UPSERTs the new prompt into sqlite.
#   3. Daemon picks up the new prompt on the next scheduled tick.
#   Land the diff once stable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
JOBS_DIR="$SCRIPT_DIR/cron-jobs"
MANIFEST="$JOBS_DIR/MANIFEST.json"
INSTANCE_HOME="${MYCLAW_INSTANCE_HOME:-$HOME/.myclaw-ot-bot}"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: manifest missing: $MANIFEST" >&2
    exit 1
fi

if [ ! -d "$INSTANCE_HOME" ]; then
    echo "ERROR: ot-team MyClaw not initialized at $INSTANCE_HOME" >&2
    echo "       Expected: setup-claude.sh restores via 'myclaw import --manifold' first." >&2
    exit 1
fi

# Locate the per-space sqlite db (jobs live in spaces/<space_id>/myclaw.db).
MYCLAW_DB=""
for db in "$INSTANCE_HOME/spaces/"*/myclaw.db; do
    [ -f "$db" ] && MYCLAW_DB="$db" && break
done
if [ -z "$MYCLAW_DB" ]; then
    echo "ERROR: no spaces/*/myclaw.db under $INSTANCE_HOME" >&2
    exit 1
fi

echo "[setup-cron-jobs] manifest:   $MANIFEST"
echo "[setup-cron-jobs] sqlite db:  $MYCLAW_DB"
echo "[setup-cron-jobs] dry-run:    $DRY_RUN"
echo

# ---- State-file templates --------------------------------------------------
# Seed per-cron state JSON files that the prompts read at runtime. Do NOT
# overwrite if they already exist (operators may have hand-edited values).
STATE_TEMPLATES_DIR="$SCRIPT_DIR/state-templates"
SPACE_DIR="$(dirname "$MYCLAW_DB")"
if [ -d "$STATE_TEMPLATES_DIR" ]; then
    for tmpl in "$STATE_TEMPLATES_DIR"/*.json; do
        [ -f "$tmpl" ] || continue
        target="$SPACE_DIR/$(basename "$tmpl")"
        if [ -f "$target" ]; then
            echo "[STATE-SKIP ] $(basename "$tmpl") (already exists at $target)"
        else
            if [ "$DRY_RUN" -eq 0 ]; then
                cp "$tmpl" "$target"
                echo "[STATE-SEED ] $(basename "$tmpl") → $target"
            else
                echo "[STATE-SEED ] $(basename "$tmpl") → $target (dry-run, skipped)"
            fi
        fi
    done
    echo
fi

python3 - "$MANIFEST" "$JOBS_DIR" "$MYCLAW_DB" "$DRY_RUN" <<'PYEOF'
import json, sqlite3, sys, time
from pathlib import Path

manifest_path, jobs_dir, db_path, dry_run = sys.argv[1:5]
dry_run = bool(int(dry_run))
jobs_dir = Path(jobs_dir)

manifest = json.load(open(manifest_path))
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# triage_events: Phase B metrics scaffold (T269501586). Consumer prompts
# (ot-metrics-rollup, ot-shift-summary) query this table; producers
# (sev-monitor / alert-monitor / post-monitor) will INSERT once wired.
# Create the empty table here so consumer queries don't error before
# producers land.
cur.execute("""
CREATE TABLE IF NOT EXISTS triage_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sev_id TEXT,
    cron_job_id TEXT NOT NULL,
    signal TEXT,
    signal_class TEXT,
    confidence REAL,
    auto_tag_applied INTEGER DEFAULT 0,
    auto_tag_verified_at TEXT,
    auto_tag_stuck INTEGER,
    validator_outcome TEXT,
    suggested_owner TEXT,
    sev_final_status TEXT,
    sev_final_root_cause_area TEXT,
    notification_text TEXT,
    ts_created TEXT NOT NULL DEFAULT (datetime('now')),
    ts_notified TEXT
)
""")
cur.execute("CREATE INDEX IF NOT EXISTS idx_triage_events_sev_id ON triage_events(sev_id)")
cur.execute("CREATE INDEX IF NOT EXISTS idx_triage_events_ts_notified ON triage_events(ts_notified)")

def next_run_for(job):
    """Best-effort next_run_epoch for new INSERTs. Daemon recomputes after first run."""
    now = time.time()
    if job["schedule_type"] == "interval":
        return now + job.get("interval_seconds", 3600)
    if job["schedule_type"] == "cron":
        # Conservative: schedule for next minute. Daemon will pick up and reschedule
        # on next eval against the cron expression.
        return now + 60
    return now + 60

inserts = updates = unchanged = deletes = 0

# Orphan removal: any job_id in sqlite but NOT in MANIFEST is stale
# (e.g., from a rename). Delete it so the daemon doesn't keep running
# the old prompt under the old id. Manifest is the source of truth.
manifest_ids = {job["id"] for job in manifest["jobs"]}
cur.execute("SELECT id FROM jobs")
sqlite_ids = {row[0] for row in cur.fetchall()}
orphan_ids = sqlite_ids - manifest_ids
for orphan in sorted(orphan_ids):
    if not dry_run:
        cur.execute("DELETE FROM jobs WHERE id=?", (orphan,))
    deletes += 1
    print(f"[DELETE   ] {orphan:30s} (orphan — not in manifest)")

for job in manifest["jobs"]:
    job_id = job["id"]
    prompt_path = jobs_dir / job["prompt_file"]
    if not prompt_path.exists():
        print(f"[FAIL] {job_id}: prompt file missing: {prompt_path}")
        continue
    prompt = prompt_path.read_text()

    sched_type = job["schedule_type"]
    cron = job.get("cron")
    interval_seconds = job.get("interval_seconds")
    daily_at = job.get("daily_at")

    cur.execute("SELECT prompt, schedule_type, cron, interval_seconds, daily_at, enabled "
                "FROM jobs WHERE id=?", (job_id,))
    row = cur.fetchone()

    if row is None:
        action = "INSERT"
        if not dry_run:
            created_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            cur.execute("""
                INSERT INTO jobs (id, prompt, schedule_type, cron, interval_seconds, daily_at,
                                  next_run_epoch, last_run_epoch, enabled, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 1, ?)
            """, (job_id, prompt, sched_type, cron, interval_seconds, daily_at,
                  next_run_for(job), created_at))
        inserts += 1
    else:
        cur_prompt, cur_st, cur_cron, cur_int, cur_daily, cur_enabled = row
        same = (cur_prompt == prompt
                and cur_st == sched_type
                and (cur_cron or "") == (cron or "")
                and (cur_int or 0) == (interval_seconds or 0)
                and (cur_daily or "") == (daily_at or "")
                and cur_enabled == 1)
        if same:
            action = "UNCHANGED"
            unchanged += 1
        else:
            action = "UPDATE"
            if not dry_run:
                cur.execute("""
                    UPDATE jobs SET prompt=?, schedule_type=?, cron=?,
                                   interval_seconds=?, daily_at=?, enabled=1
                    WHERE id=?
                """, (prompt, sched_type, cron, interval_seconds, daily_at, job_id))
            updates += 1

    sched_summary = (f"cron='{cron}'" if sched_type == "cron"
                     else f"interval={interval_seconds}s" if sched_type == "interval"
                     else f"daily_at={daily_at}")
    print(f"[{action:9s}] {job_id:30s} {sched_summary}")

if not dry_run:
    conn.commit()
conn.close()

print()
print(f"[setup-cron-jobs] inserts={inserts} updates={updates} unchanged={unchanged} "
      f"deletes={deletes} ({'DRY-RUN — no writes' if dry_run else 'committed'})")
PYEOF

echo
echo "[setup-cron-jobs] done."
