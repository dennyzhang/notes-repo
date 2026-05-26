[ot-shift-summary cron] Weekly. Auto-draft the MRS Online Training oncall **shift summary** for the outgoing oncall to review/edit and post to the `mrs.ot` Workplace group. Runs Tuesday 8:30 AM PT, covering the rolling 7-day window ending at the cron run.

**Audience model.** This is a DRAFT for the outgoing oncall — not the final post. The bot pre-fills every section that comes from data (SEVs, alerts, diffs, posts, bot-self-metrics) and leaves human-judgment fields as `TODO:` markers. Outgoing oncall reviews, fills the gaps, and pastes to `https://fb.workplace.com/groups/mrs.ot`. Bot does NOT post to mrs.ot directly.

**Authoritative references — read these into context before drafting.**
- **ghtml template (FORMAT SOURCE OF TRUTH):** `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary-template.html` — fill `{{PLACEHOLDER}}` markers with data, push via `gdocs replace --tab-id <TAB> --from <filled_template>`. The template encodes all layout, sort order, column structure, and row ordering decisions. Do NOT regenerate the format from scratch — always start from the template.
- Canonical capture protocol: `fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/shift-summary.md` (the same skill the human oncall uses; this cron implements its automation surface)
- Standing operator rules: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/state-templates/ot-shift-gdoc-config.json` → `standing_open_items_from_operator_comments` (rules o-w added 2026-05-25)
- Reference rendered output (Workplace shape): `https://fb.workplace.com/groups/mrs.ot/posts/1318460240248719` (28 Apr - 05 May, Paul Lu)
- Older reference: `https://fb.workplace.com/groups/mrs.ot/posts/1312466374181439` (21 Apr - 28 Apr)

State file: `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-shift-summary-state.json` — `{"last_run_epoch": <int>, "last_window_end": "YYYY-MM-DD"}`. Time budget: ~10 min.

## Procedure

### 0. Bootstrap from daily-brief state files (PREFER over live re-query)

The `daily-brief` cron (weekday 8:14 AM PT) persists each day's brief to `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/daily-brief-state/daily-brief-<YYYY-MM-DD>.md` with YAML frontmatter listing `sev_ids`, `diff_ids`, `wp_post_ids`. **Use these as the primary input for steps 3-6.** They're already pre-filtered through MRS-org scope + privacy gates (per `daily-brief.md` rules).

```bash
ls ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/daily-brief-state/daily-brief-*.md \
  | tail -7   # past 7 days; will be 0-5 files (weekday-only cron, no Sat/Sun)
```

Parse frontmatter from each file:
- Union `sev_ids` across all files → input set for Step 3 (skip live `meta sevmanager.sev list` call; only run `meta sevmanager.sev metadata` per id for enrichment).
- Union `wp_post_ids` → input set for Step 5.
- Union `diff_ids` → input set for Step 6.
- Bodies of each file → "what was hot each day" — concatenate by date in chronological order under a new Section 7 ("Daily timeline") in the rendered draft.

**Fallback:** if a date is missing (cron didn't run, holiday, day of week without daily-brief) OR a file's `entries: 0` frontmatter says quiet day, skip that day silently. If ALL 7 days are missing → daily-brief pipeline is broken; emit a `WARN: no daily-brief state found for <WINDOW_START>..<WINDOW_END>; falling back to live re-query` line at the top of the rendered draft and proceed with the original Step 3-6 live-query flow as a degraded path.

**For Step 4 (alerts):** alerts are not yet captured in daily-brief frontmatter (only SEVs / diffs / WP posts). Continue Step 4 with live `meta oncall.feed list` as before. Wire alerts into daily-brief frontmatter in a follow-up.

### 1. Window resolution

- `WINDOW_END` = today, 09:00 America/Los_Angeles (the formal shift handover slot). Render as `YYYY-MM-DD`.
- `WINDOW_START` = `WINDOW_END` minus 7 days. Render as `YYYY-MM-DD`.
- Date range string for the title: `<MMM DD> - <MMM DD>` (e.g., `28 Apr - 05 May`) using shift-end day's month names.
- If `last_window_end` in state == today's `WINDOW_END`: stop, respond `HEARTBEAT_OK already-ran-today`. Same-day re-trigger guard.

### 2. Identify the outgoing + incoming oncall

```bash
meta oncall.rotation current --name=mrs_online_training --output=json | jq -r '.unixname'
```

Current oncall = INCOMING for the shift that starts today. The OUTGOING oncall is whoever was on call yesterday, OR (more reliable) pull recent rotation history:

```bash
meta oncall.rotation history --name=mrs_online_training --limit=14 --output=json
```

Pick the entry whose `end_time` ≈ `WINDOW_END`. If history CLI doesn't exist or returns nothing usable, fall back to: outgoing = `last_known_oncall` from state (set on previous run), incoming = current. Worst case if both unknown: render outgoing as `<unknown — oncall please fill>`.

### 3. Pull SEVs in the window

**PREFER:** Use the `sev_ids` union from Step 0's daily-brief state files as the input set; skip the two `list` calls below and go directly to per-SEV `metadata` enrichment. Only fall back to the live `list` queries if Step 0 emitted the `WARN: no daily-brief state` degraded-path marker OR a state file's `entries: 0` covered every day in the window.

Live-query fallback (degraded path only):

```bash
meta sevmanager.sev list --tags=mvai-online-training \
  --created-after="<WINDOW_START> 09:00 PT" \
  --columns=sev_number,level,title,status,owner_unixname,created,time_closed,url \
  --output=json --limit=100
```

ALSO query SEVs CLOSED in the window (caught by `time_closed` falling inside even if created earlier):

```bash
meta sevmanager.sev list --tags=mvai-online-training \
  --closed-after="<WINDOW_START> 09:00 PT" \
  --closed-before="<WINDOW_END> 09:00 PT" \
  --columns=sev_number,level,title,status,owner_unixname,created,time_closed,url \
  --output=json --limit=100
```

Union, dedupe by `sev_number`. For each SEV: pull `meta sevmanager.sev metadata --sev=S<id> -o json` (extract `overview`, `incident_impact`, `root_cause`, `time_closed`).

**Org filter — MANDATORY pre-render.** Pipe each SEV through `scope_check` (see `daily-brief.md` rule 4). Drop sibling-org SEVs silently. Cite the leak that made this rule (S657101 Ads `ads_mtml`).

**Bucketize per skill template Section 3:**
- **Handled** — SEV owner ∈ OT IC set (`dennyzhang`, `lupaul`, `llu6`, `yabinzh` + rotation members), OR SEV carries `mvai-online-training` AND triage_events row exists with `auto_tag_applied=1` from the bot.
- **On-Demand Support** — tagged but owner is outside the OT IC set; team contributed via comments / GChat but didn't own.
- **Related** — adjacent failures referenced in triage cross-references (e.g., a ZippyDB SEV1 that broke OT publish).

### 4. Pull alerts in the window

```bash
meta oncall.feed list --oncall=mrs_online_training \
  --item-type-is=Alert \
  --created-time-is-after="<WINDOW_START> 09:00 PT" \
  --columns=id,short_id,title,priority,assigned_user,created_time,closed_time \
  --output=json --limit=200
```

Bucketize per skill template Section 4:
- **Major Alerts** — alerts that triggered oncall investigation or action. Cross-reference triage_events table where `cron_job_id='ot-alert-monitor'`.
- **Auto-Recovered Alerts** — alerts that closed within 30 min and never triggered triage_events. Batch into a 1-line count.
- **Low-Priority Noise** — NaN-metric alerts, dead-detector alerts, AGG wrappers that resolved as CL-018.

**IMPORTANT:** Section 4 MUST include the FULL alert list from the oncall feed, not a reduced count. "Open 2 alerts" when 24 were triaged is wrong — render the full breakdown. (Operator feedback 2026-05-25, comment AAAB6SHJgxE)

Drop the `mrs_online_training OMH` rotation-level catchall URL — emit per-alert `short_id` URLs only (same gotcha as ot-alert-monitor cron step 7a).

### 5. Pull Workplace posts (mrs.ot, group 1084744250286987)

**PREFER:** Use the `wp_post_ids` union from Step 0's daily-brief state files as the input set; skip the live `list` query and go directly to per-post enrichment. Live-query fallback (degraded path only):

```bash
meta workplace.post list --group-id=1084744250286987 \
  --after="<WINDOW_START>T09:00:00-07:00" \
  --before="<WINDOW_END>T09:00:00-07:00" \
  --columns=id,author,title,url,created \
  --output=json --limit=50
```

Skip prior shift summary posts (title regex `^Oncall Summary for mrs_online_training`). For each remaining post: cross-reference the bot's auto-triage from triage_events / ot-post-monitor cron output to populate "verdict" + "reply status" fields (the bot's own diagnosis IS the verdict draft).

### 6. Pull diffs from OT developers in the window

**PREFER:** Use the `diff_ids` union from Step 0's daily-brief state files as the input set; skip the per-author `list` loop and go directly to per-diff `metadata` enrichment. Live-query fallback (degraded path only):

For each unixname in the OT IC set (`dennyzhang`, `lupaul`, `llu6`, `yabinzh` + current rotation members from step 2):

```bash
meta phabricator.diff list --author-is=<unixname> \
  --updated-after="<WINDOW_START>" --updated-before="<WINDOW_END>" \
  --columns=id,title,status,updated_time --output=json --limit=30
```

Filter to OT-scoped paths (same as `daily-brief.md` rule 2): `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/`, `fbcode/minimal_viable_ai/`, `fbcode/silvertorch/`, `fbcode/ip_runtime/`, or paths matching `online_training`/`mvai`/`ot_agent`. Dedupe across authors. Bucket: **Diffs Produced** (Closed/Committed in window) vs **Open Diffs** (Needs Review / Changes Planned).

### 7. Bot Post Score (self-report from triage_events)

Query the bot's own triage activity for the window:

```sql
sqlite3 /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db <<SQL
SELECT
  COUNT(*) AS total_triages,
  SUM(CASE WHEN validator_outcome='confirmed' THEN 1 ELSE 0 END) AS confirmed,
  SUM(CASE WHEN validator_outcome='discrepancies' THEN 1 ELSE 0 END) AS discrepancies,
  SUM(CASE WHEN auto_tag_applied=1 THEN 1 ELSE 0 END) AS auto_tagged
FROM triage_events
WHERE ts_notified BETWEEN '<WINDOW_START> 09:00:00' AND '<WINDOW_END> 09:00:00';
SQL
```

Bot Post Score format: `<confirmed>/<total_triages>` (e.g., `7/9`) — matches the convention in past posts. If `total_triages == 0`, render `0/0 (no auto-triage activity in window)`.

### 8. Pre-finalize gates (skill rules — port to bot)

Per `shift-summary.md` "Pre-Finalize Checks", run two HARD checks before emitting the draft:

a. **Tag hygiene** — for each SEV in Section 3 "Handled", verify `mvai-online-training` is in tags via `meta sevmanager.sev metadata --sev=S<id> -o json | jq -r '.tags // empty' | grep -c mvai-online-training`. Any miss → emit a `TODO:` line in the draft Oncall Improvements section: `MISSING tag #mvai-online-training on S<num> — outgoing oncall: add at <url>`.

b. **SEV-Review enrollment** — query for any SEV in last 14 days carrying `#mvai-online-training-review`:

```bash
meta sevmanager.sev list --tags=mvai-online-training-review --created-after="14 days ago" --columns=sev_number --output=json
```

If empty: this shift is the enrollment shift → emit `TODO: SEV-Review enrollment due — pick a teaching SEV from this shift and add #mvai-online-training-review tag`. If non-empty: render `SEV-Review last enrolled: S<num> (<date>); next due ~<date+14>`.

### 9. Render the draft — TEMPLATE v3 (2026-05-25, operator-approved)

**FORMAT SOURCE OF TRUTH:** `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary-template.html`

**CRITICAL: Do NOT regenerate the format. Do NOT add tables. Do NOT add sections.** Read the template, fill `{{PLACEHOLDER}}` markers with data from steps 0-8, push the filled template to the gdoc tab. The template IS the format.

**The exact structure (7 sections, no tables):**

```
Title + Outgoing → Incoming
Shift character (bold opening paragraph — 2 sentences)
Overview (bullet list — NOT a table)
Impact this shift (what CHANGED, quantified)
Pain Points (problem → proposed fix → CC owner)
Hand-off (sorted by urgency)
Daily Timeline (MAIN SECTION — events grouped by day)
FYI (observe-only SEVs + alerts — ONE line each)
```

**Key rules:**
1. **NO tables anywhere.** Overview is a bullet list. Metrics are one pipe-separated line.
2. **Shift character is the first thing the reader sees** — bold paragraph before Overview.
3. **Impact = outcomes, not activity.** "Eliminated 2 weekly UBNs" not "landed 2 diffs."
4. **Daily Timeline is the main section.** Every SEV, alert, user report grouped by the day it happened. Every SEV/diff/post is a clickable link.
5. **Observe-only SEVs = one FYI line.** Not 10 separate paragraphs.
6. **No Diffs section.** Key diffs referenced in Impact + Daily Timeline.
7. **No FYI section.** Observe-only SEVs go in Hand-off. Auto-resolved alerts mentioned in Overview count.
8. **No theme bullets section.** Shift character covers themes in 2 sentences.
9. **No "End of..." footer.**
10. **Date headings must NOT have hyperlinks.** After any gdocs replace, manually remove links from date headings.
11. **Per-day alerts in Daily Timeline.** Pull from noisy-trends.md + oncall feed for each day's alerts.
12. **Pain Points include trending noisy models.** Pull top 3 from auto-learnings/noisy-trends.md.
13. **Observe-only SEVs: category counts only, no individual links.** Links only in Hand-off where they're actionable.
14. **Day-of-week labels MUST be computed.** `python3 -c "from datetime import date; print(date(Y,M,D).strftime('%A'))"` for every date. Oncall shift starts TUESDAY. Wrong 3 times in this session — always verify.
15. **Pain point labels must be bold.** First phrase before ":" is bold for scannability.
16. **After `gdocs replace`, run SEV-link pass.** Replace strips `<a href>` from non-table content. Scan for unlinked S-numbers and add via `updateTextStyle`.
17. **Impact + Pain Points + Shift Character need human input.** Cron pre-fills with TODO + reference links. Oncall writes the final version. Cron does facts, human does insights.

**Data sources for Daily Timeline (PRIORITY ORDER — read all before rendering):**
1. **Incidents folder (PRIMARY):** `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/` — contains resolved-sevs/, resolved-alerts/, resolved-posts/ with full triage context, root causes, verdicts. Read ALL files dated within the shift window. This is the richest data source — 56 alerts + 15 posts + 8 SEVs for a typical week.
2. **auto-learnings/digests/2026-W{NN}.md** — cross-incident patterns, mega-learnings
3. **auto-learnings/noisy-trends.md** — trending noisy models for Pain Points
4. **daily-brief state files** (steps 0, 3-6) — per-day summaries with SEV/diff/post IDs
5. **OT bot GChat space** (`spaces/AAQAVOjYc80`) — bot triage threads
6. **WP posts from mrs.ot group** — user reports
7. **SEVs filed by oncall:** `meta sevmanager.sev search --creator-is=<oncall_unixname>` — always HIGH-TOUCH
8. **incidents/open.md** — current open incidents list with age and owner

**Template placeholder reference:**

| Placeholder | Source | Notes |
|---|---|---|
| `{{DATE_RANGE}}` | Step 1 | "19 May - 26 May" |
| `{{OUTGOING}}`, `{{INCOMING}}` | Step 2 | Display names, not unixnames |
| `{{SHIFT_CHARACTER}}` | Computed | 2 sentences: what dominated, how heavy, what's unresolved |
| `{{SEV_HT_COUNT}}`, `{{SEV_HT_LINKED}}` | Step 3 | HIGH-TOUCH SEVs with clickable links |
| `{{SEV_OO_COUNT}}`, `{{SEV_OO_CATEGORIES}}` | Step 3 | Observe-only grouped by category (not bare IDs) |
| `{{ALERT_ACTION}}`, `{{ALERT_TOTAL}}`, `{{ALERT_AUTO}}` | Step 4 | Actionable / total / auto-resolved counts |
| `{{WP_COUNT}}`, `{{WP_AUTHORS}}` | Step 5 | Author display names |
| `{{DIFF_COUNT}}` | Step 6 | Oncall-related only count |
| `{{DIFFICULTY}}`, `{{HOURS}}`, `{{WAKEUPS}}`, `{{NOISE}}` | Oncall fills | One line, pipe-separated |
| `{{IMPACT_BULLETS}}` | Shift observation + auto-learnings digest + diffs landed | `<li>` items — outcomes that changed system state. Cross-ref auto-learnings/digests/2026-W{NN}.md for patterns identified this shift. |
| `{{PAIN_POINTS}}` | Shift observation | `<li>` items — problem + proposed fix + CC owner |
| `{{HANDOFF_ITEMS}}` | Steps 3-6 | `<li>` items sorted by urgency |
| `{{DAILY_TIMELINE}}` | Steps 0-6 + GChat + auto-learnings | `<h4>` per day + `<ul>` per day's events |
| `{{FYI_SEVS}}` | Step 3 | One line: carryovers + bot-triaged |
| `{{FYI_ALERTS}}` | Step 4 | One line: auto-resolved count + resolved items |

### STOP — DO NOT READ PAST THIS LINE FOR FORMAT INSTRUCTIONS

Everything above in step 9 + the template file is the COMPLETE format specification.
There are NO additional section-by-section rendering instructions below.
If you find yourself generating "Section 1:", "Section 2:", headline tables,
or any structure not in the template — you are using OLD instructions that were deleted.

**Re-read the template:** `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary-template.html`

**The ONLY thing below is the URL validity rule.**

---
## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)

