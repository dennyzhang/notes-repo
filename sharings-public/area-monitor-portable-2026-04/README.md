# Area Monitor — Portable Claude Code Workflow

A nightly intelligence gathering system that scans your organizational neighborhood — peer activity, group posts, incidents — and synthesizes a daily digest answering: **"What happened around me that I should know about, and what should I do about it?"**

## What It Does

Every night, the area monitor:
1. **Collects** peer diffs/PRs, group posts, and incident activity via your company's search APIs
2. **Synthesizes** raw data through Claude into a structured digest with actionable insights
3. **Publishes** to a Google Doc (preserving previous days) and a local markdown cache
4. **Maintains** a rolling skill scout that tracks new techniques from community sources

## Architecture

```
Crontab (3:00 AM daily)
  │
  ├─ STEP 1: Parallel Data Collection
  │   ├─ Job A (Org): peer diffs, group posts, incidents
  │   └─ Job B (Skill): community posts, power user activity
  │
  ├─ STEP 2: Parallel Claude Synthesis
  │   ├─ claude -p (org prompt + template + raw data) → org digest
  │   └─ claude -p (skill prompt + template + raw data) → skill digest
  │
  ├─ STEP 3: Google Doc Push (optional)
  │   └─ Smart content management: REPLACE today / PREPEND new day / FRESH insert
  │
  └─ STEP 4: Local Cache + Maintenance
      ├─ cache/AREA-MONITOR.md (org digest)
      ├─ cache/UPSTREAM-TODAY.md (skill delta)
      └─ config update (last_scan timestamp)
```

## Quick Start

1. Copy these files to your Claude workspace:
   - `area-monitor.sh` → `scripts/`
   - `area-monitor-config.json` → `config/`
   - `area-monitor-template.md` → `templates/`

2. Edit `config/area-monitor-config.json`:
   - Replace peers with YOUR manager, TL, teammates
   - Replace group IDs with YOUR relevant groups
   - Replace expertise domains with YOUR focus areas

3. Test manually:
   ```bash
   bash scripts/area-monitor.sh
   ```

4. Add to crontab:
   ```
   0 3 * * * bash ~/work/claude/scripts/area-monitor.sh >> ~/logs/area-monitor.log 2>&1
   ```

## Customization Guide

### Peer Circles
Organize people by their relationship to you:
- **management**: Your EM, TLs, skip manager
- **team**: Immediate teammates
- **leadership**: Directors, VPs (no reach-out suggestions generated)
- **adjacent**: People in related teams you collaborate with
- **collaborator**: Cross-team partners

### Data Sources
The script uses generic search patterns. Adapt the `collect_data()` function to your company's tools:
- **GitHub/GitLab**: Replace `search_peers_activity` with your PR API
- **Slack**: Replace group post fetching with Slack API calls
- **PagerDuty**: Replace incident fetching with your incident system

### Output Sections
The template has 5 sections — customize by editing `area-monitor-template.md`:
1. **Org Pulse** — org-level signals (leadership decisions, cross-team impact)
2. **Opportunities to Act** — synthesized actionable items
3. **Team Activity** — per-person activity with suggested messages
4. **Leadership Activity** — skip-level visibility (no reach-out for VPs)
5. **Incident Radar** — relevant incidents from your oncall teams

## Files

| File | Purpose |
|------|---------|
| `area-monitor.sh` | Main script — data collection, synthesis, output |
| `area-monitor-config.json` | Who to watch, where to look, what domains to care about |
| `area-monitor-template.md` | Fixed template Claude fills in (ensures consistent output) |

## Requirements

- Claude Code CLI (`claude` command available)
- `jq` for JSON parsing
- Your company's search/API tools (adapt `collect_data()`)
- Optional: Google Docs CLI for doc publishing
