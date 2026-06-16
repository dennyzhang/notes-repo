[ot-ingest-gchat cron] Daily 09:00 PT. Pull the last 7 days of activity from a watch-list of external OT-adjacent gchat spaces, distill **new project context** the OT Master Agent should integrate, and write one catch-up file per space to `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/learnings/digests/<YYYY-MM-DD>-<space-slug>-catchup.md`.

**Why this cron exists:** operator (thread `Oe2XG0WVOMY` 2026-05-18) after manual catch-up on `AAQAR1xHaQU`: "build an automation to pull project context weekly." Sibling spaces have decisions, dashboards, owner-routing info, and new tooling that the bot misses because it only watches its own gchat space + Workplace + sevmanager. Without this cron, context-debt accumulates and the bot's triage gets stale (cites old SLO methods, wrong owners, missed dashboards).

**Distinct from:**
- `ot-thread-summarizer` (distills bot's own conversations from sqlite)
- `ot-post-monitor` (real-time triage of Workplace mrs.ot posts)
- `ot-knowledge-curation` (consumes already-archived incidents)

This cron is **outward-facing**: it ingests project context from spaces the bot is NOT the primary participant in.

## Watch list

Hard-coded set of gchat space IDs the cron polls. Add new spaces by editing this prompt + landing a notes commit.

| space_id | display_name | Members | Why watch |
|---|---|---:|---|
| `spaces/AAQAR1xHaQU` | RT Infra WS2: OT Reliability & Understanding | 30 | IG OT SLO + dashboard + bad_sparse decomposition + Breathalyzer + SJD-NCCL deep-dives |
| `spaces/AAQAXSNWvcM` | MVAI OT Dev | 8 | MVAI platform changes affecting OT; small high-signal group |
| `spaces/AAQAtGhVkUw` | IG ATS Alerting | 6 | IG ATS alert config changes; threshold tuning; alert-noise discussions |
| `spaces/AAQATpEgSyk` | MRS Online Training Oncall | 18 | Oncall handoffs, escalation patterns, real-time triage discussions |

## State

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-ingest-gchat-state.json` — `{"last_run_epoch": <int>, "per_space": {"<space_id>": {"last_catchup_date": "<YYYY-MM-DD>", "last_msg_create_time": "<iso>", "skip_until_epoch": <int>}}}`.

- `last_msg_create_time` tracks the newest message we've processed so the next run only pulls deltas
- `skip_until_epoch` lets the cron back off a space that's been quiet for 4+ weeks (re-poll monthly instead of weekly)

Output: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/learnings/digests/<YYYY-MM-DD>-<space-slug>-catchup.md` — one file per space per run. Reference output: `2026-05-18-rtinfra-ws2-catchup.md` (first instance, written manually by operator).

Time budget: ~5 min per space; cap = entire watch list (~4 spaces today).

## Procedure

1. **Load state.** If missing/corrupt, treat as `{"per_space": {}}` (first-run behavior: pull last 14 days for each space instead of 7, to seed the corpus).

2. **For each space in the watch list:**

   a. **Check skip_until_epoch.** If `now < skip_until_epoch`, skip this space. Log to run summary as "skipped (back-off, next eligible <date>)". Continue.

   b. **Pull last 7 days of messages** (or 14 if first run for this space):
      ```bash
      AFTER=$(date -d '7 days ago' -Iseconds)
      meta google.chat.message list --space=<space_id> \
          --created-after="$AFTER" --limit=200 -o json
      ```

      If output is empty or `length == 0`, mark space as quiet: bump `skip_until_epoch` to `now + 28*86400` (4-week back-off). Skip distillation. Continue.

      If `length >= 200`, hit the limit; expand `--created-after` window in 7-day chunks and concat, OR cap at 200 and note "truncated" in catch-up file.

   c. **Filter out bot-noise:** drop messages from `sender_type=BOT` (sync-bots like `🤖`, Butterfly, sevmanager updates). Keep only human-authored messages.

   d. **If <5 human messages in window:** mark as low-signal week, skip distillation, log "low signal (<5 messages)" in run summary. Do NOT bump skip_until_epoch — re-poll next week. Continue.

   e. **Distill the messages into project-context categories.** Read each message; extract items in these categories (skip categories with no hits):

      - **Dashboards / canonical sources of truth** (URLs the team treats as authoritative — SLO dashboards, scuba views, internal pages)
      - **New tooling / Claude skills / agents** the team is rolling out
      - **Sibling agents** triaging the same corpus (coordination risk)
      - **New enforcement levers** (Breathalyzer-class auto-actions, launch gates, alert thresholds being tuned)
      - **New failure-mechanism nuances** (sub-classes the bot doesn't currently distinguish — e.g., bad_sparse vs pure sparse, SIGABRT-cleanup vs NCCL-timeout)
      - **Owner / routing updates** (new owner names for specific subsystems; e.g., Atul Jangra owns SJD)
      - **Workplace posts / wikis / docs** the team references repeatedly
      - **Cross-references to OT bot's clusters** (CL-NNN, P-NN) — when team confirms or contradicts a bot classification
      - **Unfinished cross-team conversations** the operator should re-open

   f. **Build catch-up file** at `<context_root>/<YYYY-MM-DD>-<space-slug>-catchup.md` with:

      ```markdown
      # <YYYY-MM-DD> — <space display_name> catch-up (gchat `<space_id>`)

      _Auto-distilled by `ot-ingest-gchat` cron. Source: <N> human messages spanning <first_msg> → <last_msg> in **<display_name>** (<member_count> members; primary contributors: <top-3 senders by msg count>)._

      _Window: <7d default | 14d first-run | Nd custom>. Skip-until: <if set, when next re-poll>._

      ## P0 — bot-integration-blocking items

      <items the bot should integrate ASAP — wrong-owner, missing-canonical-URL, new-enforcement-lever-not-classified>

      ## P1 — significant nuance / sub-mechanisms

      <new failure-mode distinctions; sub-classes worth a failure-patterns.md edit>

      ## P2 — references / good-to-know

      <wikis, gdocs, Workplace posts; bookmark-only context>

      ## Cross-references

      <CL-NNN / P-NN confirmations or contradictions from this week's chat>

      ## Open coordination threads

      <conversations operator should re-open; sibling-agent dedup conversations; cross-team alignment that didn't conclude>

      ## Integration priority table

      | Priority | Item | Cron prompt change | Time est |
      |---|---|---|---|
      | P0 | <item> | <prompt + section> | <est> |
      | ... | ... | ... | ... |
      ```

   g. **Bump state:** set `per_space[<space_id>].last_catchup_date = today`, `last_msg_create_time = max(msg.create_time)`, leave `skip_until_epoch` unset (active polling).

3. **Persist state file.**

4. **Post run summary to operator gchat (spaces/AAQAVOjYc80):**

   ```
   📥 *ot-ingest-gchat*
   <N>/<M> spaces produced catch-up files this week.
   - <space-slug-1>: <N items distilled> · <P0 count> P0 · <P1 count> P1
     File: <path>
   - <space-slug-2>: low signal (<5 msgs) — skipped
   - <space-slug-3>: quiet — back-off until <date>
   - <space-slug-4>: <N items distilled> · ...
   _State: per_space updated · next run <tomorrow 09:00 PT>_
   ```

   If 0 spaces produced files (all quiet/low-signal): post `HEARTBEAT_OK · all watch-list spaces quiet this week`.

5. **Do NOT modify cron prompts directly.** This cron is propose-only — the integration priority table tells the operator what to land, but landing requires operator review. Operator threads the changes into specific cron prompts during the next hygiene pass.

## Permissions check

The watch-list spaces all require operator's gchat access. If `meta google.chat.message list` returns `Permission denied`, mark the space as `access-denied` in state with `skip_until_epoch = now + 7*86400`, log to run summary, and continue. Operator re-grants access manually + clears skip_until_epoch.

## Failure modes + safeguards

- **Cap output file size**: ≤500 lines per catch-up file. If distillation produces more, escalate to operator instead of writing a runaway file.
- **Deduplication across runs**: if a message was already processed in a prior week's run (per `last_msg_create_time`), don't re-distill. The catch-up file only covers the new delta.
- **Idempotency**: re-running on the same day overwrites the day's catch-up file rather than creating a second one. Safe to re-run.
- **First-run guard**: if `per_space[<space_id>]` is missing entirely, pull 14 days instead of 7 (seed corpus). Mark file frontmatter as `first-run: true`.
- **Bot-spam isolation**: sender filter MUST drop `sender_type=BOT`. If the watch space is hosting another claw, that agent's posts must not feed back into our context.

## What this cron does NOT do

- Does NOT modify cron prompts (operator-review-gated)
- Does NOT update failure-patterns.md directly (proposal-only)
- Does NOT post anything to the watched spaces (read-only)
- Does NOT pull from non-gchat sources (no Workplace / wiki / paste ingestion — that's separate)
- Does NOT alert on individual messages — only daily distillation

## Seed reference

The first catch-up file (`2026-05-18-rtinfra-ws2-catchup.md`) was written manually by operator+bot in thread `Oe2XG0WVOMY` 2026-05-18. Reference its shape + categories for future auto-runs. The cron should converge to similar quality.
