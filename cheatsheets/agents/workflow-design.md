# Workflow Design Cheatsheet

Rules for building reliable hooks, cron scripts, and automations. Load before creating any new workflow.

## 6 Design Rules

### 1. Session Isolation
All temp files, sentinels, and state MUST be scoped by session ID or entity ID. Never use fixed global `/tmp/` paths for state that belongs to one session.
- Pattern: `/tmp/claude-{purpose}-${SID_SHORT}/` for session state
- Cron fallback: `/tmp/claude-{purpose}-cron/` for sessions without `CLAUDE_CODE_CURRENT_SESSION_ID`
- Derive `SID_SHORT`: `echo "$CLAUDE_CODE_CURRENT_SESSION_ID" | md5sum | cut -c1-8`
- **Why**: Multiple Claude sessions run in parallel (interactive + cron + background agents). Unscoped files cause cross-session stomping.

### 2. Heartbeat Integrity
Write heartbeat/success signals ONLY on the success path. Never unconditionally.
- **Wrong**: Process → heartbeat → exit (heartbeat writes even on failure)
- **Right**: Process → if success → heartbeat; else → alert
- **Why**: A script that writes "healthy" then fails looks healthy to monitoring. Silent failures compound.

### 3. Dedup Before Append
Any file written by multiple sessions needs dedup + file locking before appending.
- Use `file_lock` / `file_unlock` from `scripts/file-lock.sh` for atomicity
- Check for existing content before appending (first 40+ chars of key field)
- Insert into the correct section (not append at EOF where it's invisible to section-based checks)
- **Why**: Without dedup, the same item gets added on every cron run. Without locking, concurrent writes corrupt the file.

### 4. Fail-Fast on Dependencies
When a shared dependency (gmux, network, API) is down, fail with an alert immediately. Don't run expensive work (LLM, network calls) then fail at the write step.
- Check dependencies BEFORE the main work phase
- If dependency is down: `cron_alert` + exit, or skip with warning
- **Wrong**: Run 30-min LLM → try gdocs write → fail silently
- **Right**: Check gmux health → unhealthy → alert → exit

### 5. Inline Tracking
Track significant work AS it happens, not at session end. Session crashes, context compaction, and missed saves lose anything deferred.
- Tasks >10 min → write to task buffer + FOLLOWUPS/TASKS immediately
- `/my-save` step 6e is the safety net, not the primary mechanism
- **Why**: If the session dies before `/my-save`, all deferred tracking is lost.

### 6. TTL on All State
Every sentinel, cache, and marker file needs an expiry mechanism. State without TTL becomes stale truth.
- Sentinels: 4-hour TTL (check age before trusting)
- Preflight markers: cleared on code change (`sl amend/commit`)
- Alerts: timestamp updated on recurrence (not frozen at first occurrence)
- Caches: checked for freshness before use (age > threshold → warn or skip)
- **Why**: A sentinel from yesterday's session can trick today's session into skipping a required step.

## Enforcement Layer Model

When adding a new rule, pick the right enforcement level:

| Level | Mechanism | When to Use | Example |
|-------|-----------|-------------|---------|
| **HARD BLOCK** | PreToolUse hook, `exit 1` | Action is NEVER valid | `gdocs replace`, `gchat send` |
| **CONDITIONAL BLOCK** | PreToolUse hook, check state first | Action valid only with preconditions | `gdocs apply` (blocked if comments exist) |
| **SOFT BLOCK** | Prerequisite sentinel | Must read/do X before Y | Read cheatsheet before gdocs operation |
| **POST-VERIFY** | PostToolUse hook, async | Check outcome, warn on violation | Heading inheritance, style leaks |
| **COACHING** | Nightly cron signal | Pattern detection over time | Scope sprawl, stale follow-ups |

**Promotion criteria**: If a POST-VERIFY fires 2+ times on the same violation and the violation is mechanically checkable → promote to CONDITIONAL BLOCK or HARD BLOCK.

### Graduated Enforcement Rollout

New rules follow this lifecycle:

```
Week 1-2: POST-VERIFY (warn only, log to enforcement-metrics.csv)
    ↓ fires 3+ times on real violations?
Week 3+:  CONDITIONAL BLOCK or HARD BLOCK (promote)
    ↓ fires 0 times in 30 days?
Review:   Remove or demote (dead rule)
    ↓ >50% false positive rate?
Review:   Demote to POST-VERIFY or fix the detection logic
```

**Rules:**
- Never deploy a new HARD BLOCK without 2 weeks of POST-VERIFY data first
- Exception: catastrophic actions (data destruction) can start as HARD BLOCK
- All enforcement events log to `~/logs/enforcement-metrics.csv` via `enforcement-log.sh`
- Weekly review: which rules fire most? Which are false-positive? Which are dead?

### Enforcement Metrics

Every hook logs blocks and warnings to `~/logs/enforcement-metrics.csv`:
```
timestamp,session_id,rule,action,result,details
```

Use `enforcement-log.sh` to log:
```bash
source scripts/enforcement-log.sh
log_enforcement "rule-name" "action-attempted" "blocked|warned|passed" "details"
```

### Architecture Map

For how all pieces connect (hooks → scripts → state → commands), see `system/ARCHITECTURE.md`.

## Cron Script Conventions

1. Source `cron-alert.sh` for `cron_alert`, `cron_alert_clear`, `load_cheatsheet`, `create_preflight_sentinels`
2. Use `cron_run` wrapper from crontab (provides timeout + retry + alerting)
3. Lock file via `cron_preflight` (prevents overlapping runs)
4. Write heartbeat ONLY on success path (see Rule 2)
5. Log to `~/logs/{script-name}.log` with `>>` append
6. Register in `setup-claude.sh` crontab block (or entry is lost on migration)
7. Inject cheatsheets via `load_cheatsheet` when spawning `claude -p` sessions
8. Create preflight sentinels via `create_preflight_sentinels` before sessions that may `jf submit`

## Observer / Consumer Naming Convention

When N crons need the same expensive data (GChat history, diff metadata, oncall
roster, etc.), build ONE **observer** that fetches + caches and N
**consumers** that read the cache. This amortizes API cost, prevents config
drift between fetchers, and makes the dependency graph visible from filenames
alone.

**Naming:**
- Observer: `cron-<domain>-observer.sh` (e.g., `cron-gchat-observer.sh`)
- Consumers: `cron-<domain>-consumer-<purpose>.sh` (e.g.,
  `cron-gchat-consumer-digest.sh`, `cron-gchat-consumer-learnings.sh`)

**Cache contract:**
- Observer writes to `state/<domain>-cache/<entity>/...` with a `MANIFEST.json`
  per entity and a top-level `INDEX.json` listing every cached entity.
- Cache files are markdown (or JSON) with a YAML frontmatter so consumers
  can grep/parse without re-fetching.
- Observer schedule must be ≥ 2× faster than the fastest consumer schedule
  (so consumers always see fresh-ish data without waiting on a fresh fetch).

**Consumer rules:**
- Consumers NEVER fetch the source directly — they read the cache.
- Consumer fails loud if cache is missing or stale (older than `MAX_CACHE_AGE`).
- Adding a new consumer = create a new `cron-<domain>-consumer-<name>.sh`,
  register it in `setup-claude.sh`. The observer doesn't change.

**Reference:** `cron-gchat-observer.sh` (the canonical example) +
`state/gchat-cache/` (the cache layout). Built 2026-06-17.

## Hook Conventions

1. Fast exit first: `case` statement to skip irrelevant commands
2. PreToolUse hooks: synchronous, must be fast (<100ms). Blocking = `exit 1` or `exit 2`
3. PostToolUse hooks: use `"async": true` for anything that calls external APIs
4. Session-scope all marker directories using `CLAUDE_CODE_CURRENT_SESSION_ID`
5. Never `2>/dev/null` on commands that can meaningfully fail
6. Register in `.claude/settings.json` — hooks not in settings don't fire

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Global `/tmp/claude-preflight/` for sentinels | Scoped `/tmp/claude-preflight-${SID_SHORT}/` |
| Heartbeat writes after both success and failure | Heartbeat only inside `if [ $exit -eq 0 ]` |
| `cat >> FOLLOWUPS.md` without lock or dedup | `file_lock` + dedup check + insert into section |
| `load_cheatsheet` writes global sentinel | Writes to scoped dir + cron fallback dir |
| Check dependency after expensive work | Check dependency FIRST, fail-fast if down |
| Track tasks at session end only | Track inline during task, save as safety net |
| Sentinel with no TTL | Always check `age > MAX_AGE` before trusting |
| Fixed timeout for watch/poll workflows | Idle-based timeout (stop when no activity for N hours) |
| Cleanup cron `rm -rf`s big/CoW-heavy trees → exceeds `cron_run` timeout → killed before heartbeat → silently never drains its backlog | Delete the big LEAF files first (`find … -size +500M -delete` — a fast metadata unlink), THEN `rm -rf` the now-cheap dirs. Verified 2026-06-13: `rm -rf` of /tmp/.tmp* with 50-60GB CoW history.jsonl timed out at 300s every run for 12 days; purge-files-first dropped it to <30s |
| Assuming a cron is healthy because its crontab entry exists | A timing-out cron leaves a STALE heartbeat (never reaches the success path). Heartbeat-age, not crontab presence, is the liveness signal — check `state/heartbeats/` mtime |
| [OPS] Check D98639333 CI (umqv test mock fix, overdue 1 day). If green, land ... | [OPS] Denny: Check D98639333 CI today (Mar 30, EOD). If green, land before mi... |
| N/A | "Johnny's team owns X — ask if the Y rollout landed; reference his comment on... |
| N/A | "STALE TASKS — Denny assigns or parks T260201816/T260201838/T260201885. Due A... |
| N/A | Either update with new counts or replace with "SCOPE unchanged since Mar 31 —... |
| N/A | "Rate returned to baseline (X% at HH:MM Mar 30) — confirmed auto-recovered. C... |
| N/A | "Do NOT restart without clearing ALL 6 channels first. Owner: [oncall_team]. ... |

## Reliability Patterns (Source: 12-Factor App + Google SRE adapted for automation)

### Observability Triad

Every workflow must be observable through three lenses:

| Lens | Implementation | What it answers |
|------|---------------|----------------|
| **Health** | Heartbeat file with timestamp | "Is it running?" |
| **Progress** | Log output with step markers | "What is it doing right now?" |
| **Outcome** | Alert on failure, metric on success | "Did it work?" |

A workflow with health but no outcome monitoring (heartbeat writes, but nobody checks if the output is correct) is the most dangerous — it looks alive but produces garbage silently.

### Retry Strategy

| Error type | Strategy | Example |
|-----------|----------|---------|
| Transient (DNS, timeout, rate limit) | Retry 3x with exponential backoff | `auto-retry-transient.sh` does this |
| Configuration (bad path, missing file) | Fail immediately, alert | No retry — fix the config |
| Dependency (service down) | Fail-fast, alert, skip this run | `ensure_gmux_healthy` pattern |
| Data (corrupt input) | Log, skip item, continue batch | Don't let one bad record kill the run |

### Graceful Degradation

When a non-critical step fails, the workflow should continue and report partial results:
- **Wrong**: Script exits on first error (`set -e` without handlers)
- **Right**: Critical steps use `|| cron_alert`, non-critical steps use `|| echo "[WARN]"`
- **Pattern**: Track a `$status` variable, write heartbeat only if `$status == "success"` or `"partial"`

_Last updated: 2026-05-12. Maintainer: dennyzhang._
