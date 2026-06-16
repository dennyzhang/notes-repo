[ot-shift-summary cron] **Daily 8:30 AM PT.** Maintains the MRS Online Training oncall **shift summary** gdoc. Two behaviors by weekday: **TUESDAY = shift close-out** — full draft on a NEW tab for the outgoing oncall to review/edit and post to the `mrs.ot` Workplace group (the original weekly behavior). **WED–MON = comment-safe MID-SHIFT incremental refresh** of the *current* shift's tab in place (append the just-completed day + refresh header/day-count/open-items) so the doc never goes stale between Tuesdays (operator 2026-06-05 `7GKCIVDMtz8`: "do a daily incremental update for oncall shift"). Shift window is always Tue→Tue; daily incremental scopes data Tue→now.

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

### 0a. ADDRESS OPEN OPERATOR COMMENTS FIRST — before any new-day content (HARD, 2026-06-14)

**Operator rule:** *"always check and address open comments, before updating new days' content."* The shift doc is steered by the operator's inline comments; adding new days while their feedback sits unaddressed buries it and forces them to re-flag the same thing (font, missing posts, etc. — happened repeatedly 2026-06-13). So on EVERY run, BEFORE composing/inserting any new-day content (Steps 1+, render, insert-html):

1. **List open comments on the current tab.** `gdocs comments list <DOC_ID> --untrusted-authors-mode --no-daemon --json` (fetch → `--no-daemon` per the daemon nuance; `--json` is verified-working for this command, used live 2026-06-13 — output shape `{"data":{"comments":[{id, content, resolved, author, replies:[...]}]}}`). Filter to `resolved != true`. (Comments are doc-wide; focus on those anchored in / about the current shift tab.) **PARSE-FAIL GUARD (do NOT let the gate become dead code): if the list call errors or the JSON does not parse into a comments array, ABORT step 0a with a loud error and do NOT proceed to new-day content — never silently treat an unparseable result as "no open comments" (that would skip the entire gate).**
2. **For EACH open comment, ACT then reply — do not skip, do not just acknowledge:**
   - **DEDUP GATE (mandatory — prevents duplicate-reply spam every run):** the bot NEVER resolves, so an addressed comment stays `resolved=false` forever. Before doing anything, inspect the comment's `replies[]`: **if the LAST reply is already a `[myclaw-ot bot reply]` AND the comment has not been updated/re-commented since that reply, SKIP this comment entirely (no re-edit, no re-reply)** — it is already addressed and waiting on the operator to resolve or re-engage. Only ACT+reply when there is NO prior `[myclaw-ot bot reply]`, OR the operator added a newer reply/edit after the last bot reply.
   - Apply the requested change to the doc where it is doable (content fix, ordering, missing item, wording). Use comment-safe edits only (`gdocs content find-replace` / `batch-update`; NEVER full-replace a commented tab). Writes go via the DAEMON (not `--no-daemon`) per the nuance.
   - Reply via `gdocs comments reply <DOC_ID> <COMMENT_ID> "[myclaw-ot bot reply] <what was done / why deferred>" --untrusted-authors-mode` (daemon path). **NEVER resolve** — the operator resolves.
   - If a comment needs a code/cron change (not a one-off doc edit), make the durable fix OR file a deduped `[OT auto-fix]` task and say so in the reply (e.g. the font normalizer T275803195, the WP-post backfill T275803389).
3. **Gate:** only after every open comment has an action + a `[myclaw-ot bot reply]` (or a logged deferral with a task) → proceed to Steps 1+ and the new-day content. If a comment genuinely can't be actioned this run, the reply MUST say why + what's tracking it — never silently move on.
4. This step is itself comment-driven, so it compounds: the operator's feedback is applied every run instead of re-surfacing. (Generalizes the one-off backfills/font fixes from 2026-06-13 into a standing comments-first discipline.)

### 1. Window resolution

- **The shift window is ALWAYS Tuesday → Tuesday** — oncall rotates Tue 09:00 PT (operator comments AAAB8HXNZA8 + AAAB7ndcDq4 "start with Tue"). NEVER a rolling today-minus-7 window (that makes a mid-shift Monday run show Mon→Mon, which is wrong).
- `SHIFT_START` = the most recent Tuesday at 09:00 America/Los_Angeles (= today if today IS Tuesday). `SHIFT_END` = `SHIFT_START` + 7 days (next Tuesday 09:00).
- `WINDOW_START` = `SHIFT_START`. `WINDOW_END` = `SHIFT_END` on the final (Tuesday) run; on a MID-SHIFT run gather data through `now`, but the **title still spans the full Tue→Tue shift**.
- Date-range string for the title: `<MMM DD> - <MMM DD>` = `SHIFT_START` → `SHIFT_END` (e.g. `26 May - 2 Jun`), month names from each boundary. Mid-shift appends "(mid-shift, <day> ~HH:MM PT)".
- Same-day guard: if `last_window_end` == `SHIFT_END` AND this is not a mid-shift refresh → stop, respond `HEARTBEAT_OK {status: "already-ran-today"}`.

### 2. Identify the outgoing + incoming oncall — QUERY THE ONCALL TOOL, never infer (operator 2026-06-09 thread `3yt3GJLcH_k`)

The shift rotates today (Tue, ~11:00 PT). At cron time (08:30) the rotation has NOT flipped yet, so:
- **OUTGOING** = the oncall whose shift is ending = current holder until the 11:00 flip:
```bash
meta oncall.rotation current --name=mrs_online_training --output=json | jq -r '.unixname'
```
- **INCOMING** = the NEXT shift's oncall — pull it from the SCHEDULE. **NEVER assume "current = incoming"** — that exact heuristic rendered `Incoming → Paul Lu` on 2026-06-09 when the real incoming was Li Lu (operator caught it; lupaul/Paul Lu was the shift a week LATER — a one-slot off-by-one):
```bash
meta oncall.rotation schedule -r mrs_online_training --upcoming --limit=1 --columns=employee,start,end
```
The first upcoming entry's `employee` = INCOMING. (2026-06-09 ground truth: current=`dennyzhang` [outgoing], upcoming[0]=`llu6` [Li Lu, incoming], upcoming[1]=`lupaul` [Paul Lu, +1 week].)

Resolve unixname→display name via `meta people.resolve search -q <unixname> --limit=1`. Render `Outgoing → <name> | Incoming → <name>`. **Consistency gate (HARD):** the Daily Timeline's final "Handover" line MUST name the SAME incoming oncall as the header — if they disagree the header is wrong (the timeline is the schedule-derived ground truth). If the schedule CLI returns nothing, render incoming as `<unknown — oncall please confirm>`, NEVER a guess. Fallback for outgoing if `current` is empty: `last_known_oncall` from state.

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

**MANDATORY CROSS-CHECK against ot-sev-state (per L61, 2026-05-28).** Tag-based queries miss SEVs filed without the `mvai-online-training` tag (auto-detected or human-filed). Cross-reference `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-sev-state.json` `diagnosed_ids` for the window:

```bash
python3 -c "
import json
s = json.load(open('/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-sev-state.json'))
window_start_epoch = <WINDOW_START_EPOCH>
seen = [sid for sid, meta in s['diagnosed_ids'].items()
        if meta.get('added_epoch', 0) >= window_start_epoch]
print(f'ot-sev-state diagnosed {len(seen)} SEVs in window: {seen}')
"
```

For any SEV in `diagnosed_ids` but NOT in the tagged-list union: pull `meta sevmanager.sev metadata --sev=S<id>` and decide — if OT-scoped per title regex (`/OT[ -]?job|online[ -]?training|mvai|MAST|silvertorch|MRS/i`) OR if SEV gchat shows oncall robocall → ADD to candidate set + auto-tag via `meta sevmanager.sev update --sev=S<id> --add-tag=mvai-online-training` for future runs.

**Source of the L61 fix:** S668272 [IG Feed ESR] Sparse Streaming OT job failure, created 2026-05-26 21:51 PT, robocalled Denny. ot-sev-monitor missed first run (6-min indexing lag, see memory `sevmanager-indexing-lag`); SEV never received `mvai-online-training` tag; shift-summary Step 3 tag-query missed it; surfaced only after Denny's comment AAAB6WPRTi8. Double-miss = silent flywheel failure.

**Org filter — MANDATORY pre-render.** Pipe each SEV through `scope_check` (see `daily-brief.md` rule 4). Drop sibling-org SEVs silently. Cite the leak that made this rule (S657101 Ads `ads_mtml`).

**HARD SCOPE FILTER — drop `mrs_ml_release_oncall`-tagged SEVs (2026-05-28, thread `Rk8bGR2CQK8`).** Trunk-health workstream owns these end-to-end and has its own oncall; surfacing them in the OT shift summary creates noise + double-coverage confusion. For every candidate SEV (including those that pass the org filter above), query its tags via:

```bash
# canonical: meta sevmanager.sev list does NOT return per-SEV tag arrays; use a tag-membership query instead.
# Build the drop-set ONCE per window, then filter the candidate list in-memory:
DROP_SET=$(meta sevmanager.sev list --tags=mrs_ml_release_oncall \
  --created-after="<WINDOW_START> 09:00 PT" \
  --columns=sev_number --output=json --limit=200 | jq -r '.[].sev_number' | sort -u)
# Drop silently (same handling as sibling-org SEVs); log to internal pre-finalize gate count only.
```

Applies to ALL sections: §3 Daily timeline, §4 Top ongoing, §5 SEVs handled, Hand-off, Headline-numbers Detail cells. The filter is silent (no `TODO` line, no "dropped N" callout in the operator-facing draft). Internal `_pre_finalize_gates_log.json` records the dropped IDs for debugging. Sibling-org filter precedent (S657101) + new filter share the same drop-handling path.

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

### 4b. DATA-GENERATE the Daily Timeline + Page/Robocall audit (HARD — do NOT hand-type)

**The Daily Timeline and the `🚨 Critical alerts (robocalled this shift)` section are DATA-GENERATED, never hand-typed.** Hand-typing produced an incomplete laundry list and silently dropped robocalls (S668272 missed — thread `WhmgQGD72MQ`; major-alert activity missing — comment `AAAB8p7d1wg`). Run the canonical script:

```bash
bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/query-shift-oncall-events.sh \
  --start <WINDOW_START_EPOCH> --end <WINDOW_END_EPOCH> --json-only
# default window (no flags) = most recent Tue 09:00 PT → now; pass epochs to pin.
```

It emits one JSONL event per line (kind = `paged` | `alert` | `sev` | `active_now`) plus a final `{"summary":{...}}` line, each carrying a resolvable id + url + status + urgency, time-sorted. Source of each kind:
- **`paged`** — `meta oncall.notification list --oncall=mrs_online_training --escalating`. This is the TRUE page/robocall ledger (Escalation Service): critical alerts, SEVs, bananaphone (robocall), UBN. **This is what populates the `🚨 Critical alerts (robocalled this shift)` section** — every `kind=paged` row is a page; render its `id_disp` (S###/A###) + `url` + `text`. Validated to reproduce S670887 (in-shift) and S668272 (5/26) robocalls.
- **`alert`** — every major+critical alert notification in-window, with `status` (finished/acked = resolved, in_progress = open). Populates the per-day `🔔 alert:` timeline rows.
- **`sev`** — OT SEVs (tag `mvai-online-training`) created in-window, `status` Closed/Mitigated = resolved vs In Progress/Fix Ready = open.
- **`active_now`** — alerts ACTIVE right now (`meta monitoring.alert list --state-is=ACTIVE`).

**Render rules:** group `paged`/`alert`/`sev` events by their firing day (use the event `epoch` → weekday label computed from the date, NEVER hand-typed — see WEEKDAY rule below); within each day, time-sorted ascending. Drop pre-shift days. Emit each id as a clickable link from the event's `url` field verbatim (correct-by-construction via `tools/lib-url.sh` — never reconstruct). Cite counts from the `summary` line, not from narration (self-report rule). `[AGG]`-labelled rows have no inline title in the feed — render with their `url` + urgency/status, or follow the url for detail.

This REPLACES hand-typing the timeline. The script is pure bash + meta CLI (no gdoc writes). Activation after edits: operator runs `team_bot/setup-cron-jobs.sh`.

### 5. Pull Workplace posts (mrs.ot, group 1084744250286987)

**ALWAYS LIVE-QUERY (HARD).** Do NOT use daily-brief `wp_post_ids` as the primary input here — `daily-brief.md` filters posts to "high-confidence relevance to an active SEV or open question", which is too tight for shift-summary semantics (operator needs every user post in the window, including how-do-I and team-asks). Daily-brief frontmatter is REFERENCE-ONLY for posts; cross-check at end.

```bash
meta workplace.post list --group-id=1084744250286987 \
  --after="<WINDOW_START>T00:00:00-07:00" \
  --before="<WINDOW_END>T23:59:59-07:00" \
  --output=json --limit=50
```

Skip prior shift summary posts (title regex `^Oncall Summary for mrs_online_training`). For each remaining post: cross-reference the bot's auto-triage from triage_events + `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-monitor-state.json` (`processed_post_ids.<id>.notification_outcome`) to populate "verdict" + "reply status" fields (the bot's own diagnosis IS the verdict draft).

**MANDATORY CROSS-CHECK (per L60, 2026-05-28).** After the live query returns N posts, run:

```bash
python3 -c "
import json
s = json.load(open('/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-monitor-state.json'))
window_start_epoch = <WINDOW_START_EPOCH>
window_end_epoch = <WINDOW_END_EPOCH>
seen = [pid for pid, meta in s['processed_post_ids'].items()
        if window_start_epoch <= meta.get('added_epoch', 0) <= window_end_epoch]
print(f'ot-monitor-state saw {len(seen)} posts in window: {seen}')
"
```

If the live-query count != ot-monitor-state count, the section header MUST list the divergence explicitly (`⚠️ live:N, monitor:M — diff: <ids>`). Silent dropping a post is a flywheel failure per `[[tool-failure-fix-or-escalate]]`.

**Source of the L60 fix:** 2026-05-28 mid-shift snapshot for 5/26 → 5/28 shipped with "WP user reports: 0 new in window" while Hao Sha (1336024098492333, 5/27 11:11 PT, MC12 arm3 example age) and Sanket Karnik (1336148551813221, 5/27 15:01 PT, gflag add) were both in `ot-monitor-state.processed_post_ids`. Root cause: prior step 5 read daily-brief frontmatter `wp_post_ids: []` and skipped the live query. Denny flagged via comment AAAB6WPRTiI ("that's not true").

### 6. Pull diffs from OT developers in the window

**PREFER:** Use the `diff_ids` union from Step 0's daily-brief state files as the input set; skip the per-author `list` loop and go directly to per-diff `metadata` enrichment. Live-query fallback (degraded path only):

For each unixname in the OT IC set (`dennyzhang`, `lupaul`, `llu6`, `yabinzh` + current rotation members from step 2):

```bash
# NOTE: the time flag is --time-created-is-after / --last-updated-time-is-after
# (NOT --updated-after, which is rejected — verified 2026-06-06). Columns:
# number,title,status,created,updated.
meta phabricator.diff list --author-is=<unixname> \
  --last-updated-time-is-after="<WINDOW_START>" --last-updated-time-is-before="<WINDOW_END>" \
  --columns=number,title,status,created,updated --output=json --limit=30
```

Filter to OT-scoped paths (same as `daily-brief.md` rule 2): `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/`, `fbcode/minimal_viable_ai/`, `fbcode/silvertorch/`, `fbcode/ip_runtime/`, or paths matching `online_training`/`mvai`/`ot_agent`. Dedupe across authors. Bucket: **Diffs Produced** (Closed/Committed in window) vs **Open Diffs** (Needs Review / Changes Planned).

**EXCLUDE the bot's own auto-drafted self-improvement diffs (2026-06-05, operator: "the diffs will show up in oncall shift doc, right?").** The `ot-knowledge-distillation` diff-loop drafts `--draft` diffs to the agent's own repo (`mrs-ot-agent-src`), authored under `dennyzhang` — so the author+path filter above would otherwise bucket them under "Open Diffs" and leak bot plumbing into a HUMAN-oncall handoff doc, violating §4 "human signals only — no bot-autonomous-workflow content". **DROP any diff whose `tags` (from `meta phabricator.diff metadata --number=<n> -o json` → `.tags`) include `ot_bot_autodraft`** — the bot marks its autodrafts with that tag, NOT a title prefix (the title is human attention real estate, operator 2026-06-05). Safety net (in case the tag didn't apply): also drop diffs linked to the distillation task **`T259215482`** (`.tasks`). A human's OT-agent diff (no bot tag, not on T259215482) still counts. These bot diffs belong in the operator 1:1 where distillation already posts them, not the shift doc.

**ALSO pull SEV-FIX diffs linked to THIS SHIFT's SEVs, any author (2026-06-01 comment AAAB7ndcDqI "I doubt it's really 0").** The author-only query above misses fix diffs landed by non-oncall, non-IC owners — so a shift where the oncall authored nothing renders a misleading `0` even though shift SEVs were fixed by diffs. For each shift SEV, extract its fix diffs: `meta sevmanager.sev metadata --sev=S<id> -o json` → the `D########` references. **Render the metric as: `Diffs that fixed a shift SEV: <N total, any author> (<M> oncall-authored)`** — NOT a bare oncall-authored `0`. Example: S668293 carried D106946261 + others (andrewxmao) — those count. State the criteria inline so it's not ambiguous.

### 6b. DATA-GENERATE "Impact this shift" diffs (oncall-landed + bot-drafted)

**The `{{IMPACT_BULLETS}}` "what CHANGED" diff lines are data-generated, not hand-typed** — same discipline as the timeline. Two buckets, both queried for THIS shift window:

1. **Oncall-landed (Committed) diffs** — the diffs that actually changed system state this shift. Use Step 6's per-author list, filtered to landed diffs, OT-scoped paths. Render each as a clickable `D###` (via `tools/lib-url.sh diff_url`) + one-line title + author. **The valid `--status-is` value for a landed diff is `Committed` (the display label renders as "Closed", but the PowerSearch filter rejects `Closed` — verified 2026-06-06). Allowed values: Abandoned, Accepted, Changes Planned, Committed, Unpublished, Needs Review, Waiting For Author, Reverted.**

```bash
# Committed (landed) by the OT IC set this shift:
for u in dennyzhang lupaul llu6 yabinzh <rotation>; do
  meta phabricator.diff list --author-is="$u" --status-is=Committed \
    --last-updated-time-is-after="<WINDOW_START>" --last-updated-time-is-before="<WINDOW_END>" \
    --columns=number,title,status,author,updated --output=json --limit=30
done
```

2. **Bot-drafted this shift (distillation + auto-fix)** — the closed-loop's own output, `--draft` diffs from `dennyzhang`. **Identify by TAG, not title (2026-06-07): distillation/diff-loop autodrafts now carry the `ot_bot_autodraft` tag with a CLEAN human title** (the `[OT bot]` title prefix was retired — title is human attention real estate). Detect via `.tags` from `meta phabricator.diff metadata --number=<n> -o json` containing `ot_bot_autodraft`, OR linked to distillation task `T259215482`. (Other bot-diff types that still carry a message prefix — `[OT bot weekly sync]` notes-sync, `[MVAI agent]` — are detected by those prefixes as before; only the distillation/diff-loop autodrafts moved to the tag.) Cross-reference the auto-fixes context dir for the drafted-this-shift set:

```bash
meta phabricator.diff list --author-is=dennyzhang --include-only-open \
  --time-created-is-after="<WINDOW_START>" --time-created-is-before="<WINDOW_END>" \
  --columns=number,title,status,created --output=json --limit=30
# AND cross-ref drafted-this-shift fixes:
ls -t ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/system-fixes/auto-fixes/ 2>/dev/null | head
grep -rl "<WINDOW_START_DATE>\|<today>" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/system-fixes/auto-fixes/ 2>/dev/null
```

Render IMPACT as: a short stack of state-changing landed diffs (each `D###` clickable + one line), then ONE count line for bot-drafted-for-review (`✓ N distillation/auto-fix diffs drafted this shift (await operator review): D###, D###`). Resolved/landed = count + the exceptions, NOT a full enumeration (Cron Output Effectiveness rule). If the landed-diff query returns 0, verify per RULE 69 before rendering 0 (cross-check outgoing oncall's WP-post diff table + a `--status-is=Closed` re-query) and render `0 (verified: <query>)`.

### 6c. Recent failure-pattern learnings → fold into Hand-off (2026-06-07, operator: "this shall be in oncall shift")

The incoming oncall needs the latest TRIAGE KNOWLEDGE, not just open incidents — a new failure pattern learned this shift is exactly what saves the next person hours. Pull patterns codified in the shift window and surface them in the **Hand-off** section (do NOT add a template section — fold into Hand-off content; the template is the contract):
```bash
cd ~/notes
# P-rows (known-patterns) + R-rules (triage-discipline) added/changed in the window:
sl log -r "date('<window_start>')::now() and modifies('users/dennyzhang/projects/mrs-ot-agent-context/human-input/knowledge/known-patterns.md')" -T '{node|short} {desc|firstline}\n' --limit 10
sl diff -r '<first_in_window>^::tip' users/dennyzhang/projects/mrs-ot-agent-context/human-input/knowledge/known-patterns.md 2>/dev/null | grep -E '^\+\| P[0-9]+' | sed -E 's/^\+\| (P[0-9]+) \| \*\*([^.|]+).*/\1 — \2/' | head -5
```
Render a COMPACT list in **Hand-off**: `📚 New failure patterns: <Pid> — <≤12-word symptom→cause gist>; …` (cap 5, newest first). Example (this window): `P62 — STUS FULL_SNAPSHOT freeze while SPARSE/DENSE deltas healthy = kmeans-init hard gate (embedding count < minimum), NOT graceful degrade.` Gist only — the full row lives in known-patterns.md (respect the ≤4-page cap). If no pattern was codified this window, OMIT the line (no "none" filler, per Cron Output Effectiveness).

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

**STANDING REQUIRED FIELD EVERY SHIFT (operator 2026-06-10 thread `R32QmkCG66A`: "the oncall should choose a SEV and add the tag `mvai-online-training-review`. Make it a required place in oncall doc"):** every shift the oncall MUST pick ONE SEV from this shift for a deeper review and add the `mvai-online-training-review` tag to it. Render it as a LOUD `⚠️ REQUIRED — oncall fill:` field (RULE 61-bis, bold-red marker — NOT a soft `TODO:`), in the Oncall Improvements section AND as a Hand-off action item, ALWAYS (not only when the 14-day query is empty):
> `<li><span style="color:#CC0000"><b>⚠️ REQUIRED — oncall fill:</b></span> pick ONE SEV from this shift for a review deep-dive and add the <code>mvai-online-training-review</code> tag to it → S____ (tag at https://www.internalfb.com/sevmanager/view/&lt;id&gt;)</li>`
Pre-fill a suggested candidate from this shift's HIGH-TOUCH SEVs (the bot proposes; the oncall confirms/changes + does the tagging — the bot is read-only on SEV tags except the org-routing carve-out, and `mvai-online-training-review` is NOT in that carve-out, so the oncall adds it). If the 14-day query already shows a recent enrollment, ALSO render `SEV-Review last enrolled: S<num> (<date>)` for continuity — but the REQUIRED pick-one field stays every shift. Pre-push lint: the rendered tab MUST contain exactly one `mvai-online-training-review` `⚠️ REQUIRED — oncall fill:` line; ABORT if missing.

### 9. Render the draft — FILL TEMPLATE v5 (the .html file is the ONLY format)

**FORMAT SOURCE OF TRUTH:** `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-shift-summary-template.html` (currently **v5** — bullet-only, no tables).

> 🛑 **HARD OVERRIDE (2026-06-01, thread `2aXJCXZ4VY0`: operator "the latest tab is pretty bad").** The render is EXACTLY: read the v5 `.html` template → substitute `{{PLACEHOLDER}}` markers with data from steps 0–8 → push the FILLED FILE via `gdocs replace --tab-id <TAB> --from <filled_template_file>` (or `gdocs content insert-html`). Nothing else.
> - **NEVER render tables.** Any "Headline numbers — explicit table", "§1/§4/§5 table", or `[Metric, Count, Detail]` instruction appearing LATER in this step is **DEPRECATED v3 residue** — it tells you WHAT data to gather, NOT how to render. The v5 template's bullet sections are the only layout. (The 6/1 09:13 run regressed to v3 tables by following that residue — do not.)
> - **NEVER `meta google.docs.append markdown`** and never push raw `<style>`/CSS — that leaked `body { font-family: Arial … }` as visible text into the 6/1 tab. Only `gdocs replace`/`insert-html` of the filled template per `cheatsheets/gdocs/rules.md`.
> - The template's sections are the contract: SEVs and Alerts Oncall Got Paged → **OT Topline Metrics** → **Overview (COUNTS ONLY)** → **Highlights (spun off — the derived insights)** → Pain Points → Hand-off → Daily Timeline. (Overview was briefly Impact-merged but that made it a wall — Highlights is now its own section, AAAB889DKBQ.) If the filled output has a table or a `§N` heading, it is WRONG — re-render from the template.
> - **Headings = native `<h2>`/`<h3>` bold style ONLY. NEVER apply a background-color fill / paragraph shading to a heading, and NEVER run a post-render styling batch-update on headings.** The `#FFF2CC` yellow is reserved for TODO blocks (step "Styled TODO"), NOT headers. 2026-06-01 (comment chain on tab 6/2): a batch-update painted every heading yellow → operator: "the font looks off, why is the background yellow?" "Highlighted/scannable" (comment AAAB7ndcDpE) = the native bold heading, which is already scannable — do NOT add color. Render is `gdocs replace` of the template and STOP; no styling pass. (Note: open Google-Docs COMMENTS also highlight their anchored text yellow — that is NOT formatting and clears when the comment resolves; don't try to "fix" it with formatting.)
> - **The "Oncall Summary for…" line is `HEADING_3`, NOT `TITLE`** (operator decided 2026-06-01: match the section headings = h3). Title is 26pt and duplicates the tab-title size. The template marks it `<h3>`; if the html importer maps it to `TITLE`, correct with a batch-update `updateParagraphStyle namedStyleType=HEADING_3` on that paragraph.

**CRITICAL: Do NOT regenerate the format. Do NOT add tables. Do NOT add sections.** Read the template, fill `{{PLACEHOLDER}}` markers with data from steps 0-8, push the filled template to the gdoc tab. The template IS the format.

**MANDATORY PRE-PUSH SORT LINT (2026-05-28, comment `AAAB6WPRTgE` on tab `6/2`):** RULE 55 (3-tier sort: oncall_involvement DESC → severity DESC → status DESC) was declared 2026-05-25 but was NOT being enforced — comment `AAAB6WPRTgE` flagged `(S667849, S665454)` rendered out-of-order on tab `6/2`. Before calling `gdocs apply`, run the in-process lint below on every SEV-bearing list/table (Overview observe-only line, Hand-off `<ol>`, Daily Timeline within-day groupings, Section 4 Top Ongoing, Section 5 Handled). If any list is non-monotonic on the 3-key, **ABORT and re-sort** — do NOT push.

```python
# Sort lint (run before gdocs apply)
INVOLVE = {"high-touch": 3, "observe-only": 2, "none": 1}
SEVERITY = {0: 4, 1: 4, 2: 3, 3: 2, 4: 1}   # L0/L1 tied as most-severe
STATUS = {"OPEN": 3, "IN PROGRESS": 3, "MITIGATED": 2, "CLOSED": 1}
def sort_key(s):  # s is dict with involvement / level / status
    return (-INVOLVE[s["involvement"]], -SEVERITY[s["level"]], -STATUS[s["status"].upper()])
for section_name, sevs in sev_lists.items():
    keys = [sort_key(s) for s in sevs]
    if keys != sorted(keys):
        raise SortLintAbort(f"{section_name} not in RULE 55 order: {[s['sev_id'] for s in sevs]}")
```

Each SEV entry MUST carry `[L<n> <STATUS>]` bracket annotation inline so the operator can verify the sort visually. Lint is BLOCKING — failure means re-sort and re-run, never push the violating draft.

**The exact structure (7 sections, no tables):**

```
Title + Outgoing → Incoming
Shift character (NORMAL-TEXT opening paragraph, 2 sentences; bold ONLY key terms e.g. the HIGH-TOUCH count — never the whole line, RULE 82)
Overview (bullet list — NOT a table)
Impact this shift (what CHANGED, quantified)
Pain Points (problem → proposed fix → CC owner)
Hand-off (sorted by urgency)
Daily Timeline (MAIN SECTION — events grouped by day)
FYI (observe-only SEVs + alerts — ONE line each)
```

**Key rules:**

**RULE 61 — TODO markers MUST be visually loud (2026-05-28, thread `Rk8bGR2CQK8`).** Every `TODO` line the bot emits is a human-input marker the outgoing oncall relies on. Plain inline text blends with surrounding bullets and gets missed. Wrap EVERY `TODO` occurrence (in bullets, paragraphs, table cells, sub-bullets) as:

```html
<p style="background:#FFF2CC;padding:6px;border-left:4px solid #F1C232;margin:4px 0;"><b>📌 TODO (oncall):</b> <action text></p>
```

When the TODO is inside a `<ul><li>`, replace the entire `<li>...TODO...</li>` with the styled `<p>` block (do NOT nest the styled block inside `<li>` — gdoc renders nested block elements oddly). When inside a table `<td>` cell, drop the outer `<p>` styling and use a `<span style="background:#FFF2CC;font-weight:bold;">📌 TODO: <text></span>` instead (cells can't host block-level styling cleanly). Apply uniformly — do NOT mix styled/unstyled TODOs in one draft. Pre-push lint: `grep -E '^[^<]*TODO\\b' <draft.ghtml>` matches → ABORT (bare TODOs without styling block).

> **RULE 61-bis — every required-oncall-fill field carries the loud `⚠️ REQUIRED — oncall fill:` marker; NEVER a bare `TODO:` (2026-06-06, comment `AAAB863EMYQ` on tab `6/9`: "you should make this required human input more obviously. previously you did well for this part. why it run into quality regression? add preventions.").** A bare `TODO (oncall):` blends into the body and the oncall skips it — the exact regression Denny caught on the 6/9 tab (the `Difficulty/Hours`, `Impact`, and `Pain Points` fields all rendered as plain `TODO (oncall):` text). Every field the bot leaves for human judgment — `Difficulty/Hours/Wakeups`, `Impact this shift`, `Pain Points`, `Systemic Issues`, `Tasks`, `Adhoc Ask`, any SLICK/root-cause/mitigation fallback — MUST be prefixed with a **bold red** `⚠️ REQUIRED — oncall fill:` marker so it cannot be missed:
> ```html
> <li><span style="color:#CC0000"><b>⚠️ REQUIRED — oncall fill:</b></span> <action text></li>
> ```
> This marker is REQUIRED in BOTH render paths — the Tuesday full-template render AND the WED–MON mid-shift `insert-html` incremental refresh (the regression happened on the mid-shift path because RULE 61's `^[^<]*TODO` lint did not fire on `<li>`-wrapped TODOs). **Strengthened pre-push lint (run on every render, both paths):** `grep -nE 'TODO ?\(oncall\)' <draft.ghtml>` → for each hit assert the SAME element carries `⚠️ REQUIRED — oncall fill:`; any `TODO (oncall)` line WITHOUT the marker → ABORT. The marker may co-exist with the legacy `#FFF2CC` block, but the bold-red `⚠️ REQUIRED — oncall fill:` prefix is the non-negotiable minimum.

**RULE 62 — Bot-activity entries in Daily Timeline MUST be ≤1 line (2026-05-28, thread `Rk8bGR2CQK8`).** Bot self-triage entries (`bot:`, `auto-triaged`, `L<NN> ledger`, `CL-XXX cluster`, `P<NN> proposal`, `validator <verdict>`) bloat the timeline with internal chatter the operator doesn't read. Trim every BOT entry to ONE concise line. Format:

```
bot: triaged S<id> as <cluster> [confidence:low|med|high]
bot: ledger L<NN> — <≤8-word summary>
bot: P<NN> proposal — <≤8-word summary>
```

NO narrative, NO internal P-row chatter, NO validator self-references, NO CL-XXX cluster expositions, NO "rule added to surface" meta-commentary. Cross-link via the L<NN> / P<NN> token only — the daily-ledger holds detail. Human-oncall entries STAY verbose (action + context + outcome) — only BOT entries are trimmed. Pre-push lint: any `bot:` line >120 chars OR containing `validator|ledger noted|R\d+ lesson|cron health` → ABORT and re-trim.

**RULE 63 — Daily Timeline scannability format: bucket headings + bold IDs + quiet-day collapse (2026-05-28, comment `AAAB6WPRTgI` on tab `6/2`).** Operator feedback: "this section is not scannable. Critical info got buried in pool of text." A flat bullet list under each `<h4>` day is unreadable. Required structure per day:

1. **Day heading** (existing `<h4>YYYY-MM-DD (Day) — <subtitle></h4>`) — KEEP.
2. **Bucket sub-labels in fixed order** — bold inline at start of a parent `<li>`, each followed by child `<li>` rows prefixed `↳`:
   - `<b>🔴 Major:</b>` — L0/L1/L2 SEVs OR oncall-PAGEd OR oncall-filed-SEV. SKIP IF 0 ENTRIES.
   - `<b>⚠️ Watching:</b>` — L3/L4 OPEN SEVs the oncall is tracking (handover carry-forwards, new-this-day observe-only). SKIP IF 0.
   - `<b>🤖 Bot:</b>` — bot self-activity (alerts auto-triaged, ledger L<NN>, P<NN>). For days with >5 events total, COLLAPSE to a single line: `↳ bot: triaged N alerts + M ledger entries (L<X>–L<Y>)`. SKIP IF 0.
   - `<b>👤 Oncall:</b>` — human oncall actions: handover events, WP posts, diff status, escalations. SKIP IF 0.
3. **SEV entry format** inside any bucket: `↳ <b><a href=https://www.internalfb.com/sevmanager/view/###>S###</a></b> [L<n> <STATUS>]</span> — <1-line outcome, no prose>`. NO multi-line continuations. NO narrative paragraphs. (`href` uses the bare NUMERIC sev id — `sevmanager/view/672220` — NOT the old fburl shortlink form; per the canonical URL rule. Link text keeps the `S` prefix.)
4. **Quiet day**: literal nothing-happened day renders as a single line `<h4>YYYY-MM-DD (Day) — (quiet)</h4>` with NO `<ul>` below (RULE 57 reinforcement).
5. **Bucket ordering is FIXED** (Major → Watching → Bot → Oncall) regardless of which buckets are present — operator reads top-down for "what's on fire" first.
6. **Pre-push lint**: for each day-section, assert (a) buckets present are in order, (b) all SEV entries start with bold-ID-then-bracket-status pattern via regex `<b><span[^>]*><a[^>]+>S\d+</a></b> \[L\d (?:OPEN|CLOSED|MITIGATED)\]`, (c) NO bullet exceeds 240 chars. Mismatch → ABORT.

Source: comment AAAB6WPRTgI on tab `6/2` (doc `1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k`). Example before/after preserved in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/notes/2026-05-28-rule63-example.md` (if needed for regression).

1. **NO tables anywhere.** Overview is a bullet list. Metrics are one pipe-separated line.
2. **Shift character is the first thing the reader sees** — a NORMAL-TEXT paragraph before Overview with only key terms bold (NOT a fully-bold wall — operator AAAB889DKBk 2026-06-07; RULE 82).
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

**MAJOR-ALERT ACTIVITY IN TIMELINE (mandatory, comment AAAB8p7d1wg 2026-06-01 "why major/critical alerts activities are missing?").** The Daily Timeline (and the Critical-alerts section) must surface ALERTS that fired this shift, not only SEVs. **Source: Step 4b's `query-shift-oncall-events.sh` `alert` events** — it pulls the in-window major+critical alert history from `meta oncall.notification list` (carries `created_at`, `urgency`, `status`, and a resolvable `url` per alert). NOTE: the older direct `meta monitoring.alert list --start-time=… --end-time=… --state-is=ACTIVE,CLEARED` query is UNRELIABLE for in-window CLEARED alerts (the registry returns empty for time-bounded CLEARED queries — verified 2026-06-06); the notification-ledger path in Step 4b is the reliable in-window source. Attribute each alert to its firing day and add a one-line `🔔 alert:` entry under that day with model + urgency + resolved/open outcome + the event's onedetection `url` (NEVER sevmanager). For currently-ACTIVE alerts use Step 4b's `active_now` events. The 🚨 Critical-alerts section stays page/robocall-only (Step 4b `paged` events); the timeline carries the broader CRITICAL/MAJOR firing history.

**WEEKDAY + TUE-START CORRECTNESS (mandatory, comment AAAB8p7d1wc 2026-06-01 "two mistakes").** (a) Drop every pre-shift day (anything before the most-recent Tuesday 09:00 PT). (b) Compute each day's weekday label from its date — NEVER hand-type it. Use `date -d <YYYY-MM-DD> +%A` or python `datetime`. The 6/2 tab rendered 5/25 as "Sun" (actually Monday) and the whole early week off-by-one; the timeline must start at Tue 5/26 with correct labels.

**Data sources for Daily Timeline:**
- **PRIMARY: `tools/query-shift-oncall-events.sh --json-only` (Step 4b)** — data-generates the full paged/robocalled + major-alert + SEV + active-now event stream, time-sorted, day-groupable, with resolvable ids. This is the timeline backbone; the sources below are enrichment overlays, not the spine.
- daily-brief state files (steps 0, 3-6)
- `meta monitoring.alert list ... --urgency-is=CRITICAL,MAJOR` (major-alert activity — also folded into Step 4b's `alert`/`active_now` events)
- OT bot GChat space (`spaces/AAQAVOjYc80`) — read bot triage threads for per-SEV context
- auto-learnings/digests/2026-W{NN}.md — cross-incident patterns
- WP posts from mrs.ot group
- SEVs filed by oncall: `meta sevmanager.sev search --creator-is=<oncall_unixname> --time-created-is-after=<WINDOW_START> --time-created-is-before=<WINDOW_END>` — these are always HIGH-TOUCH (strongest signal)

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
| `{{IMPACT_BULLETS}}` | Step 6b (data-generated diffs) + shift observation + auto-learnings digest | `<li>` items — outcomes that changed system state. Step 6b supplies the landed-diff + bot-drafted lines (clickable `D###`); cross-ref auto-learnings/digests/2026-W{NN}.md for patterns identified this shift. |
| `{{PAIN_POINTS}}` | Shift observation | `<li>` items — problem + proposed fix + CC owner |
| `{{HANDOFF_ITEMS}}` | Steps 3-6 | `<li>` items sorted by urgency |
| `{{DAILY_TIMELINE}}` | Steps 0-6 + GChat + auto-learnings | `<h4>` per day + `<ul>` per day's events |
| `{{FYI_SEVS}}` | Step 3 | One line: carryovers + bot-triaged |
| `{{FYI_ALERTS}}` | Step 4 | One line: auto-resolved count + resolved items |

#### SLICK SLI probe (runs before template fill)

  **REQUIRED — probe BOTH named SLICK services (operator 2026-06-01, thread `2aXJCXZ4VY0`): `Discovery Online Models` AND `Instagram Online Models`.** These two populate the template's `SLICK status` section (`{{SLICK_DISCOVERY}}`, `{{SLICK_INSTAGRAM}}`). Do NOT probe only `mrs_online_training` — that's a different/generic id.

  ```bash
  # 1. Resolve each group's service_id (the display name is NOT the service_id). Match by name:
  meta slick.service list --output=json   # find the service_id whose name == "Discovery Online Models" / "Instagram Online Models"
  # 2. For EACH resolved <service_id>, pull SLI definitions + window performance.
  #    🛑 MANDATORY `-l 500` (comment AAAB8p7d1vo 2026-06-01 "no, I see some are red"):
  #    WITHOUT a high limit, `slick.sli performance` returns ONLY the first ~10 SLIs (default limit),
  #    which can all read OK by chance → a FALSE "✅ healthy". With -l 500 the full roster is probed:
  #    Discovery (mrs_ml/v1_discovery)=199 SLIs, Instagram (mrs_ml/v1_instagram)=48 SLIs — matching the
  #    operator's SLICK dashboard. NEVER assert healthy unless the full-roster probe shows zero VIOLATION.
  meta slick.sli list --service-id=<service_id> --output=json -l 500
  meta slick.sli performance --service-id=<service_id> \
    --start-time=<WINDOW_START_EPOCH> --end-time=<WINDOW_END_EPOCH> --output=json -l 500
  ```

  Render each group's worst-SLI status into its placeholder:
  - `{{SLICK_DISCOVERY}}` / `{{SLICK_INSTAGRAM}}` = `✅ healthy` | `⚠️ <sli> at-risk (value=<v>, burn=<b>)` | `🔴 <sli> breached (value=<v>)`.
  - **The "only 10 SLIs" symptom was a MISSING `-l 500`, not an API scope limit (corrected 2026-06-01, comment AAAB8p7d1vo).** Earlier guidance blamed a narrow API scope; the real cause is the default result limit. With `-l 500` the probe returns the full roster (Discovery 199, Instagram 48) and the VIOLATION reds the operator sees on the dashboard DO appear. So: always probe with `-l 500`, then HONESTLY report the reds.
  - **DO NOT assert a raw "all SLIs OK" count.** Render only: status icon + the SPECIFIC breached SLI names (worst few by gap) + the dashboard link. Never claim `✅ healthy` if ANY SLI has `status=VIOLATION` in the full-roster probe. A false "healthy" when reds exist is the exact failure operator flagged (comment AAAB8p7d1vo).
  - **Any non-healthy group → ALSO add a Hand-off item** ("SLICK: <group> <sli> at-risk/breached — investigate").
  - Surface all red signals inline: `<sli_name>: <status> (value=<v>, budget_burn=<b>)`.

  If a service_id can't be resolved OR the probe fails (CLI error, empty, network) → render the TODO fallback for THAT group (never silently omit), so the oncall fills:
  - `TODO (oncall): Discovery Online Models SLICK — green / yellow / red? value? budget burn?  https://fburl.com/monitoring/rkhcqpuj`
  - `TODO (oncall): Instagram Online Models SLICK — green / yellow / red? value? budget burn?  https://fburl.com/monitoring/gmdu02yq`

- **Headline numbers** — explicit table, render in this row order. **Schema MUST match 5/12 reference tab exactly: 3 columns `[Metric, Count, Detail]` — NO `#` column.** (Operator-validated 2026-05-18: 5/12 is the canonical layout; any divergence is a regression.)

  | Metric | Count | Detail |
  |---|---|---|
  | SEVs touched this shift | `<n>` | linked SEV IDs |
  | SEVs Remaining Open | `<n>` | linked SEV IDs |
  | SEVs on-demand support | `<n>` | Live filter: sevmanager mvai-online-training |
  | SEVs closed | `<n>` | linked SEV IDs + status transitions |
  | In-progress carryovers | `<n>` | linked SEV IDs from Section 2 |
  | Alerts | `<n> total` | `<major> major (oncall action)` + `<auto> auto-resolved` + `<noise> low-priority noise`; linked alert IDs for major only |
  | Workplace user reports | `<n>` | author display names with WP post URLs — EVERY item MUST have a link |
  | Diffs closed | `<n> oncall-related` | oncall-related diffs only (SEV fixes, OT reliability, monitoring). Exclude non-oncall diffs (agent sync, myclaw UI, unrelated bot improvements). If filtering changes total, show "X oncall-related of Y total" |
  | Diffs open | `<n>` | breakdown by author |
  | Bot Post Score | `<confirmed>/<total>` | from step 7. **Render LAST in the table** — this metric is early-stage and unreliable when triage_events is empty |

  Rendering rules for this table (apply per `cheatsheets/gdocs/rules.md`):
  - **Use markdown link syntax `[label](url)`, NOT `<a href>` HTML tags.** Markdown links convert to native gdoc hyperlinks everywhere (bullets, paragraphs, table cells). `<a href>` only converts inside table cells and leaves literal HTML in bullets/paragraphs. Source: 2026-05-18 visual-state verification failure on 5/18 tab. See `cheatsheets/gdocs/rules.md` "Visual-State Verification" section.
  - Header row background `#C9DAF8`, body 11pt Arial.
  - Column widths via `updateTableColumnProperties` (FIXED_WIDTH): Metric=180pt, Count=80pt, Detail=340pt.
  - Detail cell SEV IDs: `[S###](https://www.internalfb.com/sevmanager/view/###)` — NO `S` prefix in URL path (RULES.md URL validity).
  - Detail cell Diff IDs: `[D###](https://www.internalfb.com/diff/###)`.
  - Detail cell Alert IDs: `[A###](https://www.internalfb.com/onedetection/alert?alert_id=###)`.
  - Detail cell Workplace posts: `[<topic>](https://fb.workplace.com/groups/mrs.ot/permalink/<id>/)`.
  - Count cells are **computed at render time from the same source as the Detail cell**, not duplicated.
  - **Freshness re-check (mandatory):** for every SEV ID destined for the SEVs Remaining Open row, re-fetch `meta sevmanager.sev metadata --sev=S<id> -o json | jq -r '.status'` immediately before render. Drop any SEV whose live status is `Mitigated`, `Closed`, `Resolved`, or `Invalid`. Same re-check governs the carryover list in Section 2.
  - Source query for `SEVs Remaining Open`:

    ```bash
    meta sevmanager.sev list --tags=mvai-online-training --status='In Progress' \
      --columns=sev_number,level,title,owner_unixname --output=json --limit=100
    ```

  **Global rendering rules (apply to ALL tables and lists in the entire doc):**
  - **Sort by importance everywhere.** ALL tables sort by: oncall direct involvement first, then severity/impact, then issue status. ALL hand-off lists sort by urgency. Never sort alphabetically or chronologically unless importance-order would be identical. (Operator feedback 2026-05-25, comments AAAB6SHJgw4/AAAB6SHJgw0)
  - **Consolidate SEV+Level columns.** In ALL SEV tables, merge SEV and Level/Lvl into one column (e.g., "S667687 L4"). Saves horizontal space. (Operator feedback 2026-05-25, comment AAAB6SHJgw8)
  - **Every referenced item needs a URL.** Every WP post, SEV, diff, alert in any table or list MUST have a clickable link. No bare names. (Operator feedback 2026-05-25, comment AAAB6SHJgxM)
  - **Hand-off items: no already-committed diffs.** Diffs that are already submitted/in-review belong in the open diffs section, not hand-off. Only include items that require action by the incoming oncall. (Operator feedback 2026-05-25, comment AAAB6SHJgww)

- **Theme section** (skill section 1 second bullet) — REQUIRED ≥6 substantive bullets, NO template fallback, NO `TODO (oncall)` here (per L12). **MUST cross-reference `auto-learnings/digests/2026-W{NN}.md`** for the matching week and incorporate curated cross-incident patterns (e.g., DPP session restart fleet-wide impact, P59 preload deadlock, detector formula false positives, CL-003 cascade scale). The weekly digest captures patterns the shift summary's live-SEV-only view misses. (Operator feedback 2026-05-25, comment AAAB6SHJgws). Compute cross-SEV pattern frequencies and emit one bullet per pattern that fires ≥1× in the window. Mandatory categories the bot checks (emit only if hit):
  - (a) **Long-running L3s without mitigation** — any SEV `level==3` AND `status=='In Progress'` AND `(now - created).days >= 5`. List the SEV ids + age.
  - (b) **Package-cluster failures** — ≥2 SEVs touching same package within 48h (e.g., light_cli, fire-app, mvai_ig_ranking).
  - (c) **NCCL / DPP hang family** — titles match `nccl|stuckjob|gloo|dpp|deadlock|hang`. Cross-link to P24/P30 if applicable.
  - (d) **MB warmup / capacity-class** — titles match `mb\d|warmup|ramp|qps|slow`. Cross-link to known 3h-warmup pattern.
  - (e) **Multi-region serving degradation** — titles match `region|fallback|serving error|error rate`.
  - (f) **Bot monitoring health** — if `triage_events COUNT(*) == 0` for window → emit "Bot triage dark for full window — investigate ot-alert-monitor / ot-sev-monitor / ot-post-monitor cron health".
  - (g) **Long-tail patterns** — if <6 categories fire above, supplement with per-PG SEV-count distribution (e.g., "IG: 4 SEVs / Facebook: 6 / Threads: 3") and per-cluster-pattern (CL-001/CL-003/CL-013/CL-014/CL-017) frequency to reach 6.

#### Section 1b: Hand-off action items (incoming oncall)

Render this section IMMEDIATELY after Section 1 Headline numbers — it is the primary action surface for the incoming oncall and must not be buried near the doc tail.

Source: union of (a) any `TODO (oncall):` markers emitted by step 8 pre-finalize gates, (b) Section 2 carryover SEVs whose `investigation_summary` is empty, (c) any Section 5 Workplace post lacking a verdict, (d) any Section 3 SEV with `status==In Progress` and no `mvai-online-training-review` tag past 14 days.

Format: numbered list, each item `<n>. <action> — <linked artifact> — owner: <incoming_unixname>`. SEV/diff/task IDs MUST be explicit `<a>` anchors (same rule as Headline numbers Detail cells). If empty, render `✅ No hand-off action items — clean shift.`

#### Section 2: Ongoing Issues

For each SEV with `status==In Progress` AND created before `WINDOW_START`:
- **Re-fetch live status first** (same freshness rule as Section 1 SEVs Remaining Open). Drop any SEV whose live `metadata.status` is no longer `In Progress`. This guards against carryover entries surviving past mitigation (caught 2026-05-09 with S660546 carrying after mitigation).
- Bullet: `S<num> [L<level>]: <title>` (SEV id rendered as `<a href="https://www.internalfb.com/sevmanager/view/<num>">S<num></a>` — NO `S` prefix in URL path per RULES.md URL validity) then sub-bullets pulled from `investigation_summary` field of metadata. If empty → `TODO (oncall): 1-line status update needed`.

#### Section 3: SEVs (5/12-schema canonical, operator-validated 2026-05-18)

Render **TWO tables** matching 5/12 reference layout exactly:

**Table A: Top ongoing issues** — 4 columns, sorted L3 first then activity. Source: live SEV state + ot-bot deep-triage replies. Cap at 8 rows.

| SEV | Symptom | Root cause / Verdict | Status & next |
|---|---|---|---|
| `[S<num>](https://www.internalfb.com/sevmanager/view/<num>) [L<lvl>] <title>` | 1-line symptom from `metadata.overview` or `metadata.incident_impact` | derived via root-cause fallback chain (see below) | live `status` + 1-line next action |

**Table B: Closed this week — per-SEV** — 6 columns, all closed-in-window SEVs.

| # | SEV | Severity | Title | Root cause | Mitigation & follow-up |
|---|---|---|---|---|---|
| `<n>` | `[S<num>](...)` | `L<lvl>` | metadata.title | metadata.root_cause OR derived | metadata.remediation OR status-based |

**Table C: OT-IC vs Bot triage signals** — 4 columns, per closed SEV.

| SEV | OT IC in SEV gchat | Bot triage | Verdict |
|---|---|---|---|
| `[S<num>](...)` | `<unixname>` if OT IC in 17-name set posted in SEV gchat, else `none` | `yes (N)` from triage_events count, else `none` | `OWNED` if both yes, `observed-only` if bot-only, `not involved` if neither |

Then one trailing summary line under Table C: `Net: X of Y closed SEVs had real OT IC ownership; Z had observed-only; rest not involved.`

**Bucketing (used to select which SEVs go in Table B / Table C):**
- **Handled** — SEV owner ∈ OT IC set (`dennyzhang`, `lupaul`, `llu6`, `yabinzh` + rotation members), OR SEV carries `mvai-online-training` AND triage_events row exists with `auto_tag_applied=1`.
- **On-Demand Support** — tagged but owner outside OT IC set; team contributed via comments/GChat but didn't own.
- **Related** — adjacent failures referenced in triage cross-references.

Skip subsections with zero entries.

**Root-cause fallback chain (MANDATORY, per L12 — do not allow `TODO (oncall)` here).** For every SEV whose `metadata.root_cause` is empty, derive a one-line root cause by walking this chain until non-empty:

1. **Overview first sentence** — `metadata.overview.split('.')[0]` truncated to 140 chars.
2. **Title pattern match** — known-pattern dictionary (P05/OOM, P12/TCPStore, P17/fbpkg-expiry, P24/NCCL-hang, P30/DPP-pkg, P38/Boxcar, snapshot-publish, MB-warmup, multi-region-fallback, tenant-overload, preemptive-launch, dpp-segfault). Render as `<pattern-family>: <title-derived summary>`.
3. **Impact field first sentence** — `metadata.incident_impact.split('.')[0]`.
4. **Owner + status only** — `(open — <owner> investigating, see SEV gchat)` for In Progress; `(closed; see SEV gchat)` for Closed.

NEVER emit `TODO (oncall)` in the root_cause cell.

**Mitigation derivation (MANDATORY).** `metadata.remediation` if non-empty; else: `Mitigated` → "Mitigated (no detail in SEV remediation field)"; `Closed` → "Closed; resolution in SEV gchat"; `Cleanup` → "Mitigated, in Cleanup"; `In Progress` → "Open — see SEV gchat". Never `TODO (oncall)`.

#### Section 4: Tasks, Incidents & Alerts (5/12 schema: 3-col bucket table)

Render as **a single 3-col bucket-summary table** matching 5/12 layout, NOT a per-alert detail table:

| Bucket | Count | Detail |
|---|---|---|
| Actionable | `<n>` | `[A<id>](...)` per actionable alert, 1-line each with time + title + assignee |
| Auto-recovered (≤30 min) | `<n>` | alerts that closed within 30 min and never triggered triage_events |
| Low-priority | `<n>` | NaN-metric / dead-detector / threshold-misfit alerts; cross-link to associated SEV if known |
| Notable | `<n>` | systemic patterns spotted (e.g., hung-job detection gap, coverage holes) |

Use markdown link syntax `[label](url)` for ALL alert IDs.

#### Section 5: User Reports and Feedback (5/12 schema: 3-col table)

**Schema MUST match 5/12 reference: 3 columns `[Author, Topic, Summary & Reply status]`** — NOT the older 5/6-column variant (5/12 dropped Created and Takeaway columns; operator validated 2026-05-18).

| Author | Topic | Summary & Reply status |
|---|---|---|
| `[<display_name>](https://www.internalfb.com/profile/<unixname>)` | `[<topic_line>](<post_url>)` | `<summary>` + `auto-replied by bot` if triage_events row exists; else `(N comments — TODO confirm resolved)`; else `unanswered` |

Skip past shift summaries (title regex `^Oncall Summary for mrs_online_training`). Header bg `#C9DAF8`, body 11pt Arial. Column widths (FIXED_WIDTH): Author=130pt, Topic=300pt, Summary=240pt.

**Per-post enrichment (MANDATORY, per L12).** For each post id, call:
```bash
meta workplace.post content --post-id=<id> --output=json
```
Extract: `author.name`, `author.unixname`, `message` (post body), `comment_count`, `created_time`. Derive:
- **Topic cell** = first line of `message` (strip leading `#` markdown heading marker, truncate at 90 chars). Use markdown link syntax `[topic](post_url)`. Never use placeholder text.
- **Author cell** = `[display_name](https://www.internalfb.com/profile/<unixname>)`. If unixname missing, slug from display_name (`John Doe` → `johndoe`).
- **Summary & Reply status cell** = 1-sentence diagnosis from triage_events.bot_diagnosis if present, then status: `auto-replied by bot` / `(N comments — TODO confirm)` / `unanswered`. Match 5/12 patterns: `"Diagnosed (90%); awaiting reply"`, `"TODO (oncall): S<id> in progress"`, `"TODO (oncall): guidance posted"`.

**Link syntax: use markdown `[label](url)`, NOT `<a href>` HTML tags.** (Per `cheatsheets/gdocs/rules.md` Visual-State Verification rule; `<a href>` only converts inside table cells but markdown `[label](url)` works in bullets/paragraphs/headers too.)

#### Section 6: Oncall Improvements

- **Diffs Produced** — table from step 6 closed-bucket. Columns: diff id (rendered as `<a href="https://www.internalfb.com/diff/D###">D###</a>`), title, motivation (cross-ref to a SEV or alert if the diff lands a fix; else `TODO (oncall): standalone improvement`).
- **Open Diffs** — table from step 6 open-bucket. Same diff-id anchor rule.
- **Pre-finalize gates** — explicit table (NOT a verbatim TODO paste). Render this BEFORE Systemic Issues:

  | Gate | Status | Owner | Evidence link |
  |---|---|---|---|
  | Tag hygiene (`mvai-online-training` on every Section 3 Handled SEV) | ✅ pass / ⚠️ N missing | bot | per-SEV anchor list |
  | SEV-Review enrollment (last 14d carries `mvai-online-training-review`) | ✅ enrolled S### / ⚠️ due | bot | `<a href="...">S###</a>` or empty |
  | Three-question gate pass rate (Section 3+4+5) | `<pass>/<total>` | bot | dropped-row count + reason |
  | Org-scope filter (no sibling-org SEVs leaked) | ✅ clean / ⚠️ leak | bot | leaked SEV anchor + reference S657101 |

  Apply `cheatsheets/gdocs/rules.md` post-push checklist. Header bg `#C9DAF8`, body 11pt Arial. Column widths via `updateTableColumnProperties` (FIXED_WIDTH, scalar columnIndices): Gate=130pt, Status=60pt, Owner=80pt, Evidence link=200pt. Step 8 still emits the underlying `TODO:` markers — they additionally feed the Hand-off action items section above.

- **Systemic Issues** — `TODO (oncall): list any pattern-level gaps spotted this shift`.
- **Tasks** — `TODO (oncall): file or link any GSD task work`. Task IDs as `<a href="https://www.internalfb.com/tasks/?t=###">T###</a>`.
- Footer links (always render): `Online Training GSD: https://www.internalfb.com/gsd/3382026308735140` (matches past posts' Better Engineering link).

**Note:** Bot Post Score moved to Section 1 Headline numbers (row #2) — it is the primary KPI for bot health and belongs at the top, not buried in Oncall Improvements.

#### Section 7: Daily timeline (NEW — sourced from Step 0 daily-brief state)

If Step 0 found ≥1 daily-brief state file, render this section as the LAST section before the footer. Format: one collapsible block per date (chronological order), each containing the verbatim brief body from that date's state file. Header line per day: `### <YYYY-MM-DD> (<weekday>) — <SEV count> SEVs · <diff count> diffs · <wp post count> WP posts` (counts pulled from frontmatter).

If Step 0 fell back to live re-query (no state files), skip this section entirely and emit a `WARN: Daily timeline unavailable — daily-brief cron output missing` line at the very top of the rendered draft.

This section is the answer to operator comment AAAB57N4fXs (2026-05-09): "You have a daily cron job to summarize issues. The oncall shift summary should take them as input for the time period."

### 10. Post to bound space + append to gdoc + persist state

**(a) GChat notification (existing)** — send to `spaces/AAQAVOjYc80`:

```
📋 [Weekly OT Shift Summary | <DATE_RANGE>]
Outgoing: <outgoing_unixname> → Incoming: <incoming_unixname>

<Section 1 + summary stats inline — keep ≤ 800 chars for the lead message>

Full draft pasted in thread reply.
Also appended to gdoc: https://docs.google.com/document/d/1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k/
```

Then send a threaded reply with the FULL rendered draft (Sections 1-6). Cap the threaded reply at GChat's 4096-char message ceiling — if the draft exceeds, split into multiple threaded messages numbered `(1/N)`, `(2/N)`, etc.

**(b) Append to canonical OT Oncall Shift gdoc.** This is the persistent operator-facing surface — Workplace post is downstream/manual; gdoc is the source of truth the team browses week-to-week. Bot-config: read `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-shift-gdoc-config.json` for `doc_id` + `default_tab_id` (do NOT hard-code; operator may add per-quarter tabs). If config file missing, fall back to `doc_id=1helRQh0I05stXhMEsroMYxbETPgtdyeNS3Zy55TJe0k`, `tab_id=t.sdbn13ll2glq`.

**HARD GATES — read `hard_lessons_2026_05_12` from the config and enforce these on every gdoc-touching op:**
- **L1 — 'consolidate' means MERGE, not DELETE.** If the operator's gdoc already has a section for this window: NEVER delete it. MERGE the fresh data into operator's existing structure, or restore as APPENDIX and ask before merging.
- **L2 — every gdoc reply MUST start with `[myclaw-ot bot reply] `.** Meta CLI runs as the operator; without the prefix, replies look like operator self-replies.
- **L3 — NO destructive op without ack.** Before any `delete-content range`, `replace-content`, or `replace-all`: cache current export, describe planned change in chat, wait for explicit operator confirmation. Append-only ops are exempt.

**Authoring rule — author as ghtml, NEVER as markdown** (per `cheatsheets/gdocs/rules.md` HARD RULE: markdown→ghtml import wraps every heading in `<span style="font-size:11pt">` overriding H1/H2/H3 defaults AND splits emoji surrogate pairs). The shift summary contains H2/H3 headings + emoji (⚠️ 🔴 🆕 📊) — markdown is FORBIDDEN here. Render the draft as a ghtml file with: `<h2>` for title, `<h3>` for sections, `<h4>` for subsections; `<table><tr><td>...</td></tr></table>` for tables with `<td><b>Header</b></td>` (NOT `<th>` — ghtml drops `<th>` content silently); `<a href="URL">label</a>` for ALL SEV/D/A/T/W IDs (works inside both bullets and `<td>` cells); `<ul>/<ol>/<li>` for lists; `<p>` for paragraphs; `<b>/<i>/<code>` for inline. NO `---` separators (cheatsheet HARD RULE: ugly in gdocs).

**Push via `gdocs` (standalone) — NEVER `meta google.docs.*`** (per cheatsheet HARD RULE, learned 2026-05-17). The two CLIs go through different transports; `meta google.docs.*` quietly drops bold-in-headers, drops `<a>` link wrappers, and pollutes headings with font-size spans. **The previous `meta google.docs.append markdown` recipe was wrong on three of these axes simultaneously.** Use `gdocs replace --tab-id` for a fresh tab (no comments) or `gdocs content insert-html --tab-id` to add into an existing tab that may carry comments:

```bash
DOC_ID=$(jq -r .doc_id /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-shift-gdoc-config.json)
TAB_TITLE="$(date -d "$WINDOW_END" +%-m/%-d)"  # e.g., 5/26 — matches tab_convention.naming
TAB_ID=$(gdocs tabs "$DOC_ID" 2>/dev/null | awk -v t="$TAB_TITLE" '$2==t {print $1}')
NEW_TAB_CREATED=0
if [ -z "$TAB_ID" ]; then
  TAB_ID=$(gdocs add-tab "$DOC_ID" --title "$TAB_TITLE" 2>&1 | awk '/tabId:/{print $2}')
  NEW_TAB_CREATED=1
fi

# === HARD GATE #1 (PRE-PUSH, RULE 81): lint the filled ghtml; ABORT the push on any violation ===
if ! bash team_bot/tools/shift-doc-lint.sh /tmp/ot-shift-summary-${WINDOW_END}.html; then
  echo "[ABORT] shift-doc-lint pre-push gate FAILED — do NOT push; fix the violations above"; exit 1
fi

# Fresh tab path (no comments, safe full-replace):
gdocs replace "$DOC_ID" --tab-id "$TAB_ID" --from /tmp/ot-shift-summary-${WINDOW_END}.html --full-replace-removes-comments

# Existing-tab-with-comments path (gated by comment-count check):
COMMENTS=$(gdocs comments list "$DOC_ID" --untrusted-authors-mode 2>/dev/null | grep -c "^[a-zA-Z0-9]\{20,\}")
if [ "$COMMENTS" -gt 0 ]; then
  # round-trip: gdocs edit -> modify ghtml -> gdocs apply (preserves comments)
  # OR insert-html with --after-heading anchor for additive updates
  gdocs content insert-html "$DOC_ID" "@/tmp/ot-shift-summary-${WINDOW_END}.html" --tab-id "$TAB_ID" --after-heading "Oncall Summary"
fi

# === HARD GATE #2 (POST-PUSH, RULES 81/88): COMPLETE gate incl. the docs-API font-audit (#12) that
# ghtml can't see. Non-zero = the live tab has a regression (font/bold/link/dedup) — fix before done. ===
if ! bash team_bot/tools/shift-doc-lint.sh --doc "$DOC_ID" --tab "$TAB_ID"; then
  echo "[ABORT] shift-doc-lint POST-push gate FAILED on the live tab — fix immediately (RULE 81)"; exit 1
fi
```

> **FONT-CONSISTENCY RULE — `insert-html` of a new timeline day MUST match the existing sections' body style (2026-06-06, comment `AAAB863EMYM` on tab `6/9`: "the font it bad. why it's not consistent with previous dates?").** `gdocs content insert-html ... --after-heading` makes the inserted paragraphs INHERIT the paragraph style of the element at the insertion point. On the 6/9 tab the 6/4 + 6/5 day bullets were inserted after a `HEADING_4` day-heading and silently came in as `HEADING_3` (14pt) instead of `NORMAL_TEXT` (11pt) — so the new days rendered in a larger/wrong font than the prior days (6/3 and earlier, which are `NORMAL_TEXT`). This is the same heading-inheritance class as `cheatsheets/gdocs/rules.md` "insert-text --as-html near headings". **Required on EVERY mid-shift incremental day insert:**
> 1. New day-heading = `<h4>` (matches existing day headings); new day body = `<ul><li>` items that MUST render as `NORMAL_TEXT` 11pt Arial — identical to the prior date's `<li>` items. Mirror the structure of the most-recent existing date section before composing the new one.
> 2. **POST-INSERT FONT NORMALIZATION — DETERMINISTIC, NOT PROSE (T275803195, 2026-06-13).** The old "remember to read-back and fix" step kept getting skipped under task focus → the HEADING_3 font bug recurred (operator: "why font mess up again?" on tabs 6/9 AND 6/16). It is now a script you MUST run after EVERY `insert-html`/`replace` of timeline content — do not hand-do the get-structure+batch-update:
>    ```bash
>    bash team_bot/scripts/normalize-shift-timeline-fonts.sh "$DOC_ID" "$TAB_ID" --apply
>    ```
>    It forces every Daily-Timeline ENTRY paragraph (everything that is NOT a `M/D (Weekday)` day-heading, and not the `Local notes` label) to `NORMAL_TEXT`, leaves day-headings as `HEADING_4`, and re-verifies (exit 1 if any remain). It self-handles the daemon nuance (fetch `--no-daemon`, write via daemon). Idempotent — safe to run every tick.
> 3. **RENDER-LINT GATE (must pass before the run is considered clean):** `bash team_bot/scripts/normalize-shift-timeline-fonts.sh "$DOC_ID" "$TAB_ID" --check` — exits non-zero if ANY timeline entry is still a HEADING_*; treat a non-zero `--check` as a failed render (escalate, do not report success). This is the structural backstop so the bug cannot silently recur even if step 2 is skipped.

**Tab-reorder limitation (re-verified 2026-05-28, gotcha_gdoc-tab-ordering.md, ledger L57).** `gdocs add-tab` has NO `--index` / position option and Docs API v1 STILL rejects `moveTab` (`Unknown name "moveTab"` HTTP 400). New tabs always land at the END (rightmost). Denny wants latest week LEFTMOST. There is no programmatic workaround. If `NEW_TAB_CREATED=1`, the cron MUST emit a gchat escalation to the operator:

```bash
if [ "$NEW_TAB_CREATED" -eq 1 ]; then
  meta google.chat.message send --as-meta-bot --space-name=spaces/AAQAVOjYc80 \
    --text="🚫 New tab \`$TAB_TITLE\` created at the END (index=$(gdocs tabs list "$DOC_ID" | awk -v t="$TAB_ID" '$1==t {print $3}')). \`moveTab\` is not in Docs API v1 (re-verified 2026-05-28). **Please drag \`$TAB_TITLE\` to the leftmost position in the UI.** Tab: https://docs.google.com/document/d/$DOC_ID/edit?tab=$TAB_ID"
fi
```

**Prefix-text-stuck-on-resolved-comment trap (learned 2026-05-28, ledger L57).** `--full-replace-removes-comments` removes the COMMENT but NOT the anchor text when the comment is `resolved=true`. If a stale prefix like `[Bot] OT Oncall Shift` is anchored on a resolved comment, the prefix will survive every `gdocs replace`. Detection (run BEFORE replace):

```bash
gdocs comments list "$DOC_ID" --untrusted-authors-mode 2>/dev/null | grep -F "[Bot] OT Oncall Shift" && \
  echo "WARN: resolved-comment anchors found; switch to gdocs edit -> strip locally -> gdocs apply round-trip instead of replace"
```

Cleanup recipe (orphans the resolved comments, removes the text):
```bash
gdocs edit "$DOC_ID" --tab-id "$TAB_ID" --output /tmp/tab-scrub.html
# remove the offending <p data-idx="...">[Bot] OT Oncall Shift</p> and adjacent empty <p>s
gdocs apply "$DOC_ID" /tmp/tab-scrub.html --tab-id "$TAB_ID"
```

The draft body MUST start with `<h2>Oncall Summary for mrs_online_training: <DATE_RANGE></h2>` and end with `<p><i>End of <DATE_RANGE> shift summary.</i></p>`. Provenance line as `<p><i>Generated by: ot-shift-summary cron (weekly Tue 8:30 AM PT) | Source: fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/cron-jobs/ot-shift-summary.md | Last updated: YYYY-MM-DD HH:MM PT</i></p>` immediately under the H2 (cheatsheet HARD RULE: provenance on every auto-generated doc).

**POST-PUSH CHECKLIST — MANDATORY (per `cheatsheets/gdocs/rules.md`).** After `gdocs replace`/`insert-html`, run ALL of these in one `gdocs batch-update` call:

1. **Header bg `#C9DAF8` on every table's row 0.** `updateTableCellStyle` with `tableRange.tableCellLocation.{tableStartLocation.index, rowIndex=0, columnIndex=0}`, `rowSpan=1`, `columnSpan=<table_cols>`, `tableCellStyle.backgroundColor.color.rgbColor={red:0.788, green:0.855, blue:0.973}`, `fields="backgroundColor"`.
2. **Proportional FIXED_WIDTH columns on every table.** `updateTableColumnProperties` — one request per column, `columnIndices` MUST be a SCALAR integer (cheatsheet learned 2026-04-28: PHP backend rejects array form). Default widths per shift-summary table:
   - Headline numbers (11×3): `[180, 80, 340]`
   - Ongoing carryovers (Nx5): `[80, 50, 280, 100, 180]`
   - Top ongoing SEVs (Nx6): `[80, 40, 150, 240, 200, 200]`
   - Tasks/Alerts (4×3): `[160, 60, 400]`
   - User reports (Nx4): `[90, 120, 280, 200]`
   - Open diffs (Nx5): `[80, 270, 60, 80, 200]`
   - Pre-finalize gates (4×4): `[300, 120, 80, 180]`
3. **Verify visual state.** `gdocs get <DOC>` (NOT `--text`) and grep the tab block for: (a) every SEV/D/A label that should be a hyperlink IS wrapped in `<a href="...">` (cheatsheet learned 2026-05-18: `--text` export hides this — must verify against ghtml export); (b) NO `<span style="font-size:` polluting any `<h2>/<h3>/<h4>` (cheatsheet learned 2026-05-20: markdown imports cause this); (c) no `???`/`??` rendering on emoji.

NOTE: `gdocs` (`/usr/local/bin/gdocs`) and `meta google.docs.*` look interchangeable but are NOT — different transports. ANY write op uses `gdocs`. ANY env-var-controlled feature (`GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=1`) works ONLY with `gdocs`. Cron-prompt history: `meta google.docs.append markdown` was the recipe pre-2026-05-25 and is now FORBIDDEN.

**(c) Apply operator-feedback rules** (from comments on prior 5/5 section, anchors `[g]…[l]`). Read these from `ot-shift-gdoc-config.json → standing_open_items_from_operator_comments`. They are HARD requirements for the rendered draft:

- **`[g]` Alerts depth.** Section 4 must list every actionable alert in window with details + investigation notes. Pull via `meta oncall.feed list ...` (existing) AND for each alert: `meta oncall.feed describe --id=<alert_id> -o json --no-truncate` (single call — includes title, priority, assigned_user, description + investigation notes; `oncall.feed` has NO `metadata` or `comments` action — canonical is `describe`). For raw OneDetection alert detail (suppression state, urgency, resolvable url): `meta monitoring.alert metadata --alert-id=<full_alert_key> -o json`.
- **`[h]` User posts completeness.** After running step 5's `meta workplace.post list`, sanity-check the count against the GChat space's `ot-post-monitor` cron output for the same window — these MUST match. If counts diverge, list the missing post URLs explicitly in the section header for operator follow-up.
- **`[i]` Specific missing post.** Confirmed pattern: posts moved between Workplace groups can be missed. Use `--include-cross-posted` when available; otherwise verify the count check from `[h]`.
- **`[j]` Creation Date column, sorted.** Section 5 user-posts table MUST include a `Created` column. Sort rows oldest → newest by `created` field. Use `YYYY-MM-DD HH:MM PT` rendering.
- **`[k]` Add new "Adhoc Ask" subsection** (under Section 4 or Section 5 — operator's choice; default below Section 5). Captures urgent escalations the oncall got drafted into via 1:1 / GChat (e.g., prior shift had Patrick Tan + Shuguang requests). Source: scan the bot's own messages in `spaces/AAQAVOjYc80` whose content matches `(urgent|UBN|escalation|<oncall_unixname>)` and the human reply included a 1:1 mention. Default rendering: `_TODO (oncall): list any 1:1 / GChat escalations this shift_` if the heuristic finds none — never silently omit.
- **`[l]` Diff summary, top 5 only.** Section 6 must summarize total diff count + top 5 by impact (heuristic: prefer diffs that close a SEV from this shift, then diffs landed by the outgoing oncall, then highest line-count). Render full diff list as a collapsed `<details>` block beneath the top-5.
- **`[m]` SEV Stack column.** Section 3 SEV tables MUST include a `SEV Stack` column (between SEV-id and Title). Pull via `meta sevmanager.sev metadata --sev=S<id> -o json | jq -r '.stack // empty'`. Source comment: AAAB5ghIkk0.
- **`[n]` Table background — header only.** When rendering tables, set background color (light gray / theme color) ONLY on the HEADER row — NEVER on data rows. Default markdown-converted-to-table rendering can produce alternating-row shading; if it does, post-process via `gdocs batch-update` with `updateTableCellStyle` (set data-row cells to white `{"red":1,"green":1,"blue":1}` / clear `backgroundColor` with `fields:"tableCellStyle.backgroundColor"`) to clear data-row shading. NEVER `meta google.docs.*` (write path goes through the wrong transport — see cheatsheet HARD RULE). Source comment: AAAB5ghIkkQ.

**(d) Persist state.** Write `last_run_epoch`, `last_window_end`, `last_known_oncall = <outgoing_unixname>` to `/home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-shift-summary-state.json`. Also write `last_gdoc_append_epoch` + `last_gdoc_section_heading` to a new key for the gdoc-side dedup guard.

**(e) Idempotence + dedup guard.** Before appending in (b), `gdocs get <doc_id> --untrusted-authors-mode | grep -F "<DATE_RANGE>" -c` — if ≥1, a section for THIS WINDOW already exists (could be operator-curated or prior bot run). Do NOT append a duplicate. Instead:

  1. Locate the existing section's start/end indices via `gdocs get-structure <doc_id> --tab-id=<tab_id>` (look for HEADING elements containing the date range).
  2. UPDATE in place. **First check comment count** (`gdocs comments list <doc_id> --untrusted-authors-mode`): if the tab has comments, `deleteContentRange` / `replace` are hook-blocked — use `gdocs content find-replace` or `gdocs batch-update` (insertText/updateTextStyle) for targeted cell updates only. If comment-free, either (a) `gdocs batch-update` with `deleteContentRange` (start=<s>,end=<e>) followed by `insertText` at <s>, or (b) `gdocs content find-replace` on individual cells if only a few values changed. NEVER `meta google.docs.*` for any write.
  3. If you can't safely locate the section (ambiguous heading), SKIP the gdoc write and log `gdoc-update-skipped ambiguous-section <DATE_RANGE>`. Still send the GChat post.

This prevents the recurrence of the 2026-05-12 issue where the bot appended a `5/12` section duplicating the operator's existing `5/5` section (both labelled `5/5 – 5/12`). See `consolidate_no_duplicates` rule in `ot-shift-gdoc-config.json`.

### 11. Cleanup + heartbeat

**TUE→TUE WINDOW (operator thread `WhmgQGD72MQ` 2026-05-28: "as you know the oncall starts on Tue. So we should always start with Tue and ends on the next Tue.")**: shift window = Tue 09:00 PT → next Tue 09:00 PT. Pre-flight assert: `[ "$(date -d "$WINDOW_START" +%u)" = "2" ]` (weekday must be Tuesday). If not, recompute (find most recent Tuesday 09:00 PT ≤ NOW). Tab title (M/D format), section headers, frontmatter dates MUST all reflect Tue→Tue. Reject any Mon-start or Sun-start math.

**DETERMINISTIC SORT KEY (operator thread `WhmgQGD72MQ` 2026-05-28: "you should order the SEVs by importance"):** every list/table in the shift summary uses this 5-key sort, applied in order:
1. Oncall-robocalled / paged this shift (DESC: paged first)
2. Oncall-filed / oncall-engaged via chat or sev comment (DESC: engaged first)
3. Severity (SEV0 > SEV1 > SEV2 > SEV3 > SEV4 > non-SEV)
4. This-shift before carryover (this_shift=1 first)
5. Status (OPEN > IN_PROGRESS > MITIGATED > CLOSED)

Bot-internal / low-confidence rows last. Document the sort key inline in EACH section header (e.g., `### SEVs HIGH-TOUCH (sort: robocalled → engaged → severity → this-shift → status)`).

**ROBOCALL / PAGE AUDIT (mandatory section, before HIGH-TOUCH; operator thread `WhmgQGD72MQ` 2026-05-28: "S668272 — oncall got robocalled Wed night. why this is not captured?"):** every shift summary MUST have a `### 🚨 Critical alerts (robocalled this shift)` section at the top, surfacing every SEV/alert that paged a human oncall during the window. Detection:
- `meta sevmanager.sev list ... -o json | jq '.[] | select(.auto_detected == true and .detection_method_tags | contains(["page"]))'`
- Cross-reference with `meta pagerduty.events list --range="<WINDOW_START> .. <WINDOW_END>"` if available (or oncall.feed audit).
- For each: enumerate (SEV/alert link, model, paged-oncall unixname, time-paged, current status).
- If sevmanager has indexing lag (<6 min before run), manually reconcile from sev gchat first message timestamp.

NEVER omit a robocall from the shift summary; missing one is the highest-impact failure mode for this doc.

**CARRYOVER / FYI TWO-GATE FILTER (operator gdoc comments — S659671 + S659877 leaked into prior shift's carryover list):** every SEV in the carryover or observe-only section MUST pass BOTH gates:
1. **OT-scope gate:** tag includes `mvai-online-training` OR `ai.model-series describe` confirms OT stack (training_stack in {MVAI, SILVERTORCH}).
2. **Oncall-engagement gate:** sevmanager.chat shows ≥1 message from current OR prior shift's oncall during the SEV's lifetime, OR oncall_unixname IS the current/prior oncall.

If EITHER gate fails → drop silently. Anti-regression: S659671 (not OT-tagged, IFR error rate T4 serving) and S659877 (IGML T4 serving — no oncall engagement) MUST drop, not appear in observe-only list.

**DIFFS-CLOSED FILTER (operator gdoc comments — bot-internal diffs cluttered the diffs list):** the "Diffs landed" section excludes bot-internal/sync/tooling diffs. Whitelist: tag `mrs-ot-reliability` OR path prefix `fbcode/pe_mrs_ml/` (oncall-authored fixes only — NOT auto-generated sync diffs from `ot-notes-fbcode-commit`/`ot-notes-fbcode-sync-weekly`). For each surviving diff: prepend a 3-8 word descriptor pulled from `diff title` (first line). NEVER emit bare `D<id>` tokens.

**ALERTS SECTION (operator gdoc comments — "need to know 'critical alerts' fired, which robocalled oncall"):** alerts section emits TWO counts (total triaged / major or UBN) and enumerates every major/UBN alert inline with (alert-name, model, paged-oncall-name, detector-page URL). Never lump as a single total. Use the `url` field from `meta monitoring.alert metadata --alert-id=<full_alert_key> -o json` as the href (the bare-numeric `?alert_id=<id>` URL does NOT resolve for [AGG] alerts; `oncall.feed` has no `metadata` action — use the `monitoring.alert` namespace for raw alert URLs — verified 2026-05-28 thread `WR9DFGuQ3dU` on alert A2449443538836650).

**SECTION-EXCLUSION RULES (operator thread `WhmgQGD72MQ` 2026-05-28 21:47 PT — two generic feedback):**

1. **NO BOT-AUTONOMOUS-WORKFLOW CONTENT in the shift summary.** The shift summary is for the HUMAN ONCALL READER and focuses on HUMAN SIGNALS (real SEVs, alerts that paged a human, user-filed Workplace posts, human oncall actions / diffs). DO NOT include bullets about: bot tooling fixes shipped that session, sqlite cron registrations, prompt amendments, cron-health alerts that auto-mitigated, parity validators, gchat wrapper amendments, OAuth refreshes, memory file updates, cheatsheet edits, any bot self-improvement work. These are autonomous workflows — their existence is the bot doing its job in the background, NOT a signal the human oncall needs to act on. Pre-push assert: scan the draft for patterns like "Bot tooling fixes shipped", "registered via surgical INSERT", "wrapper inlined", "parity validator added", "cron-health alert auto-mitigated", "[Denny session]" — these are leak markers; if any appear, cut the entire bullet (not just rephrase).

2. **TRUNK-HEALTH SEVs ARE LEAST PRIORITY.** SEVs tagged `mrs_ml_release_oncall` (or similar trunk-health workstream tags) are OWNED by the release oncall, not the MRS OT oncall. The MRS OT oncall does NOT need to action them. Render rule: do NOT list trunk-health SEVs in HIGH-TOUCH or observe-only sections. Aggregate to a SINGLE one-line bullet at the bottom of the SEV section: `Trunk-health SEVs handled by release oncall (not actionable here): N` — link IDs only if N ≤ 3; otherwise just the count. Never headline. Identification: tag includes `mrs_ml_release_oncall` OR title contains `cogwheel TGIF validation` / `trunk_metrics_test` / similar trunk-side keywords.

**≤4-PAGE HARD CAP (pre-push gate, 2026-05-28 operator thread `WhmgQGD72MQ`):** the rendered ghtml MUST fit in ≤4 printed pages. Concrete gates before `gdocs replace`:

1. Body byte count: `wc -c` on the filled ghtml file ≤ 13000 bytes. Over budget → cut, do NOT push.
2. Section count: ≤ 6 top-level `<h3>` sections. Over budget → consolidate.
3. NO "End of <date> shift summary" footer line (operator flagged: "adds no value, remove it").
4. NO "FYI:" filler bullets (operator flagged: "adds no value").
5. ALL SEV mentions clickable `<a href="https://www.internalfb.com/sevmanager/view/<id>">S<id></a>` — NEVER render bare `S<id>` (operator flagged: "why SEV is not clickable? same for all SEVs").
6. SEVs sorted by importance: oncall_involvement DESC → severity DESC (SEV0/1 > SEV2 > SEV3 > non-SEV) → issue_status (OPEN > MITIGATED > CLOSED). Applies to §3 SEV tables, §4 alerts, §5 user posts, §6 diffs. Pre-push assert: each list/table monotonic on the 3-key sort.

If over budget, cut in this order: (a) historical Daily Timeline entries BEFORE current shift, (b) carryover SEV detail (one-line reference, not full enrichment), (c) drop "Oncall Improvements" section if it's just template, (d) move observe-only SEVs to a one-line aggregate, (e) drop redundant Pain Points already covered in mega-learnings.

**Mid-shift / daily-incremental mode (DEFAULT on every non-Tuesday daily run, or any off-cycle manual run, when the current-week tab already exists):** this is the path 6 of 7 days. The Tuesday run is the close-out (new tab, full draft, §earlier); WED–MON refresh the current shift's tab IN PLACE. Switch to MID-SHIFT mode when today is NOT Tuesday (or invoked off-slot) AND the current-week tab exists. **NO-TAB → CREATE IT (HARD — operator override 2026-06-10 thread `cWZYKBGcGB8`: "creating the new tab IS part of your job; you shouldn't skip it"):** if it's a non-Tuesday run and the current-week tab does NOT exist, **CREATE it — never skip.** Maintaining the *current* shift's tab is this cron's core job. The Tuesday close-out produces the *outgoing* shift's review draft (a DIFFERENT tab, named by the ending shift); nothing else creates the *incoming/current* shift's tab — so a missing current-week tab is the **NORMAL day-1 state of a new shift, NOT a masked close-out failure** (the prior "skip + ask operator to hand-create" gate was wrong: 2026-06-10 the Jun 9 close-out correctly made the outgoing `6/9` tab, but the incoming `6/16` tab had no creator → mid-shift skipped, leaving the doc stale). **Create it via the close-out's tab-creation mechanism. COMPUTE THE WINDOW DETERMINISTICALLY — Tue→Tue, NEVER today-based (HARD; the 2026-06-10 create-run got this WRONG — it made a `6/10` tab spanning "Jun 3 - Jun 10", a forbidden today-minus-7 rolling window, instead of `6/16` / Jun 9-16):**
```
SHIFT_START=$(TZ=America/Los_Angeles date -d 'last tuesday' +%Y-%m-%d)   # most-recent Tuesday (non-Tuesday run); = the shift's START
SHIFT_END=$(date -d "$SHIFT_START +7 days" +%Y-%m-%d)                    # next Tuesday = the shift's END
TAB_TITLE=$(date -d "$SHIFT_END" +%-m/%-d)                               # e.g. 6/16 — the SHIFT-END Tuesday, NEVER today's date
```
The tab title is **always the SHIFT-END Tuesday (`$TAB_TITLE`), never today**; the populated content window is `SHIFT_START`→now but the **title/header span the full `SHIFT_START`→`SHIFT_END` (Tue→Tue)**. Sanity-assert before `add-tab`: `[ "$(date -d "$SHIFT_START" +%u)" = "2" ] && [ "$(date -d "$SHIFT_END" +%u)" = "2" ]` (both Tuesdays) — abort if not. Then `gdocs add-tab "$DOC_ID" --title "$TAB_TITLE"` and FULL-populate it from the v5 template via `gdocs replace --tab-id <new_tab> --from <filled_template>`. This first run is a full populate (not an incremental append, since the tab is empty); subsequent WED–MON runs find the tab and do the comment-safe incremental refresh. After creating, emit the new-tab reorder escalation (new tabs land rightmost; ask operator to drag it leftmost — see "Tab-reorder limitation"). Do NOT respond `no-current-tab-skipped`. (The only thing the old gate was right to forbid — a *full-replace onto a wrong/stale tab* — is still forbidden: only `add-tab` a genuinely-new titled tab, never full-replace an existing commented tab on a WED–MON run.)

**POST-CREATE SELF-CHECK — auto-delete a malformed new tab, NEVER leave it (HARD, operator 2026-06-10 thread `R32QmkCG66A`: "for new tabs, make the same mistakes won't happen").** The 2026-06-10 root failure wasn't just the wrong window — it was that the malformed `6/10` tab (rolling "Jun 3-10" window) **persisted** until a human caught it. So immediately after `add-tab` + populate, VERIFY the new tab and **delete-and-abort on any mismatch** rather than leaving a bad tab for the operator to find:
```
NEW_TAB_ID=$(gdocs docs tabs list "$DOC_ID" | awk -v t="$TAB_TITLE" '$2==t {print $1}')   # the just-created tab
HDR=$(gdocs get "$DOC_ID" --tab-id "$NEW_TAB_ID" | sed 's/<[^>]*>//g' | grep -m1 'Oncall Summary for mrs_online_training')
```
Assert ALL: (1) `NEW_TAB_ID` non-empty (the `$TAB_TITLE` tab exists); (2) `$TAB_TITLE` is the SHIFT-END Tuesday (`date -d "$SHIFT_END" +%-m/%-d`), NOT today's M/D; (3) `$HDR` contains the Tue→Tue range `<SHIFT_START disp> - <SHIFT_END disp>` and does NOT contain a rolling/today-based range (e.g. reject if it shows `<today-6> - <today>`). **If ANY assertion fails → `gdocs docs tabs delete "$DOC_ID" "$NEW_TAB_ID"` (remove the malformed tab) AND respond with an operator-1:1 alert `⚠️ shift new-tab create FAILED self-check (got <bad title/range>); deleted the malformed tab, no stale artifact left — re-run needed` — do NOT leave the bad tab and do NOT claim success.** A wrong tab that self-deletes is recoverable; a wrong tab that persists is the mistake this prevents.
- WINDOW_START = current shift start (most recent Tuesday 09:00 PT)
- WINDOW_END = now (not today 09:00 PT)
- Section header: `Oncall Summary for mrs_online_training: <SHIFT_START> - <NOW> (mid-shift, <day> ~HH:MM PT)`
- Framing: "Active oncall: <name> (since <handover_date>). Day <N> of 7." — NOT "Outgoing → X | Incoming → Y" (that's end-of-shift framing).
- Daily Timeline: scope to current shift only (skip days before WINDOW_START).
- HIGH-TOUCH scoped to current shift only (drop prior-shift mitigated/closed SEVs).
- ≤4-page gate still applies — mid-shift snapshots tend to be shorter so cap is rarely tight.

**COMMENT-SAFE — HARD (the current-week tab carries operator comments).** Refresh IN PLACE with TARGETED edits ONLY:
- `gdocs content find-replace` for the header timestamp, the `Day N of 7` count, the shift-character line, and any changed cell.
- `gdocs content insert-html --after-...` to APPEND the just-completed day's Daily-Timeline section + new open "needs-you" items.
- **Re-scan WP posts (HARD — every mid-shift, not timeline-only).** Run Step 5's live `meta workplace.post list --group-id=1084744250286987 --after="<SHIFT_START>T00:00:00-07:00" --before="<now>" --output=json --limit=50` for the full shift window on EVERY mid-shift run. For each new post whose id is NOT already rendered as a `fb.workplace.com/groups/mrs.ot/permalink/<id>` link in the current tab: (a) find-replace the WP-count cell and authors line via `gdocs content find-replace`; (b) append the new row to the Section 5 user-reports table via `gdocs content insert-html`. Apply Step 5's MANDATORY CROSS-CHECK against `ot-monitor-state.json` after scanning. Root cause of recurring "why user posts are missing?" (T275803489).
- **NEVER `gdocs replace` / `--full-replace` on this tab — it orphans every comment.** Full-replace is reserved for the Tuesday close-out's brand-new (commentless) tab. Never delete/resolve a comment; reply only via `gdocs comments reply` prefixed `[myclaw-ot bot reply]` and only if addressing one.
- **PIN the pre-edit `revisionId` first** (`gdocs get <DOC> --tab-id <T> --untrusted-authors-mode`) as the revert path; record it in the run.
- **VERIFY-READ-BACK after each edit.** gdocs has been intermittently hanging (60–280s, no error). **ABORT-ON-FLAKY:** if a call times out, retry once; if still hanging, STOP and respond `HEARTBEAT_OK {status: "gdocs-flaky-stopped", landed: "<what-landed>"}` + the pinned revision — do NOT blind-write a partial onto a leadership doc. NEVER `meta google.docs.*` as a fallback.
- **Idempotent per day:** before appending a day's timeline, check that day's heading isn't already present (a re-run refreshes the header/day-count only, never duplicates the timeline).
- gdocs CLI only (`/usr/local/bin/gdocs`), `--untrusted-authors-mode` on every call (per gdocs cheatsheet). (Pattern proven by the 2026-06-05 manual mid-shift run: pin → find-replace header/day-count + insert-html the new days → verify-read-back, ~100 comments preserved.)
- **NO NARRATION before the final response (Cron Delivery Discipline, HARD).** The gdocs edits are done via the explicit `gdocs` calls above — they ARE the work. The final response is EXACTLY one of the `HEARTBEAT_OK …` tokens below and nothing before it: no "composing…", no "State updated.", no "Now writing the doc." Any text before `HEARTBEAT_OK` gets delivered to chat verbatim (June 2 leak: "State updated. Now composing the GChat output.").

Respond `HEARTBEAT_OK {status: "posted-shift-summary", range: "<DATE_RANGE>"}` (or `HEARTBEAT_OK {status: "gdocs-flaky-stopped", landed: "…"}` on abort). Per CLAUDE.md delivery discipline the final response is bare `HEARTBEAT_OK` or `HEARTBEAT_OK {…}` metrics ONLY — a trailing bare-word suffix (`HEARTBEAT_OK posted-shift-summary 6/2-6/9`) is NOT recognized as a no-op and gets delivered to chat verbatim.

## Safety

- **Never auto-post to mrs.ot Workplace group.** This is a draft for the human oncall; they paste it manually. Rationale: the published shift summary is read by the entire MRS-org leadership rotation, including non-OT principals — wrong information at this surface costs the team's trust budget. Skill's "Workplace is read-only" rule applies.
- **No SEV mutations.** Don't apply tags, don't comment, don't change owner. Surface `TODO:` markers only. (Tag hygiene fixes are oncall's call — skill says "skill does NOT auto-fix — these are oncall decisions".)
- **Org filter** — drop sibling-org SEVs silently per `team_lane_scope.is_in_mrs_org_scope()` capability. Source: 2026-04-30 S657101 Ads leak.
- **Three-question gate** (from `daily-brief.md`): every SEV/alert/post line passes (a) OT-scope, (b) MRS-org, (c) team-visible — drop on any fail.
- **Same-day rerun guard** — step 1's `last_window_end == today` check prevents accidental double-post when operator manually triggers the cron.
- **Empty draft handling** — if SEVs / alerts / posts / diffs are all empty AND no in-progress carryovers, render `📋 Quiet shift — no SEVs, no actionable alerts, no Workplace activity. <outgoing_unixname>: confirm before final post.` rather than a multi-page draft of empty sections.

## Learned rules (auto-appended)

- **2026-05-11 — Live status re-check on every carryover/remaining-open SEV.** Daily-brief frontmatter is up to 24h stale. Always re-fetch `meta sevmanager.sev metadata --sev=S<id>` immediately before render and drop SEVs whose live status is no longer `In Progress`. Source: 2026-05-09 oncall-doc comment from operator — S660546 still listed under In-progress carryovers after mitigation.
- **2026-05-11 — Headline numbers Detail cells require explicit `<a>` anchors.** Bare SEV/Diff/Task numbers in text-path table cells do NOT auto-link (the gdocs preprocessor only auto-links HTML inserts). Apply to ALL Detail-style cells across the rendered draft. Source: 2026-05-10 oncall-doc comment.
- **2026-05-11 — Bot Post Score is a top-line KPI, not buried in Oncall Improvements.** Position #2 in the Headline numbers table (right after `SEVs touched this shift`).
- **2026-05-11 — Hand-off action items live near the top, not the tail.** Render immediately after Section 1 Headline numbers — the incoming oncall must see actionable items in the first scroll, before SEV detail walls.
- **2026-05-11 — SLICK SLI is now machine-probable.** `meta slick.sli list --service-id=mrs_online_training` + per-SLI `meta slick.sli performance --service-id=...` exists (canonical flag is `--service-id` / `-s`, NOT `--service`). Auto-fill before falling back to TODO. Old assumption ("no programmatic API") is obsolete.
- **2026-05-25 — RULE 32: Headline `SEVs touched this shift` split into two rows.** ROW A = `SEVs (high-touch)` — count + IDs where oncall directly engaged (gchat msg, attached diff/task, SEV-page comment, WP broadcast referencing the SEV). ROW B = `SEVs (observe-only)` — count + IDs that were bot-triaged with no oncall touch this shift. Never merge into one row. Source: comment AAAB6TgHzYA on 5/26 tab.
- **2026-05-25 — RULE 33: Bot-internal diffs excluded from oncall shift output.** Filter at Section 6 (Diffs Produced + Open Diffs) AND Section 7 (Daily timeline diff bullets): drop any diff whose title starts with `[OT bot]`, `[OT Debuggability]` (unless linked to a SEV), or whose path is under `fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/` / `fbcode/pe_mrs_ml/mrs_ot_agent/notes-to-fbcode-sync*` / `fbcode/pe_mrs_ml/mrs_ot_agent/skills/` (bot-tooling). These are internal bot maintenance, not oncall-visible improvements. Source: comment AAAB6TgHzXo on 5/26 tab (re: D106237863 notes-to-fbcode-sync consolidation guard).
- **2026-05-25 — RULE 34: Daily timeline section moved up to Section 3.** Order: §1 Headline → §1b Hand-off → §2 Ongoing → **§3 Daily timeline** (was §7) → §4 SEVs opened this shift → §5 Tasks/Incidents/Alerts → §6 User Reports → §7 Oncall Improvements → footer. Rationale: timeline is the reader's narrative entry-point; SEV/alert tables are supporting evidence. Section numbering renumbers correspondingly. Source: comment AAAB6TgHzXg on 5/26 tab.
- **2026-05-25 — RULE 35: Diff URL MUST have D prefix.** Format: `<a href="https://www.internalfb.com/diff/D######">D######</a>`. Bare `/diff/######` (no D) returns 404 ("document type not supported"). Pre-push lint regex: `href="[^"]*diff/[0-9]` matches → ABORT. Apply to every Diff cell in Section 6 + every diff bullet in Section 7. Source: comment AAAB6TgHzXY on 5/26 tab.
- **2026-05-25 — RULE 36: Every Author cell in Section 6 (User Reports) gets a profile link.** Even past-shift-summary posts (regex `^Oncall Summary for mrs_online_training`) keep the row AND get the `<a href="https://www.internalfb.com/profile/<unixname>">DisplayName</a>` wrap. Prior bug: regex skipped past-shift posts AFTER hyperlink wrapping, leaving them plain text. Fix: hyperlink-wrap ALL Author cells unconditionally; the past-shift filter (if any) drops the row entirely, not just its hyperlink. Source: comment AAAB6TgHzXU on 5/26 tab (re: Li Lu plain text in 5/19 row).
- **2026-05-25 — RULE 37: Section 6 user-reports table sorted by Created DESCENDING (latest at top).** Pre-push lint: assert `row[0].created >= row[-1].created` (ISO date comparison). Note this OVERRIDES earlier `[j]` rule which mandated ascending — operator updated convention 2026-05-25. Source: comment AAAB6TgHzXQ on 5/26 tab.
- **2026-05-25 — RULE 38: Section 5 (Tasks, Incidents & Alerts) MUST union 4 data sources.** (a) `meta monitoring.alert list --oncall mrs_online_training --start-time --end-time --state-is ACTIVE,CLEARED`; (b) `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-alert-monitor-state.json` (cron state); (c) `meta workplace.post list --group-vanity-name=mrs.ot --after --before` filtered to `--tag=incident` or title-matching `incident|UBN`; (d) SEVs linked to `mrs_ml/v1_discovery` SLI via `meta slick.sli alerts --service-id=mrs_ml/v1_discovery`. Bucket into Actionable / Auto-recovered (≤30m) / Low-priority / Notable. Pre-push lint: if total count = 0, comment must say `verified zero — sources (a-d) all returned empty` to distinguish from `not queried`. Source: comment AAAB6TgHzWg on 5/26 tab.
- **2026-05-25 — RULE 39: cron source-of-truth links never include a commit hash.** Footer provenance link MUST be `https://www.internalfb.com/code/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/team_bot/cron-jobs/ot-shift-summary.md` (always-current master). Commit-pinned URLs `https://www.internalfb.com/code/fbsource/<sha>/fbcode/...` 404 in browser when the SHA never reached fbsource (e.g., sapling-local-only commits). Source: comment AAAB6TgHzVg on 5/26 tab.
- **2026-05-25 — RULE 41: Drop `Tasks TODO (oncall)` placeholder block from rendered output.** The footer `Tasks TODO (oncall): file or link any GSD task work` (and similar passive prompts) adds no value to oncall reading the doc — they know to file tasks. If the bot has REAL task IDs to surface (from `meta tasks.task list --oncall mrs_online_training --created-after ...`), render them as concrete bullets; otherwise OMIT the block entirely. Never render the empty-prompt placeholder. Source: comment AAAB6TgHzYw on 5/26 tab.
- **2026-05-25 — RULE 42: Drop the `Pre-finalize gates` table from rendered output.** Self-referential bot checklist (Tag hygiene / SEV-Review enrollment / Deep-triage backlog / Bot Post Score check) belongs in the cron's internal pre-flight log, NOT in the operator-facing shift summary. Operator reads the summary; bot QC is bot's problem. Move these gates into a `_pre_finalize_gates_log.json` in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/` for debugging; do NOT render in the gdoc. Source: comment AAAB6TgHzYs on 5/26 tab.
- **2026-05-25 — RULE 43: NEVER render `TBD` in the Headline numbers table.** Every row must have a concrete count + Detail. If a metric is not computable at render time (e.g., Tue final cron deferral), DROP THE ROW entirely instead of rendering `TBD`. Pre-push lint: `grep -F 'TBD' <draft.ghtml>` matches → ABORT and re-compute or drop. The Headline table is the document's hero metric — TBD rows undermine credibility. Source: comment AAAB6TgHzYo on 5/26 tab.
- **2026-05-25 — RULE 44: Section 3 SEV table — merge `SEV` + `SEV Lvl` into one cell, sort by oncall involvement first then importance.** Schema change: `[SEV (with Lvl badge), Stack, Title, Status]` (4 columns, was 5). Render format inside the SEV cell: `<a href="https://www.internalfb.com/sevmanager/view/NNNNNN">S######</a> <span style="background:#fed;color:#a00;padding:0 4px;border-radius:3px;">L<n></span>`. Sort key: primary = high-touch (per RULE 32, oncall directly engaged) BEFORE observe-only, secondary = L-level ascending (L1 before L4). Applies to both Table A (Top ongoing) and Table B (Handled). Supersedes `m_sev_stack_column` ordering. Source: comment AAAB6TgHzYk on 5/26 tab.
- **2026-05-25 — RULE 45: `Bot Post Score` row moves to the BOTTOM of Headline numbers (LAST row).** This SUPERSEDES the 2026-05-11 rule that mandated position #2. Operator updated convention 2026-05-25: Bot Post Score is a bot-self-QC signal, not a top-line oncall KPI — it belongs after all human-facing metrics. Render order: SEVs (high-touch) → SEVs (observe-only) → Alerts → Tasks → Workplace posts → Diffs → … → Bot Post Score (last). Source: comment AAAB6TgHzYg on 5/26 tab.
- **2026-05-25 — RULE 46: NO `Manual check` placeholders — replace with automated probe + key signal.** Every cell that previously rendered `Manual check` (e.g., Pre-finalize gates evidence column, Hand-off action items) must be replaced with a concrete automated query result. Examples: tag hygiene → `meta sevmanager.sev list --oncall mrs_online_training --has-tag mvai-online-training --created-after <window>` count; SEV-Review enrollment → `meta tasks.task list --tag mvai-online-training-review --created-after <window>` count; Deep-triage backlog → grep `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-monitor-state.json` for pending. If a check is genuinely manual (rare), DROP the row instead of rendering `Manual check`. Pre-push lint: `grep -F 'Manual check' <draft.ghtml>` matches → ABORT. Source: comment AAAB6TgHzYc on 5/26 tab.
- **2026-05-25 — RULE 47: NO `TODO (oncall) — <thing> deferred to Tue final cron` placeholder lines.** These are bot-deferral apologies, not oncall content. If the data is genuinely deferred, OMIT the line entirely; the Tuesday cron will supply real values on its run. Pre-push lint: `grep -E 'TODO.*deferred.*cron' <draft.ghtml>` matches → ABORT and drop the line. Source: comment AAAB6TgHzYY on 5/26 tab.
- **2026-05-25 — RULE 48: Timeline grammar — never juxtapose unrelated clauses with comma-splice ambiguity.** Bad: `Bot-triage alone is NOT involvement. Age-monitoring nudges removed. 2026-05-19 (Tue) — handover Denny starting incoming.` Reads as 'not-involved Denny started oncall'. Fix recipe: (1) make timeline entries strict `YYYY-MM-DD (Day) — <event sentence>` format; (2) bot-self-policy notes (e.g., `Bot-triage alone is NOT involvement`) live in a SEPARATE meta-block above/below the timeline, not interleaved with date events; (3) every timeline event sentence has explicit subject (`<unixname>` or `bot`), explicit verb, explicit object — no fragments. Pre-push lint: regex `\b(starting|started)\s+(incoming|outgoing|oncall)\b` matches a timeline line without a unixname-prefix → ABORT. Source: comment AAAB6TgHzYU on 5/26 tab.
- **2026-05-25 — RULE 49: Section 6 Open Diffs table — strict columnar row format.** Schema: `Diff | Reviewer(s) | Lines | Path | Status | Next-Action`. Bad free-form rows (e.g., `D106194663 review — i2i SLI DENSE_DELTA restore, 89 lines, CFHG path — needs reviewer.`) split into columns. Reviewer cell = comma-list of `<a href=https://www.internalfb.com/profile/<unixname>>name</a>`. Lines = signed (`+89/-3`). Path = top-level dir (`fbcode/configerator/`). Status ∈ {Open, Approved, Land-blocked, Land-failed}. Next-Action = one of `needs reviewer | needs land | needs rebase | waiting on Sandcastle`. Source: comment AAAB6TgHzfA on 5/26 tab.
- **2026-05-25 — RULE 50: Section 7 Theme bullets MUST consult auto-learnings folder before synthesizing.** Mandatory inputs before drafting cross-SEV pattern bullets: (a) `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/learnings/daily-ledger.md` — extract all L-NN entries within shift window; (b) `auto-learnings/digests/2026-W<NN>.md` for the active week; (c) `auto-learnings/patterns/INDEX.md` for CL-NNN cluster IDs touched this shift. Theme bullets cite CL-NNN + L-NN where applicable. Pre-push lint: if Theme bullets section exists AND grep `CL-[0-9]+\|L[0-9]+` in section returns 0 → ABORT with `did not consult auto-learnings`. Source: comment AAAB6TgHze8 on 5/26 tab.
- **2026-05-25 — RULE 51: Section 6 Diffs Closed filter — only oncall-effort diffs.** Filter clauses (ALL must pass): (a) author = dennyzhang OR co-author on a SEV/shift workflow; AND (b) title/summary references a SEV in the shift window OR diff path touches shift-handled dirs (`fbcode/configerator/`, `fbcode/pe_mrs_ml/{sevmanager,model-state,training-runtime}/`, cron prompts for SEV-related crons). Exclude bot-internal infra: `D105981671` (sl auto-sync), `D106052922` (notes-to-fbcode-sync), `D106189268` (state JSON seed fix). Schema same as RULE 49. Headline `Diffs closed` count is the FILTERED count, not raw author-diff count. Source: comment AAAB6TgHzew on 5/26 tab.
- **2026-05-25 — RULE 52: Section 4 Headline alert count must split UBN-class vs standard.** Format: `N triaged (X UBN-class, Y standard)` where UBN-class = union of (a) linked SEV with severity ∈ {SEV0, SEV1, SEV2}; (b) Workplace mrs.ot user-report attached within ±24h of alert; (c) detector flagged UBN tier; (d) alert PAGEd (auto_detected=true with page event). Pre-push lint: assert `X + Y == N`. Source: comment AAAB6TgHzek on 5/26 tab.
- **2026-05-25 — RULE 53: SEV identification — 4-clause tightening for §3 SEV tables.**
  (1) **OT-SEV filter** — REQUIRE either (a) tag `mvai-online-training` set on SEV OR (b) title regex `/online[ -_]training|delta[ -_](publish|pipeline)|example[ -_]age|publish[ -_]path|trainer[ -_]stuck|FULL_SNAPSHOT|SPARSE_DELTA|DENSE_DELTA/i`. Both fail → exclude. Historical misses: S659671, S657071, S635148 (no tag, title pattern miss).
  (2) **No-carryover-if-no-engagement** — `In-progress carryovers` row REQUIRES one of (a) oncall posted gchat msg in linked SEV space THIS shift; (b) oncall landed diff cross-referencing SEV THIS shift; (c) oncall added SEV-page comment THIS shift. Bot-only triage does NOT count. Historical false-carryovers: S659877, S663485.
  (3) **Trailing SEV sort** — SEVs opened BEFORE shift start get a `[trailing-from-W<NN>]` badge AND sort AFTER all this-week-opened SEVs in §3 tables. Never lead with trailing SEVs.
  (4) **Mitigated-during-shift inclusion** — When pulling §3 candidate SEVs, union `--in-progress` AND `--status=mitigated --time-mitigated-after=<shift-start>`. The `--in-progress` only query misses SEVs mitigated mid-shift (e.g., S665454 Threads U2M trainer stuck 14h was missed this way — Denny's 5/22 WP broadcast targeted it).
  Source: comment AAAB6TgHzeg on 5/26 tab.
- **2026-05-25 — RULE 54: Section 4 alert-list cells use `<ul><li>` for multi-alert lists; alert URLs render as clickable `A<id>` text.** Bad (current): inline comma list with raw `https://...alert_inspect?alert_id=...` URLs. Good: `<ul><li><a href="https://www.internalfb.com/intern/monitor/alert_inspect?alert_id=NNNN">A<NNNN></a> — <summary></li>…</ul>`. AGG clusters render with nested sub-bullets for member alerts. Long inline strings >120 chars → MUST break to list. Source: comment AAAB6TgHzeY on 5/26 tab.
- **2026-05-25 — RULE 55: All tables sort by oncall_involvement DESC, then importance DESC, then issue_status; cron MUST diff prev-week tab schema first.**
  (a) **Sort key (3-tier):** primary `oncall_involvement` ∈ {high-touch=3, observe-only=2, none=1}; secondary `importance` ∈ {SEV0/1=4, SEV2=3, SEV3=2, non-SEV=1}; tertiary `issue_status` ∈ {OPEN=3, MITIGATED=2, CLOSED=1}. Applied to §3 Top-ongoing, §3 Handled, §4 alerts, §5 user-posts, §6 diffs. Pre-push lint: for each table, assert each adjacent row pair satisfies the 3-tier sort.
  (b) **Prev-week schema diff before drafting:** cron does `gdocs get --tab-id <prev-week-tab>` BEFORE generating current draft. Extract section headings + table column headers; if current draft diverges (sections added/dropped/renamed, or table columns differ), write `_schema_drift.json` to space dir AND surface drift in cron output. Prevents 'I forgot what last week looked like' regressions. The 5/19 tab is the baseline for 5/26.
  Source: comment AAAB6TgHzeE on 5/26 tab.
- **2026-05-25 — RULE 56: Daily timeline promotes to Section 2 (UPDATES + supersedes RULE 34).** New section order: §1 Headline → **§2 Daily timeline** → §3 Hand-off → §4 Top ongoing SEVs → §5 SEVs handled this shift → §6 Tasks/Incidents/Alerts → §7 User Reports → §8 Diffs → §9 Oncall Improvements → footer. Rationale: timeline is the narrative spine the operator reads first. Cross-refs in template body all renumber. Source: comment AAAB6TgHzgI on 5/26 tab.
- **2026-05-25 — RULE 57: Drop negative-existence filler from Daily timeline.** Bullets like `No new WP posts by Denny.`, `No new diffs by oncall this day.`, `No SEVs touched today.` add no value. Empty days render as `<date> — (quiet)` if literally nothing; otherwise list only what HAPPENED. Pre-push lint regex `^\s*-?\s*No new .* by .*\.\s*$` in §2 → ABORT and drop the line. Source: comment AAAB6TgHzgE on 5/26 tab.
- **2026-05-25 — RULE 36-ext: ALL person-name renders across ALL sections use `render_person(name, unixname)` helper.** Sections covered: §2 timeline subject, §4 SEV owner cell, §5 SEV owner cell, §7 user-post author, §8 diff author + reviewers. Output: `<a href="https://www.internalfb.com/profile/<unixname>">DisplayName</a>`. Single shared helper, NOT per-section regex. Closes the gap where §5/§7 used different code paths and the timeline-day-event renderer left names plain (Li Lu unwrapped in 5/19 timeline despite RULE 36 fix). Source: comment AAAB6TgHzf4 on 5/26 tab. Li Lu unixname = `llu6`.
- **2026-05-25 — RULE 58: NEVER render `L?` placeholder for SEV level.** Resolution: `meta sevmanager.sev describe --sev=S###### -o json | jq -r '.severity'` returns L0…L4. If null (rare — only freshly-opened pre-triage SEVs), retry once after 30s; if still null, render `<L-pending>` with footnote, NEVER `L?`. Pre-push lint regex `\bL\?\b` → ABORT. Source: comment AAAB6TgHzfQ on 5/26 tab.
- **2026-05-25 — RULE 59: Section 9 (Oncall Improvements / Systemic Issues) sort by oncall actionability DESC.** Order: (1) operator-blocking surfacing items (e.g., `S665454 missing from §4`); (2) cross-shift learning items (CL-NNN updates, R-NNN root-cause findings); (3) bot-internal hygiene LAST with `[internal]` prefix badge (e.g., `[internal] P56 pattern proposal — needs review`, `[internal] triage_events table empty — investigate cron wiring`). Operator can fast-skip the `[internal]` badge tier. Source: comment AAAB6TgHzfM on 5/26 tab.
- **2026-05-25 — RULE 60: Section 5 (SEVs handled this shift) row format — structured columns, no prose.** Schema: `# | SEV | Lvl | Title | Tagged? | Status | Action`. `Tagged?` cell = `✅ mvai-online-training` (auto-tag present) or `❌ untagged — review` (auto-tag missing). `Action` cell = concrete `<owner-unixname>: <verb>` (e.g., `incoming-oncall: tag if in-scope`, `lupaul: post mitigation`), never free-form English. AUTO-TAG behavior: cron should auto-apply `mvai-online-training` tag during draft for any §5 SEV missing it WHEN it passes RULE 53(1) OT-SEV filter — do not leave to incoming oncall. Source: comment AAAB6TgHzfI on 5/26 tab (re: items #9 S665454, #10 S665214).
- **2026-05-25 — RULE 40: NEVER write `PAGEd → <user>` without verifying.** Required checks before claiming a SEV was paged: (1) `meta sevmanager.sev describe --sev=S######` → check `auto_detected` field (true = automated trigger) AND `detection_method_tags` (look for `alert/` or `oncall_page/` markers, NOT `dashboards/`); (2) `meta sevmanager.chat list --sev=S######` → check first chat message author; if it's the SEV owner posting context (e.g., "#dataops monitor"), they OPENED the SEV manually, not got paged. SEV's `opened_by` + `journalist` fields = the human who created it, NOT the page recipient. Source: comment AAAB6TgHzXk on 5/26 tab — I claimed `S667687 PAGEd → andrewxmao` when actual: andrewxmao opened it manually as L4 from dashboard. Memory: `gotcha_sev-page-vs-self-open`.
- **2026-06-02 — RULE 64: Clickable IDs are a BLOCKING pre-push lint, not just a spec.** RULES 35/44/53 already mandate `<a href>` on every S/D/A/T, yet the 2026-06-02 08:52 render still emitted bare `S668689`, `S669904` (operator comment `AAAB8p7d1wU`: "SEV/post/alert in oncall shift should be clickable"). Spec without enforcement drifts (P-011). Pre-push gate: `grep -oE '\b[SDAT][0-9]{5,}\b' <draft.ghtml>` and for each hit assert it sits inside an `<a href=`; any bare ID → ABORT and linkify before push. Applies to ALL sections incl. Overview bullets and shift-character.
- **2026-06-02 — RULE 65: WP user-report entries MUST carry a topic keyword, not just author.** Operator comment `AAAB8p7d1wE`: "need keywords for the post. Currently they are mainly username, which is not helpful." Format each entry `<author-link> — "<3–6 word topic>" (<post-link>)`, topic = first line of post `message` (strip leading `#`, truncate ~60 chars). Never render an author name alone. Applies to the Overview `{{WP_AUTHORS}}` line AND the Section-5 table.
- **2026-06-02 — RULE 66: SLICK fallback MUST emit the dashboard links and NEVER assert "healthy" or an SLI count the probe did not return.** Operator comments `AAAB8p7d1vo` ("no, I see some are red") + `AAAB7ndcDqA` ("why only 10? The link shows 24"). If `meta slick.sli list/performance` returns empty/errors, render BOTH dashboard links (`https://fburl.com/monitoring/rkhcqpuj` Discovery, `https://fburl.com/monitoring/gmdu02yq` Instagram) + "status not auto-verified — open dashboards". FORBIDDEN: a fabricated "✅ healthy — all N SLIs OK". Pre-push lint: `grep -E 'healthy.*all [0-9]+ SLIs' <draft>` → ABORT unless every SLI status came from a non-empty `slick.sli performance` row.
- **2026-06-02 — RULE 67: Drop the "Paul already posted to WP / handover time" meta-line.** Operator comment `AAAB8rj6jRQ`: "adds no value." The outgoing→incoming line already conveys the handover; a separate `👤: <name> → WP shift summary (HH:MM) · handover → <name> (HH:MM)` line is noise. Do not emit it.
- **2026-06-02 — RULE 68: Notes-repo / auto-learnings references MUST be links, not bare paths.** Operator comment `AAAB8p7d1wI` (on `auto-learnings/digests/2026-W23.md`): "need to link notes repo, so the audience have more details." Render any `auto-learnings/...`, `references/...`, `known-patterns.md` reference as a clickable internal URL, never bare text.
- **2026-06-02 — RULE 69: "Diffs closed (oncall): 0" is almost always a query miss — verify before rendering 0.** Operator comment `AAAB7ndcDqI`: "what's the criteria? I doubt it's really 0." Paul's same-week WP post listed ~11 oncall diffs. If the diff query returns 0, cross-check the outgoing oncall's WP-post diff table AND `meta phabricator.diff list --author-is=<outgoing> --status-is=Closed --updated-after=<WINDOW_START>` before rendering; if still 0, render "0 (verified: <query>)" so the criteria is auditable, never a bare 0.
- **2026-06-02 — RULE 70: Carryover SEVs WITH oncall engagement this shift MUST be pinned into HIGH-TOUCH — never dropped.** RULE 53(2) excludes carryovers WITHOUT engagement; the inverse failed on the 2026-06-02 render — `S665454` (Threads U2M stuck) and `S669019` (Reels MB9 OOMs) were dropped from HIGH-TOUCH despite the outgoing oncall foregrounding both in his WP post (Ongoing + SEV table) with diffs/gchat this shift. Inclusion gate: a carryover (created < WINDOW_START, status In Progress) enters HIGH-TOUCH if ANY of (a) outgoing/incoming oncall posted in the SEV gchat this shift, (b) a diff cross-referencing the SEV landed/updated this shift, (c) the SEV appears in the outgoing oncall's WP shift post. Pre-push lint: diff HIGH-TOUCH against the outgoing oncall's WP-post SEV list — any SEV present in BOTH the WP post AND the open-carryover set but MISSING from HIGH-TOUCH → ABORT. Anti-regression: `S665454`, `S669019`.
- **2026-06-02 — RULE 71: Canonical "SEVs this shift" count = CONTRIBUTION, not ownership.** Operator decision (thread `8IyKRxB9wPE`): the headline SEV count is SEVs where the OT oncall engaged via ANY of {ownership, gchat msg, attached diff/task, SEV-page comment, WP-post mention} — matching the outgoing oncall's WP framing. Anti-regression: 2026-06-02 the bot rendered "7 HIGH-TOUCH" (ownership) while Paul's WP post listed ~11 (contribution); operator: "real number is 10ish." Render ownership as a parenthetical sub-figure: `SEVs this shift: <contribution_N> (<owned_N> owned)`. The contribution count is the hero number.
- **2026-06-02 — RULE 72: PRESERVE the operator's "Local notes (Bot — don't touch it)" section verbatim across every render.** Operator comment `AAAB8rj6jVk`: the tab carries an operator-owned `Local notes (Bot — don't touch it)` section; the template now has a `{{LOCAL_NOTES}}` placeholder for it. On EVERY (re-)render: first read the existing `Local notes (Bot — don't touch it)` block from the CURRENT tab and carry it forward VERBATIM into `{{LOCAL_NOTES}}`. NEVER generate, edit, overwrite, or drop its content — bot is read-only on that block (same class as operator comments). Brand-new tab with no prior block → emit the heading + empty placeholder only.
- **2026-06-06 — RULE 73: the RULE 64 clickable-ID lint + bold-lead-label pass MUST run on the INTERACTIVE comment-driven insert path, not just cron renders.** Operator comments `AAAB85kcND0` ("diffs should be clickable like sevs; content should be scannable, key msg in bold") + `AAAB85kcNCY` (Impact diffs) on tab `6/9`: the `Impact this shift` "Diffs this shift:" line shipped with **10 bare, unclickable D-numbers** even though RULE 64 already mandates `<a href>` on every `[SDAT]\d{5,}`. Root cause = same class as RULE 61-bis: the offending content was hand-inserted MID-SHIFT by an interactive session answering operator comments (via `gdocs content insert-html` / `batch-update`), a path that NEVER runs the cron's pre-push RULE 64 lint. Generalize: **every write to the shift doc — cron Tuesday render, cron WED–MON mid-shift refresh, AND any interactive session inserting/editing content in response to operator comments — must, before declaring done, (a) run RULE 64** (`grep -oE '\b[SDAT][0-9]{5,}\b'` over the to-be-written/just-written text → each hit must sit inside an `<a href>`; bare `D######` → `https://www.internalfb.com/diff/D######`, bare `S######` → `https://www.internalfb.com/sevmanager/view/######`) **and (b) bold the lead label of every Impact / Overview / Pain-Points bullet** (key message in bold per `AAAB85kcND0`; `<b>Diffs this shift:</b>`, `<b>Zombie-job management (highlight):</b>`). On an already-committed live insert that lacks links, the comment-safe retrofit is **style-only** `batch-update updateTextStyle` with `link`/`bold` over the exact `D######`/label ranges (NO `deleteContentRange`/`replace` — preserves comment anchors), then verify links landed + comment count unchanged. Anti-regression: tab `6/9` Impact section, 2026-06-06.
- **2026-06-06 — RULE 74: the `🚨 Critical alerts (paged / robocalled)` section lists ONLY real pages, never by-design noise or a "no robocalls" non-statement.** Operator comments on tab `6/2`: `AAAB85kcNEU` ("then what's the point?" on a `No confirmed robocalls — …` bullet) + `AAAB85kcNEQ` ("the alert link is invalid" on an `[Invalid Detector - No Data]` alert listed as critical). Two failure modes the section must never have: **(a) by-design / invalid alerts masquerading as pages** — `[Invalid Detector]`, `[No Data]`, `[Preemptive]`, auto-cleared, and any `auto_detected=false`-manually-opened SEV do NOT belong in the paged/robocalled section (nothing robocalled a human); route them to the relevant lower section or omit. **(b) padding with a status-quo non-statement** — if zero confirmed robocalls this shift, do NOT emit `No confirmed robocalls — …`; instead LEAD with the page-eligible **MAJOR** alerts that could page (per the resolved `AAAB8zSlyDY` rule), and if there are none either, collapse the entire section to a single line `No pages or robocalls this shift.` — never a multi-bullet 🚨 section implying critical activity that did not happen. **(c) A### link form (reinforces RULE 64 for alerts):** every `A<feed_id>` MUST link to the resolvable `short_id` from `meta oncall.feed metadata --id=<feed_id> -o json` — the bare `…/onedetection/alert?alert_id=<numeric_feed_id>` form is a 404 trap (the real `alert_id` is the long `1201…%40%23%24…` expression, NOT the feed id). Pre-push lint: any `onedetection/alert?alert_id=<digits>` href with a purely-numeric `alert_id` → ABORT (must contain the `%40%23%24` detector expression). Anti-regression: tab `6/2` Critical section + alert `A844952808102065`, 2026-06-06.
- **2026-06-06 — RULE 75: the paged-alerts section is named `🚨 SEVs and Alerts Oncall Got Paged`, and its page-eligible sentence must be grammatical.** (a) **Rename** (operator comment `AAAB85kcNFw` on tab `6/9`: "Change the template: rename it to 'SEVs and Alerts Oncall Got Paged'"): the section heading is now `🚨 SEVs and Alerts Oncall Got Paged` — NOT "Critical alerts (paged / robocalled this shift)". The new name is the canonical reference everywhere (template `<h3>`, section contract, this prompt). (b) **Grammar** (operator comment `AAAB85kcNFs` "the english gramma is wrong. fix it. and add prevention"): the page-eligible MAJOR-alerts sentence MUST be `These alerts page mrs_online_training on breach` — the subjectless `These page mrs_online_training on breach` is ungrammatical (reads "page" as a noun). Prevention: pre-push lint `grep -nE 'These page ' <draft.ghtml>` → ABORT (must be `These alerts page`). Generalize: render full sentences with an explicit subject, never a bare demonstrative + verb. Anti-regression: tab `6/9` paged-section heading + "These page" bullets, 2026-06-06.
- **2026-06-06 — RULE 76: the Impact "Diffs this shift" line must LEAD with a derived one-line highlight (theme → operational benefit), not just enumerate diffs.** Operator comment `AAAB85kcNF0` on tab `6/9`: "one highlight: all major alerts now have shift-triage diff improvements. This gives oncall more headroom time before being paged. you should be able to derive this highlight. also debug how to ensure you are capable for this as well." Enumerating diffs (even clickable+bold) is bot-as-database; the operator wants the bot to SYNTHESIZE what the diffs collectively mean for the oncall. **Capability (the derivation step, run in Step 6b before rendering Impact):** after assembling the shift's landed+drafted diffs, classify each by what it improves (observability/event-logging, detector retune / false-page suppression, shift-left WARNING tier, freshness/instrumentation, false-alarm guards) and emit ONE bold lead sentence naming the dominant theme + its operational benefit for the oncall — e.g. `<b>shift-triage improvements landed across all major alerts → more oncall headroom before a page.</b>` — THEN the enumerated clickable diffs. The benefit must be oncall-facing (lead time before paging, fewer false pages, faster detection), derived from the diff cluster, never hand-waved. **The highlight must show the CAUSAL MECHANISM, not just assert the benefit** (operator follow-up `AAAB85kcNF0` "really? do you think current content communicates this situation well?" — a generic "shift-triage improvements → more headroom" reads as a slogan; the reader can't tell HOW). Name what specifically changed and how it delivers the benefit, e.g. "every major-alert class got a shift-left fix that buys lead time before a hard page: FULL_SNAPSHOT false-pages suppressed by detector retune, issues surface at a new WARNING tier with agent deep-triage before escalating, freshness + delta-publish instrumentation catch staleness proactively — so the oncall is warned and triaged earlier, not cold-paged." Mechanism → benefit, concrete, then the supporting diffs. Pre-push check: the `Diffs this shift:` bullet's first sentence after the label must be a bold mechanism→benefit clause, not a bare diff id and not a benefit assertion with no mechanism. Generalize to all enumerated Impact bullets: lead with the derived "why it matters", enumerate second. Anti-regression: tab `6/9` Impact diffs line, 2026-06-06.
- **2026-06-06 — RULE 77: SLICK-hygiene is a first-class Impact highlight when SLI entries were cleaned this shift.** Operator comment `AAAB85kcNGU` on tab `6/9`: "add a highlight: SLICK got 3 major improvements — 1/ removed dead entries 2/ backfilled empty entries (Clement) 3/ fixed incorrect setting." When the shift cleaned the SLICK roster (dead-entry removal, empty-entry backfill, misconfig fix), Impact MUST carry a bold `SLICK hygiene (N fixes this shift):` bullet stating what was cleaned + why it matters (violation counts now reflect real freshness, not stale/empty rows). Derive from the SLICK config-change audit (`meta slick.config` history / oncall notes), not narration.
- **2026-06-06 — RULE 78: SLICK status renders at MODEL level within each bucket, not just a bucket aggregate.** Operator comment `AAAB85kcNGM` on tab `6/9`: "slick result should be in bucket level. e.g: IG slick should mention 4 models." Each SLICK bucket bullet (Discovery Online Models, Instagram Online Models) must enumerate its member models with per-model SLI-violation status — e.g. `Instagram Online Models 🔴 30/48: ig_organic_feed_mtml (N viol), ig_textpost_feed_m2m_retrieval (N), …` — built from `meta slick.sli list --service-id=<bucket_sid> -l 500` grouped by model. The bucket count stays as the headline; the per-model breakdown follows. Never fabricate model names or counts. **WORKING INVOCATION (root-caused 2026-06-06 — the "flakiness" was a wrong query):** `slick.service list --oncall=mrs_online_training` returns nothing because the OT SLICK buckets are owned by `pe_mrs_ml`, NOT registered under the `mrs_online_training` oncall — so oncall-scoped discovery is a dead end. Use the known service-ids directly: Instagram = `mrs_ml/v1_instagram`, Discovery = `mrs_ml/v1_discovery`. Per-model violation status: `meta slick.sli performance --service-id=mrs_ml/v1_instagram --start-time <shift_start_epoch> --end-time <now> -l 500 --output=json` → each row has `spatial_bucket` (the model), `sli_name` (the metric), `status` (OK/VIOLATION), `performance` vs `goal`; group violations by `spatial_bucket` to get worst models. (Verified live: IG 8/49 across ig_reels_tab_mtml(4)/ig_textpost_feed_m2m_retrieval(Reranker 0%)/u2m/esr/vm_esr; Discovery 31/162 worst facebook_ifr_main_mtml_main(5).) Only fall back to dashboard-links + "not auto-verified" (RULE 66) if THIS query errors — never a guessed list. **SKIP TODAY'S RECORDS (operator AAAB85kcNGM follow-up 2026-06-06 "always skip today's records as they are lagging"):** set `--end-time` = start of TODAY (UTC midnight), NOT now — today's freshness/publishing SLIs read as breached on incomplete data → false violations. Verified 2026-06-06: incl-today IG 8/49 + Discovery 31/162, but excl-today IG 1/49 + Discovery 7/162 — ~75-90% were today-lag false positives (the only real IG violation was ig_textpost_feed_m2m_retrieval Recurring-Training Reranker at 0%). **LIST ALL failures per group** (model + metric + perf-vs-goal, grouped by `spatial_bucket`) — it is an audit list, not "worst few" (operator "list all failures for IG, I want to audit them with you"). **Order: Instagram FIRST, then Discovery** (operator "change your template: show IG slick first").
- **2026-06-06 — RULE 79: Pain Points / fix-status bullets use the "N bugs fixed, gaps remain" framing — never imply a class is fully solved.** Operator comment `AAAB85kcNGI` on tab `6/9`: for the zombie blind-spot, "we should mention: major bugs are fixed, but the gaps still remain. There could be more failure points and latency issues." When a root-cause class had fixes land this shift, the bullet must state BOTH (a) the specific bugs fixed (with the diff) AND (b) the residual gaps / unguarded scenarios — so the incoming oncall knows the class is mitigated, not closed. Generalize to every "fixed/mitigated" Pain-Point or Hand-off bullet: pair the fix with its remaining exposure. Anti-regression: tab `6/9` zombie blind-spot (EA-exit + D-state fixed via D98638473; gap = SJD kept ticking ~2h before auto-kill, more zombie scenarios + publish latency unguarded), 2026-06-06.
- **2026-06-06 — RULE 80: READ and CONSOLIDATE the operator's "Local notes (Bot — don't touch it)" section into the structured sections every render — preserving the manual block verbatim (extends RULE 72).** Operator comment `AAAB85kcNGc` on tab `6/9`: "Local notes section is manual input. your job should read and consolidate them into your shift repo. but don't delete the manual section." RULE 72 made the block read-only/preserved; RULE 80 adds the INGEST step: parse the Local-notes block for SEV ids / signal the operator captured by hand, and fold each into its proper structured section (HIGH-TOUCH if oncall-engaged, Pain Points, Timeline, Hand-off) so the manual signal is not stranded. Concrete miss this drove: `S668980` (IGR ESR MB7 sparse-delta QPS dip, mitigated 6→10 min publish interval) sat only in Local notes while Overview showed `SEVs (HIGH-TOUCH): 1` — operator comment `AAAB85kcNGY` "S668980 is also another high-touch SEV"; corrected live to `2`. Process: (1) read Local-notes verbatim (never edit/delete it — RULE 72); (2) extract its SEV/diff/signal; (3) reconcile against the data-generated sections and ADD any engaged item the queries missed (cross-checked, not blindly); (4) the Local-notes block itself stays untouched at the bottom. Anti-regression: tab `6/9` — S668980 stranded in Local notes, 2026-06-06.
- **2026-06-09 — RULE 81: Daily Timeline renders DATE-ONLY (drop HH:MM).** Operator comment `AAAB9CvZy8o` ("date is good enough. No need go to hh:ss"). Render `Wed 06-03 — <event>`, not `Wed 06-03 04:13 — <event>`. Clock time is noise for a handoff; the date is the unit. (Exception: keep the time ONLY inside the "SEVs and Alerts Oncall Got Paged" section if a wakeup hour matters — there the time IS the signal.)
- **2026-06-09 — RULE 82: Hand-off items must be VERBOSE + actionable for the incoming oncall.** Operator comment `AAAB9CvZy9E` ("handoff notes should be more verbose to be actionable for next oncall"). Each Hand-off line = what + why-it-matters + owner + the SPECIFIC next action and where to do it (SEV/job/diff link) — not a terse one-liner the next oncall has to re-investigate. The incoming oncall should be able to act from the line alone.
- **2026-06-09 — RULE 83: Local-Notes preservation must be DETERMINISTIC, not prose (RULE 72+80 failed at runtime).** On the 2026-06-09 Tuesday close-out the operator's "Local notes (Bot — don't touch it)" block was WIPED to the empty placeholder (operator comment `AAAB9CsaDKA` "why you removed entries... I told you don't") — even though RULE 72 (preserve verbatim) AND RULE 80 (read+consolidate, keep verbatim) BOTH existed with anti-regression notes. Conclusion: detailed prose rules do NOT reliably fire under the full-tab regen — same class as the narration-leak / relative-path failures (see `recurrence-root-fix-not-prose`). FIX: (a) **durable** — carry-forward must be done in the deterministic template-fill step (code reads the live `Local notes` block from the current tab and injects it into `{{LOCAL_NOTES}}`), NOT left to the LLM remembering RULE 72/80; track moving this into the fill script. (b) **interim guard (HARD)** — POST-PUSH read-back assert: after pushing the tab, re-read its `Local notes` block; if it is empty/placeholder while the captured pre-push block had operator content, the carry-forward FAILED → re-insert the captured block (comment-safe `gdocs content insert-html`) AND send a `⚠️ Local-notes carry-forward failed, restored` line to operator-1:1. NEVER leave the section wiped. Recovery for the 2026-06-09 loss: operator's text is in Google Docs File → Version history (pre-08:30 revision).
- **2026-06-06 — RULE 81 (STRUCTURAL — the deeper fix): run `team_bot/tools/shift-doc-lint.sh` as a HARD gate on EVERY write path; it is the executable form of the prose pre-push lints, which kept getting skipped.** Retro across 2026-06-06 (17 operator comments in one day) found the meta-pattern: the recurring failures (bare/broken IDs, subjectless grammar, by-design noise in the paged section, "no robocalls" non-statements, bare TODOs) are ALL already covered by prose "pre-push lint: grep X → ABORT" rules (35/61-bis/64/73/74/75) — yet they recur because a human/LLM is trusted to run greps by hand, and that step is skipped under task focus, ESPECIALLY on interactive mid-shift hand-inserts. Fix: those greps are now ONE script. **Mandatory:** (a) cron Tuesday render AND WED–MON mid-shift refresh pipe the filled ghtml through `shift-doc-lint.sh` before `gdocs replace`/`insert-html` — non-zero exit ABORTS the push; (b) any INTERACTIVE session editing the doc must run `bash team_bot/tools/shift-doc-lint.sh --doc <DOC> --tab <TAB>` (the COMPLETE gate — ghtml checks #1–11 AND the docs-API font-audit #12, which catches the HEADING-on-`<li>` oversized-font bug that ghtml hides) and reach exit 0 before declaring done. The script strips `<aside>` comment blocks + the operator-owned `Local notes` section (out of scope) and checks: bare `[SDT]\d{6,}`/`A\d{10,}` outside `<a href>`, `/diff/<num>` missing D, numeric-only `onedetection alert_id`, `These page ` grammar, `No confirmed robocalls` padding, `[Invalid Detector]`/`[No Data]`/`[Preemptive]` in the paged section, `TODO (oncall)` without the REQUIRED marker. Verified 2026-06-06: on first run against the "fixed" 6/9 tab it caught a still-bare `S670887` in the HIGH-TOUCH bullet that manual review had missed. Synthesis-class rules (highlight mechanism→benefit RULE 76, SLICK model-level RULE 78, fixed+gaps RULE 79) stay prose (judgment calls); add new deterministic checks to the script, not as another prose grep.
- **2026-06-06 — RULE 82: bold is for SHORT LABELS / key terms only — NEVER a whole sentence or a whole bullet.** Operator (2026-06-06, recurring): "the one sentence is in bold. this hurts readability… debug deeper why you keep making the same mistake." **Root cause (the mechanism):** `gdocs content find-replace` and `insertText` make the inserted/replacement text INHERIT the text style of the character immediately before the insertion point. When you insert/replace content right after a bold label (`<b>Diffs this shift:</b>`, `<b>Instagram Online Models:</b>`), the new text comes in BOLD, and the manual "un-bold the body" follow-up gets skipped under task focus — so a whole bullet/sentence ends up bold. It recurred on the NF0 highlight and again on the SLICK-bullet swap. **Fix procedure:** after ANY find-replace/insertText that lands adjacent to a bold run, immediately `updateTextStyle {bold:false}` over the full inserted range, THEN `updateTextStyle {bold:true}` over ONLY the short label. **Enforcement (the real fix):** `shift-doc-lint.sh` check #8 flags any `<b>` span inside an `<li>` that is a sentence (contains `. ` or ends `.` with len>40) or a wall (>110 chars); short label phrases pass. UPDATE 2026-06-07 (operator `AAAB889DKBk` "don't you see problem with the font format?"): the shift-character is NO LONGER a fully-bold paragraph — it is NORMAL text with only key terms bold (the all-bold summary was itself a bold wall). check #8 only scans `<li>`, so the `<p>` summary is not auto-checked, but the rendering rule is now: bold only key terms there too. Anti-regression: tab `6/9` SLICK bullets fully bold after the swap + NF0 highlight, 2026-06-06. UPDATE 2026-06-07 (operator AAAB889DKKY "you said there is mechanism to avoid it, why the problem still happened?"): check #8 reads ghtml `<b>` spans, which INLINE LINKS fragment into short passing pieces — so a fully-bold line broken by links evaded it (the WP-reports line). Added API-based check #14: flag any bullet with >60 bold chars (run-level bold is immune to link fragmentation). Bold = short label only; this now catches link-fragmented bold walls.
- **2026-06-06 — RULE 83: group the Impact "Diffs this shift" line by THEME, with "debug-agent improvement" as a standing recurring theme.** Operator comment `AAAB85kcNIY` on tab `6/9`: "you should have a theme of 'debug agent improvement'. this should be a recurring theme for diffs. many diffs for this shift can be moved to there." Most OT-lane diffs harden the bot's own triage/observability/detection (ETT event-logging, WARNING-tier + agent deep-triage, freshness/delta-publish instrumentation, detector retune, distillation guards) — that IS one coherent theme, not a scattered list. Render diffs grouped by theme; **`debug-agent improvement`** is the recurring bucket (sub-group it by *earlier detection* / *observability* / *false-alarm reduction* and close with the mechanism→benefit per RULE 76). Other themes as they arise (direct-SEV-fix, infra/capacity). The theme label is the bold lead (short — RULE 82); the diffs follow as linked, non-bold content. **`debug-agent improvement` and `shift-left triage` are DISTINCT themes, never merged** (operator follow-up `AAAB85kcNIY` "two distinct themes"): shift-left = catch/preempt earlier so fewer hard pages (detector retune, WARNING tier, freshness checker, delta-publish instrumentation); debug-agent = the bot's own triage/observability capability (ETT event-logging, agent deep-triage, distillation false-alarm guards).
- **2026-06-06 — RULE 84: a hyperlink wraps the CRITICAL TOKEN only (id / short label) — NEVER a whole sentence.** Operator comment `AAAB85kcNIw` on tab `6/9`: "not usable for the whole sentence attached to a link. it should be the most critical ones only." **Same inherit-trap as bold (RULE 82) but for links:** `find-replace`/`insertText` make new text inherit the LINK of the character before the insertion point, so content inserted/swapped right after a linked run (a dashboard-linked group name, a linked id) silently becomes one giant link. Hit it on the SLICK-bullet swap (the whole 487-char IG bullet inherited the dashboard link). **Fix procedure:** after any insert/replace adjacent to a linked run, clear the link on the full new range, then re-apply it on only the short token. Enforced by `shift-doc-lint.sh` check #9 (flags `<a>` whose visible text is a sentence or >45 chars; id/label links pass). **Two hard-won tooling gotchas:** (1) **index drift** — every `insertText`/`find-replace` that ADDS or REMOVES characters shifts the indices of everything after it; re-fetch `meta google.docs structure` IMMEDIATELY before any index-based `batch-update`, never reuse a snapshot taken before another length-changing edit (stale indices silently hit the wrong range). (2) **`gdocs` cannot reliably CLEAR a link** — `updateTextStyle {link:null}`/empty-textStyle returns success but sometimes no-ops, and `find-replace` PRESERVES the matched text's link; a link baked into an old render resists `updateTextStyle`-clear AND `find-replace` (which preserves the matched link). The fix is delete+clean-reinsert: `deleteContentRange` the bullet, then `insert-html` a clean version with the link on the critical token only (verified working 2026-06-06 — `deleteContentRange` is NOT hook-blocked here). Anti-regression: tab `6/9` SLICK bullets + the 6/4-timeline Xiao Zang WP link — all fixed live, 2026-06-06.
- **2026-06-06 — RULE 85: section order — Paged → OT Topline Metrics → Overview(+Impact) → Pain Points → Hand-off → Timeline.** Operator comments `AAAB85kcNI0` ("this section shall move up. and rename to 'OT Topline Metrics'" — the SLICK section) + `AAAB85kcNI4` ("impact this shift section should be consolidated into [Overview]"). The SLICK block is renamed **OT Topline Metrics** and moved up to right after the paged section; the **Impact** bullets are merged INTO Overview (no separate Impact `<h3>`). Live-doc note (CORRECTED 2026-06-06): `deleteContentRange` is NOT hook-blocked in this environment — I verified it with a probe after wrongly deferring the move 3 rounds on that assumption (operator: "this is not moved up" / "I don't see changes"). So structural MOVE/MERGE CAN be done live: insert the block at the new position, then `deleteContentRange` the old one (and re-insert a clean bullet to fix an un-clearable link). The real cost is that delete ORPHANS comment anchors on the removed range (the comments survive, lose their highlight) — so prefer additive ops, but when the operator explicitly demands a structural change, do it live. Done live this round: section moved up, Impact merged into Overview, the stuck Xiao Zang link fixed via delete+clean-reinsert. **META-RULE: never defer on an ASSUMED constraint (a hook, a block) — verify it cheaply first; an unverified "can't" that defers operator-demanded work is worse than the work.**
- **2026-06-07 — RULE 86: mid-shift incremental MUST emit each new day as its own `<h4>` heading APPENDED after the latest existing day — never as `<li>` bullets, never prepended into the prior day's section.** Operator comments `AAAB889DKBI` ("don't you see problems with the format?") + `AAAB889DKBQ` (Overview). The 6/6 + 6/7 incremental produced TWO bugs: (1) the day name rendered as a flat `<li>6/6 (Saturday) — 2 alerts resolved</li>` instead of `<h4>6/6 (Saturday)</h4>`; (2) the new days were PREPENDED at the top of the 6/5 section (before 6/5's own content) instead of appended after the latest day. Plus render noise: `🤖 Bot: ↳ bot:` double-label, `[confidence:med]` internal metadata, and per-day-header `— N alerts` count-suffixes (inconsistent with 6/2–6/4 plain headers). **Required:** new day = `<h4>M/D (Weekday)</h4>` + `<ul>` of NORMAL_TEXT `<li>`; insert it AFTER the last `<li>` of the current latest day (anchor on that day's last bullet text, not on the `Daily Timeline` h3 or a prior day's heading); day headers are plain `M/D (Weekday)` (no count suffix); bucket labels appear ONCE (`⚠️ Watching:`, `🤖 Bot:` — matching RULE 63; NEVER `🤖 Bot-resolved:`, which RULE 90 / check #13 forbid as a false read-only-surface action claim — no `↳ bot:` echo); strip `[confidence:*]`. Enforced by `shift-doc-lint.sh` check #10 (flags any `<li>` whose text is a `M/D (Weekday)` date — a day heading mis-rendered as a bullet). Anti-regression: tab `6/9` 6/6+6/7 days mis-nested as bullets under 6/5, fixed live 2026-06-07. Also fixed this round: removed the redundant Overview `⚠️ REQUIRED — oncall fill: What outcomes changed…` placeholder that sat directly above the actual outcome highlights (zombie/diffs/fleet-health) — once the highlights are present the prompt is contradictory noise (`AAAB889DKBQ`).
- **2026-06-07 — RULE 87: the shift-character summary line must be REGENERATED from current data every incremental run, and stays consistent with the Overview counts.** Operator comment `AAAB889DKBk` ("what mechanism would make the summary line consistent with the new changes?"): the opening summary said "one HIGH-TOUCH prod incident" while the doc had evolved to 3 HIGH-TOUCH SEVs — a hand-typed summary goes stale as the mid-shift incremental adds days/SEVs. Mechanism: (1) the incremental MUST re-derive the shift-character from the live data (HIGH-TOUCH count from the Overview SEV line, open items from the latest day) — never leave the Tuesday-render summary frozen; (2) consistency is enforced by `shift-doc-lint.sh` check #11, which extracts the `N HIGH-TOUCH` from the summary and the `SEVs (HIGH-TOUCH): N` from Overview and FAILS on mismatch. Keep the summary 2 sentences, NORMAL text with only key terms bold (NOT fully bold — RULE 82, operator AAAB889DKBk), and use NO bare S/D ids in it (prose only — bare ids there would trip check #1). **2026-06-07 — RULE 88 (font, recurrence): moving/inserting a section via `insert-html` re-triggers the HEADING-inheritance bug — the `<li>` items inherit the inserted `<h3>/<h4>`'s namedStyleType and render oversized.** On the OT Topline move the 2 SLICK bullets came in as `HEADING_3` (operator `AAAB889DKBU` "do you see problems with the font size?"). MANDATORY after ANY insert-html of a section: re-fetch the docs API `paragraphStyle.namedStyleType` for each inserted body `<li>` and assert `NORMAL_TEXT`; fix any heading-styled line with `updateParagraphStyle {namedStyleType:NORMAL_TEXT}` (comment-safe). The ghtml export does NOT reveal this (it still renders `<li>`), so the check MUST be structure/API-based, not ghtml-based — that's why it's a post-insert step, not a shift-doc-lint check. UPDATE 2026-06-07: this font-audit is now BUILT INTO `shift-doc-lint.sh` as check #12 (runs in `--doc <DOC> --tab <TAB>` mode), so the COMPLETE gate (one command) covers it — no separate manual step needed.
- **2026-06-07 — RULE 89: Pain Points MUST surface the current-week recurring/noisy trends from `auto-learnings/noisy-trends.md`, data-derived.** Operator comment `AAAB889DKFM` ("scribe_read_proxy lag … looks a recurring issue. why it's not called out here? the trending issues and noisy models should be called out per current week's data. any mechanisms ensure this?"). Mechanism: the Pain-Points step MUST read `mrs-ot-agent-context/learnings/noisy-trends.md` for the current week, take the top recurring models/classes by fire-count (e.g. ≥3 fires in the window, or a multi-week-persistent class like CL-003 ZippyDB/Scribe), and render each as a Pain Point with the model ids + fire-count + owning-team handoff. Verified recurring this round and added live: scribe/ZippyDB CL-003 (ig_reels_tab_ss_omni 2144816217 "6th fire in 8d", ig_reels_tab_cs_omni 2130305043, ig_organic_feed 878102693 → S659235) — persistent W20–W23. Pre-push check: if `noisy-trends.md` has a model with ≥3 fires this week and Pain Points names none of the top-3, the trend was dropped — surface it. (Cite from the file, never assert recurrence without the data — self-report rule.)
- **2026-06-07 — RULE 90: the bot is READ-ONLY on alerts/SEVs/WP — NEVER claim it resolved/fixed/mitigated one.** Operator comment `AAAB889DKB8` ("Is the 'bot-resolved' accurate?"): a 6/6 bullet said "Bot-resolved: 2 sparse-delta alerts" but the bot took NO action — they auto-cleared and the bot only observed. Per CLAUDE.md the bot is read-only on every external triage surface, so "bot-resolved/-fixed/-mitigated/-cleared" is always inaccurate. Use "auto-cleared / self-resolved / bot-observed / bot-tracked". Enforced by `shift-doc-lint.sh` check #13 (flags `bot-?(resolved|fixed|mitigated|cleared)`).
- **2026-06-07 — RULE 91: Overview = COUNTS ONLY; the derived insights live in a separate `Highlights` section.** Operator comment `AAAB889DKBQ` ("do we need to spin off 'highlights' section?" + "too lengthy"): merging Impact into Overview (RULE 85/NI4) made Overview a wall. Better design — Overview keeps the one-line category counts (SEVs/alerts/WP/diffs/difficulty); a separate `<h3>Highlights</h3>` (right after Overview) holds the derived insights (zombie mgmt, diffs-by-theme, OT fleet-health, SLICK hygiene, recurring noisy trends). Comment-safe live spin-off = INSERT an `<h3>Highlights</h3>` heading before the first highlight bullet (additive — no delete, no orphaned anchors); then `deleteParagraphBullets` + set `namedStyleType=HEADING_3` on it (insert-html makes a heading inherit the preceding list-item style). Also clarified the paged "page-eligible" jargon to plain language and removed a duplicate page-eligible bullet (`AAAB889DKFY`).
- **2026-06-07 — RULE 92 (META): run a PROACTIVE whole-doc self-review before declaring done — do not wait to be told.** Operator comment `AAAB889DKBQ` ("why you didn't figure out the solution by yourself?"): across this session I was reactive — fixing each flagged comment, often needing the operator to both spot the problem AND propose the fix (the Highlights spin-off was the operator's idea). That is the failure. After the data is rendered and the deterministic gate passes, STEP BACK and red-team the whole doc as a senior PE would, surfacing issues the operator has NOT flagged: (a) **cross-section duplication** — the same SEV/alert/diff/id must appear ONCE (density P0); scan for any id repeated across Paged / OT Topline / Overview / Highlights / Timeline and collapse to one home + pointers (e.g. Overview=counts, detail lives in Paged/Topline). (b) structure — does each section earn its place; is anything better split/merged. (c) every line action-or-investigate, no status-quo padding. (d) accuracy/read-only-vocabulary. Fix or propose these proactively. Mechanism: this red-team pass is a REQUIRED final step of every render (cron + interactive), the same spirit as "Close the Thread" step 1 generalized to every shift doc. **HOW TO STOP BEING REACTIVE (operator AAAB889DKBQ follow-up "how to avoid you being too reactive?"):** the root cause of reactivity is treating each operator COMMENT as the unit of work — fix the flagged thing, reply, wait. Replace that with three habits: (1) **Shift left — gate + red-team BEFORE the operator looks.** Run `shift-doc-lint.sh --doc <DOC> --tab <TAB>` AND the RULE-92 whole-doc red-team at render time, so the operator opens an already-clean, already-complete doc with nothing to flag. The operator is not your QA. (2) **Every fix → generalize to the CLASS + sweep ALL instances now + add a deterministic check.** One bare id flagged → linkify all ids + add check #1; one HEADING-styled `<li>` → audit ALL list items + check #12. Never fix only the single flagged instance. (3) **Success metric = operator-comments-per-render trends to ZERO.** Each class the operator flags once must become a permanent gate check so they never flag it again; if a class recurs, a check is missing — add it. The accumulation of checks (#1–13) IS the de-reactiving: it moves the catch from the operator to the gate. Found proactively this round: heavy cross-section id duplication (S659235 ×3, FULL_SNAPSHOT model-triple verbatim in Paged+Overview) — collapsed Overview→Alerts to a count + pointer (RULE 91).
- **2026-06-07 — RULE 93: every CRITICAL / open NEEDS-YOU item must carry the handles an investigator needs to dig in — and a misfit cross-check.** Operator comment `AAAB889DKGo` ("do you see gaps, when people want to check closer on this issue?"): the 6/7 `facebook_reels_ifu_i2i 2132537419 FULL_SNAPSHOT stall` bullet had a bare model id + "root unconfirmed" with NO way to investigate. Required per CRITICAL/NEEDS-YOU item: (a) resolvable **alert/SEV link** (A### via `oncall.feed metadata` short_id, S### linked); (b) **model→MAST job / SLI dashboard** pointer; (c) the **TRUE owner** — for **STUS** models trace the **root-trainer lineage (R19)**, not the surface model (the ifu_i2i page target was ankankr@root-trainer 877526181, not the surface model owner); (d) a **tracking task** ref if "bot-tracking"; (e) **THRESHOLD_MISFIT cross-check** — before calling a FULL_SNAPSHOT alert a "real stall", check the model's misfit history (ifu_i2i is a known FULL_SNAPSHOT THRESHOLD_MISFIT — "model never publishes FULL_SNAPSHOT", 7th in 30d), label `[INFERRED]` if unverified. If the specific alert is not in the active oncall feed (cannot verify a per-alert short_id), DO NOT fabricate an alert URL (cheatsheet: a 404 is worse than no link). **Resolution order (2026-06-07, operator AAAB889DKRQ/DKTU "why slick link, instead of alert link?" — SUPERSEDES the old SLICK-dashboard fallback):** (1) live feed short_id/url; (2) the alert's **captured `.url` from `state/alert-state.json` `diagnosed_ids[*].url`** — `ot-alert-monitor` snaps it at detection time (its step 7.e) precisely because alerts auto-clear before the render and can't be re-resolved; (3) if BOTH are empty, leave the model-id token **BARE** — **NEVER substitute a SLICK group-dashboard link** (Discovery=rkhcqpuj / Instagram=gmdu02yq). A SLICK dashboard is group SLO health, not the alert; it belongs ONLY in OT Topline Metrics, never as the clickable on a CRITICAL/NEEDS-YOU/alert reference. **2026-06-07 — RULE 64-ext (operator AAAB889DKGo "alerts, SEVs, and posts should have url attached"):** clickability covers ALERTS too, including alerts cited by MODEL-ID + symptom (e.g. "878102693 SPARSE_DELTA", "FULL_SNAPSHOT misses on 2130324780") — not just A###. Attach the alert short_id if resolvable, else the captured `.url` from `alert-state.json` `diagnosed_ids[*].url` (see RULE 93 resolution order); if neither resolves, leave the model-id token BARE — NEVER a SLICK group-dashboard substitute (that fallback is retired as of DKRQ/DKTU 2026-06-07). shift-doc-lint check #1 now also flags bare W### (posts).
- **2026-06-07 — RULE 94: the paged section carries a PAGE-REDUCTION lens, not just a list of what paged.** Operator comment `AAAB889DKHs` ("reducing # of oncall being paged would greatly reduce oncall load — any improvements this section can make for that aspect?"). Beyond listing pages, the section MUST surface the load-reduction signal: (a) classify the shift's pages as **real-actionable vs false/by-design/auto-cleared** (count both); (b) for each **recurring or false** page-source, name the **permanent-fix action + owner** — detector reconfig (e.g. ifu_i2i FULL_SNAPSHOT THRESHOLD_MISFIT → T274815280), threshold tune, upstream capacity (CL-003 scribe), or progress-aware auto-kill (the S670887 SJD gap); (c) cite the page-reducer diffs landed this shift (detector retune, WARNING tier). Turns the section from passive ("what paged") into actionable ("what paged + which were avoidable + the fix") so each shift drives the page count down. Pairs with RULE 89/93 (recurring-trend + investigability) and the P63 fast-path.
- **2026-06-07 — RULE 95: Highlights/body = HUMAN-handoff signal only; bot-autonomous work collapses to ONE FYI footnote.** Operator (1:1, 2026-06-07: doc "skews bot/agent-meta… trim to human-handoff signal, bot-internals to a footnote"; then "improve it"/"now"). The reader is the incoming HUMAN oncall (3-min handoff). Debug-agent/tooling diffs, fleet-health cron mechanics, validator internals are NOT handoff signal — collapse them to a single italic `Bot-autonomous work (FYI, not handoff): …` footnote at the END of Highlights (count not list — "+N observability/triage diffs"; keep only the page-reducer diff links). Headline Highlights bullets stay human: real incidents, root causes, SLI/data-quality, page-reduction. This is the CLAUDE.md "human signals only / trunk-health → one-line footnote" rule applied to Highlights.
- **2026-06-07 — RULE 96: auto-derive everything derivable; reserve REQUIRED-fill markers for genuinely-SUBJECTIVE fields only.** Operator comment `AAAB889DKIQ` ("why this needs human input, instead of automated?" on the Pain-Points "What systemic issues recurred?" TODO). A field is a human-fill TODO ONLY if it cannot be derived from data. **Auto-derive (NO placeholder):** systemic/recurring issues (noisy-trends.md + SEV/alert recurrence, RULE 89), counts, root causes, impact highlights, page-reduction — render directly; a "what recurred?" placeholder above bot-derived pain-point bullets is redundant + contradictory (same anti-pattern as the removed Overview "what outcomes changed" placeholder). **Genuinely-human (KEEP the bold-red REQUIRED marker):** Difficulty/Hours rating, Wakeups load, qualitative shift experience. Pre-push: a REQUIRED-fill placeholder whose answer is already auto-rendered nearby → drop it. **2026-06-07 refinement (AAAB889DKIs):** even the "subjective" fields get a DATA-BASED PROPOSAL the oncall ADJUSTS — never a bare TODO. Render `📊 Shift metrics (proposed from data — oncall adjust): Difficulty N/5 (<1-line data basis>) | Hours ~Nh | Wakeups N (<source>) | Alert noise N/5` and make it the FIRST Overview bullet (#1 — the at-a-glance summary leads). Propose Difficulty from SEV/page/noise load, Wakeups from robocall count (data), Alert-noise from false-vs-real ratio; Hours stays an estimate. Propose-then-adjust beats blank-TODO. **REVERSED 2026-06-07 (AAAB889DKLg "this can be removed, adds no value" / "just remove it"): the shift-metrics line is DROPPED entirely — proposed Difficulty/Hours are guesses adding no value; page count + SEV/alert/SLI signal already convey load. Do NOT render a metrics line. This supersedes the propose-metrics-#1 guidance above.** **2026-06-07 (AAAB889DKJI — "I got paged multiple times for major alerts", "0 by alerts" was WRONG): the page COUNT must come from the `meta oncall.notification list --oncall=mrs_online_training` ledger, NEVER assumed.** Counting "0 alert pages" because alerts "auto-cleared" was a self-report-rule violation — auto-cleared ≠ not-paged. Mechanism (CORRECTED 2026-06-07 per AAAB889DKLA "oncall only got paged for alerts sent to THEM"): use the **`--escalating`** ledger — `meta oncall.notification list --oncall=mrs_online_training --escalating -l 500 -o json`, filter `created_at >= shift_start`. That returns ONLY notifications that ESCALATED to the oncall (actual pages), NOT the full rotation feed. The non-escalating list (154 this shift, ~20 distinct, 89 raw) is the FEED, not pages — counting it overstated the page load badly. Real this shift: 7 escalated pages (6 critical alerts + 1 SEV robocall S670887). Count page-worthy = escalating rows (+ `source_type=sev` robocalls). This shift: 89 alert pages (6 critical, 83 major, 17 models) + 1 SEV robocall — that high count IS the page-reduction story. **CORRECTED 2026-06-07 (AAAB889DKLA "oncall only got paged for alerts sent to THEM"):** the count must use the **`--escalating`** ledger (`meta oncall.notification list --oncall=mrs_online_training --escalating -l 500`), which returns only notifications that ESCALATED to the oncall (actual pages) — NOT the full rotation feed. The 89/20 were the FEED (overstated). Real this shift = 7 escalated pages (6 critical alerts + 1 SEV robocall S670887). Use --escalating, never the plain feed list, for the page COUNT. **Enforcement (AAAB889DKLA "what mechanisms would ensure this counting accurate?"):** shift-doc-lint check #15 cross-verifies the doc's "N escalated pages" against the live --escalating ledger count for the shift window and FAILS on mismatch. Note the distinction the operator drew: --escalating = alerts SENT-TO / escalated-to the oncall (real pages); the feed also includes SUBSCRIBED/follower alerts (the oncall is a follower but was not paged) — those must NOT be counted. **2026-06-07 (AAAB889DKIk):** the paged section LEADS with a count — `Paged this shift: N total — M by SEV (…), K by alerts (…)` — before the per-item detail.
- **2026-06-07 — RULE 97: exclude model-code / kernel-crash SEVs — they are out of OT scope even when on an OT-relevant model.** Operator comment `AAAB889DKIY` ("why this SEV is included? OT oncall shouldn't care") on S670844 (IMA crash on permute_multi_embs_kernel, owner Arbaz Khan). OT scope = online-training INFRA: publishing, streaming/scribe, OT-job health, staleness/freshness, SLIs. A SEV whose root cause + owner is in the MODEL/MVAI lane (illegal-memory-access / kernel / numerics / model-code) is NOT OT's concern — do NOT list it (not even as observe-only) just because it shares a model_entity_id with a real OT SEV (S670844 was included only because it co-occurred on 2125752019 with the OT zombie S670887). Test before including any SEV: is its root cause + owner an OT-lane surface (publish/stream/scribe/OT-job/SLI) or a model-code surface? Model-code → exclude. (Same spirit as the org-boundary filter in `team_lane_scope`.)
- **2026-06-07 — RULE 98: scope EVERY item to the shift window [shift_start, now]; include only if created-in-window OR engaged-in-window.** Operator comment `AAAB889DKIc` ("shouldn't we only include issues for this shift? what mechanisms enforce this?"): the WP user reports listed W1332046782223398 (created 2026-05-22) and W1336024098492333 (created 2026-05-27) — both PRE-shift (shift started 6/2). Rule: a WP post / SEV / alert belongs only if (a) created within the shift window, OR (b) engaged this shift (oncall gchat / landed diff / SEV closed / resolution in-window). "WP user reports: N" counts ONLY posts AUTHORED in-window; a pre-shift post whose issue resolved this shift goes to the relevant section (HIGH-TOUCH / diffs), NOT counted as a "report this shift" (W1332's Threads-U2M resolution is in HIGH-TOUCH via S665454/D98638473; W1336 had no this-shift engagement → dropped). **Mechanism (enforcement):** the cron MUST fetch `created_time` for every WP/SEV/alert candidate and compare to `shift_start`; pre-window items with no this-shift engagement are excluded. Pre-push: any item with a date/created_time < shift_start AND no in-window engagement marker → drop or move to its resolution section. (Data-verified: meta workplace.post content created-times 5/22 & 5/27.) **Correction (AAAB889DKJE "this is wrong" + AAAB889DKI0 "what's the point of this?"):** "engaged-in-window" INCLUDES pre-shift posts that RESOLVED this shift — do NOT zero them out ("WP user reports: 0") and do NOT add a pre-shift-authoring meta-explanation (pointless noise). Frame by the in-window event: "WP user reports: N (resolved this shift) — <topic linked to permalink> → <fix>". Count items with this-shift ACTIVITY (resolution/engagement), not just authored-in-window. The created_time check is to drop pre-shift posts with NO in-window activity, not to erase resolved-this-shift ones. Also surfaced: model-id ambiguity in a family (2132537419 baseline vs 2132070936 STUS) — disambiguate. This is the proactive-review (RULE 92) applied to each open item: would a reader be able to act on it without re-deriving everything?

## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)

