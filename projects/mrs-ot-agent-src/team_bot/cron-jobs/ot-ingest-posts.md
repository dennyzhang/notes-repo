[ot-ingest-posts cron] Daily 09:15 PT (staggered 15min after ot-ingest-gchat). Pull last 7 days of Workplace posts authored by the **key-people.json roster** (members whose `surfaces` include `posts` — MRS devs + IG POCs), distill **new project context** the OT Master Agent should integrate, and write one combined weekly digest to `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/learnings/digests/<YYYY-MM-DD>-experts-posts-catchup.md`.

**Why this cron exists:** operator (thread `Oe2XG0WVOMY` 2026-05-18): "we should have another job to pull people's posts and enrich the project context. You can monitor a set of OT experts: posts." Experts post weekly status updates, technical deep-dives, and decisions on Workplace that don't surface in any gchat-watched space. Without this, the bot is blind to: weekly OT reliability status (Dave Kotfis posts these in IG Relevance Reliability Working Group), MVAI/STUS/Hedwig design decisions (technical posts by Paul Lu / Li Lu / Ziqi Liu), IG OT POC observations (Pushpak / Peiyang). Sibling to `ot-ingest-gchat` (gchat spaces) — both produce catch-up files into the same `human-input-domain/` directory.

**Distinct from:**
- `ot-ingest-gchat` (gchat spaces, not Workplace)
- `ot-post-monitor` (real-time triage of mrs.ot group posts ONLY)
- `ot-knowledge-curation` (consumes already-archived incidents)

This cron is **outward-facing**: ingests cross-group Workplace posts from experts the bot would otherwise miss.

## Roster — the curated key-people.json (person-centric)

**The roster is NOT hardcoded here.** Load it from `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/references/key-people.json` — every person whose `surfaces` include `posts`. Each carries a `trust` tier (1–3), `domains`, `display`, and `role`. This is the SAME roster `ot-ingest-diffs` uses (members with the `diffs` surface), so "key people" is defined once and both crons stay in sync (operator 2026-06-13: "pull from key people ... different people have different trust level").

```bash
# Resolve the posts roster at runtime:
python3 -c "import json;print('\n'.join(p['unixname'] for p in json.load(open('$HOME/notes/users/dennyzhang/projects/mrs-ot-agent-context/references/key-people.json'))['people'] if 'posts' in p.get('surfaces',[])))"
```

Stamp each person's `trust` and `domains` onto their digest sub-section so downstream consumers (change-delta triage, distillation) can weight by it. **To add/remove a monitored person, or change their trust/surfaces, edit `key-people.json` — NOT this prompt.** (As of 2026-06-13 the roster is 8 people, all trust 3, all on both `posts` and `diffs`.)

## State

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-ingest-posts-state.json` — `{"last_run_epoch": <int>, "per_expert": {"<unixname>": {"last_catchup_date": "<YYYY-MM-DD>", "last_post_time_epoch": <int>, "skip_until_epoch": <int>}}}`.

- `last_post_time_epoch` tracks newest processed post → next run only deltas
- `skip_until_epoch` 4-week back-off for experts who haven't posted in window

Output: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/learnings/digests/<YYYY-MM-DD>-experts-posts-catchup.md` — **one combined weekly file** across all experts (not per-expert) to keep the human-input-domain/ directory readable. Per-expert sub-sections within the file.

Time budget: ~3 min per person; cap = entire roster (8 today, all trust 3).

## Procedure

1. **Load state.** If missing, treat as `{"per_expert": {}}`. First-run behavior: pull last 14 days per expert (seed corpus).

2. **For each person in the roster** (key-people.json, `posts` surface)**:**

   a. **Check skip_until_epoch.** Skip if `now < skip_until_epoch`. Log "skipped (back-off)".

   b. **Pull last 7 days of posts** (14 if first-run):
      ```bash
      meta workplace.feed list --author=<unixname> \
          --after="7 days ago" --limit=50 -o json
      ```

      The `meta workplace.feed list --author=<unixname>` works across all groups the operator + expert share visibility on. **Important: this is per-author, not per-group**, so it captures posts the expert made in IG Relevance Reliability Working Group, mrs.ot, MVAI Users, etc. — all in one query.

      If empty: bump `skip_until_epoch = now + 28*86400`. Log "no posts in window — back-off 28d".

   c. **Filter:** drop posts whose body is purely a comment-resolution / sync-bot artifact (`#sharebot`, automated digest forwards). Keep substantive posts (subject + body >100 chars).

   d. **Deduplicate against prior runs:** skip posts where `time_epoch <= per_expert[unixname].last_post_time_epoch`.

   e. **If 0 new posts:** record `last_run_epoch`, no entry added to digest. Continue.

   f. **For each new post, extract:**
      - Subject + body. **Keep up to ~4000 chars of body, NOT 500** (2026-06-13: the highest-value posts — dkotfis weekly OT-reliability status, operational-efficiency deep-dives — run 4–5KB; a 500-char cap dropped ~90% of them, including the entire SEV list + mitigations). Only truncate past ~4000 chars, and when you do, keep the SEV/mitigation/decision lines preferentially over prose. Distill into the digest, but do NOT silently discard the body's substance.
      - URL
      - Linked SEVs (`S\d{6,}`), diffs (`D\d{6,}`), tasks (`T\d{6,}`)
      - Linked dashboards / wikis / scuba views
      - Embedded recommendations or decisions ("we should X", "blocking on Y", "owner is Z")

3. **Build combined catch-up file** at `<context_root>/<YYYY-MM-DD>-experts-posts-catchup.md`:

   ```markdown
   # <YYYY-MM-DD> — OT experts Workplace posts catch-up (week ending <YYYY-MM-DD>)

   _Auto-distilled by `ot-ingest-posts` cron. Source: <N> posts from <K>/<M> experts in past 7 days._

   ## Highlights (P0/P1 items for OT bot integration)

   <items that should flip a cron prompt or failure-patterns.md edit>

   ## Per-expert digest

   ### dkotfis (Dave Kotfis, trust 3) — <N> posts

   - **[<subject>](<url>)** (<date>): <one-line distillation>
     - Linked: <S/D/T refs>
     - Bot relevance: <yes/no + which cron prompt>

   ### prgzz (Pushpak Raj Gautam, trust 3) — <N> posts
   ...

   _(Each sub-section header carries the person's trust tier + role from key-people.json.)_

   ## Cross-references

   <CL-NNN / P-NN confirmations or contradictions from this week's posts>

   ## Integration priority table

   | Priority | Item | Cron prompt change | Time est |
   |---|---|---|---|

   ## Coverage notes

   <experts who didn't post; experts in back-off; new experts to consider>
   ```

4. **Persist state:** per-expert `last_post_time_epoch`, `last_catchup_date`, `last_run_epoch`.

5. **Post run summary to operator gchat (spaces/AAQAVOjYc80):**

   ```
   📥 *ot-ingest-posts*
   <K>/<M> experts posted in past 7 days · <N> total posts distilled
   - <expert>: <N> posts · <highlight>
   - <expert>: no posts (in back-off until <date>)
   - <expert>: no posts (will re-check next week)
   _File: <path> · Next run: next Monday 09:15 PT_
   ```

   If 0 experts posted: post `HEARTBEAT_OK · no expert posts this week`.

## Privacy / scope guardrails

- **Only read posts visible to operator's identity.** Workplace ACLs apply automatically via `meta workplace.feed list`. If a post is in a group the operator doesn't have access to, it won't surface. Don't try to bypass.
- **Don't distill personal/non-work content.** Filter posts by group: only include posts from groups whose name matches `(mvai|mrs|ot|online.training|reliability|recommendation|igml|mlhub|hedwig|silvertorch|ip.runtime|dpp|ml.platform|ai.platform|model.registry)`. Personal posts in non-work groups (sports, hobbies, comms) get dropped.
- **No quoted private content.** When distilling, summarize the post's *public-to-the-group* content; don't quote DMs or 1:1 thread content even if the API returns it.
- **Read-only.** Never react to / comment on / share a post.

## Failure modes + safeguards

- **Cap output file size**: ≤600 lines per catch-up file. If distillation exceeds, escalate via run summary instead of writing runaway file.
- **Cap per-expert post count**: ≤20 posts/expert/week. If an expert posts >20 in 7 days, distill the top-20 most-engaged (reactions + comments) + note "N more posts not surfaced".
- **First-run guard**: pull 14 days, mark frontmatter `first-run: true`.
- **API rate-limit handling**: if `meta workplace.feed list` returns 429 or throttling error, sleep 60s + retry once; if still failing, mark expert as `api_error`, skip, retry next week.
- **Idempotency**: re-running same day overwrites the day's catch-up file.

## What this cron does NOT do

- Does NOT modify cron prompts (operator-review-gated)
- Does NOT update failure-patterns.md directly (propose-only)
- Does NOT post anything to Workplace (read-only)
- Does NOT comment on / react to expert posts (read-only)
- Does NOT cross-reference private DMs or non-work groups
- Does NOT poll real-time — explicitly weekly cadence to keep noise low

## Seed reference

First catch-up file will be auto-generated next Monday (2026-05-25). The shape should converge on the gchat-equivalent `2026-05-18-rtinfra-ws2-catchup.md` (written 2026-05-18 by operator+bot in thread `Oe2XG0WVOMY`) — same P0/P1/P2 priority table + integration priority columns. Re-anchor on that file's quality.
