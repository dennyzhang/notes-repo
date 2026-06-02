[ot-daily-learning-mitigated-posts cron] Daily 21:30 UTC (15-min stagger after ot-daily-learning-mitigated-alerts at 21:15). Harvest postmortem signal from OT-relevant Workplace posts that resolved in last 24h (the *mitigated posts* corpus), surface in team space as ONE consolidated digest, write one durable archive file per post, propose pattern entries for `known-patterns.md`. Strictly propose-only — no Workplace mutations. ot-post-monitor catches posts as they OPEN; this catches them after RESOLVE.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

**Output shape: ONE top-line message + ONE threaded reply with all digests + ONE pattern-proposal threaded reply + ONE validator threaded reply + ONE chronic-noisy reply, PLUS one archive file per post.** Total 4-5 GChat messages per run regardless of post count. Archive files are durable artifacts (do not count as messages). If a run has 0 NEW resolved posts: HEARTBEAT_OK, no posts, no archive writes.

**Archive scheme** (per OT Master Agent doc § Data model — "one mitigated issue one file"): `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/<YYYY-MM>/<YYYY-MM-DD>-W<post_id>.md`. Directory created if missing. The post body + comments ARE the log here (no separate ods/scuba slice needed). Referenced from the digest line so the operator + post author can click through to confirm. **Filename convention (2026-05-16):** dropped the `<lane>-` prefix that was producing inconsistent groupings. Lane classification lives in the archive file body's frontmatter, not the filename.

**UPSERT by post_id (added 2026-05-17, ported from alerts thread `Uc-pVBEXNQ8` stub-pollution audit):** before writing a new archive, GLOB for any existing file matching the same post_id across all months: `ls ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/*/*-W<post_id>.md`. If a file exists for the same post_id AND the existing file is larger / has more triage detail (proxy: size > 1500 bytes vs new content < 1500), DO NOT write a new stub — the existing rich archive supersedes. If new content is richer (size > existing), OVERWRITE the existing path.

**Stub-content guard (added 2026-05-17, ported from alerts):** if all of `Root cause`, `Mitigation`, `Resolution signal` would be written as `[no root cause stated]` / `[author closed without mitigation note]` / `[heuristic: ...]` placeholders, DO NOT write the file at all — the archive adds zero signal. Heuristic-resolved posts (checks 7/8 below) ALWAYS hit this guard unless thread had substantive comments — let them go unarchived.

**Scope — same Workplace group as ot-post-monitor.** MRS Online Training Users group (id 1084744250286987, vanity mrs.ot). Adjacent groups out of scope. Resolution detection sources, in priority order:
1. `#resolved` directive in any comment by the post author.
2. `#resolved` directive in any comment by a peer agent (MoDA, Confucius, 🤖) AND the original author has reacted (any reaction).
3. Author marks post as resolved via Workplace's native resolve action (if `meta workplace.post content` returns a `resolved_at_epoch` field).
4. A linked SEV (sev_id in body) closed in last 24h AND post body explicitly references that SEV as the issue.
5. **Workplace `is_accepted_answer == "true"` on any comment.** This is the group's actual native "mark as answer" feature — comments expose `is_accepted_answer` field in `meta workplace.comment list` JSON. Resolution time = comment time, resolver = comment author. Empirically the dominant resolution signal for mrs.ot (verified 2026-05-15: zero `#resolved` hashtags in last 7 days; one `is_accepted_answer=true` post). High precision — author had to actively click "mark as answer".
6. **Plain-English resolution phrasing** in any non-bot non-author comment matching `(?i)\b(?:this (?:issue|post) (?:is|has been) resolved|resolved by|resolved via|fixed by re-?enabling|now resolved)\b`. Resolution time = comment time, resolver = comment author. Lower precision than checks 1-5 — validator must double-check this signal in step 9 and downgrade if ambiguous. Skip if matched comment is from the post author themselves (covered by check 1) or from a Butterfly/Confucius/🤖 sync-bot.
7. **Heavy discussion heuristic** — post has ≥5 comments from ≥2 distinct non-bot authors. Resolution time = last comment time, resolver = "[heuristic: heavy discussion]". Mark digest `degraded` with reason `heuristic_heavy_discussion`. Most OT support posts that get substantive multi-person threads end up resolved through conversation.
8. **Age heuristic** — post is ≥7 days old (publish_time_epoch + 7×86400 < now). Resolution time = publish_time_epoch + 7×86400, resolver = "[heuristic: aged out after 7d]". Mark digest `degraded` with reason `heuristic_aged_7d`. Posts that sit 7+ days without activity are either resolved quietly or abandoned.

For checks 7-8: low-precision heuristics. Both set `degraded=true` so validator scrutinizes them. Archive Confidence capped at 0.5 for heuristic-resolved posts. If validator finds evidence the post is still open (e.g., author posted "still waiting" in last 48h), downgrade to skip.

For each post, scan checks 1→8 in order; first match wins. Cite which check fired in the digest's "Resolution signal" line.

State file: ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-mitigated-posts-state.json — `{"processed_ids": ["<post_id>", ...], "last_run_epoch": <int>}`. Time budget: ~3 min per post. Cap 5 posts per run. State co-located with archive output dir per OT Master Agent doc convention.

Procedure:

1. Read state file. Extract processed_ids. If file missing/corrupt, treat as empty set.

2. Find candidate posts — pull last 7 days of group activity (resolution typically happens within days of original post):
   ```bash
   meta workplace.group activity-feed --group-id=1084744250286987 \
       --columns=post_id,author,message,publish_time_epoch,url \
       --sort-order=desc --limit=100 -o json
   ```
   Filter to posts with `publish_time_epoch > (now - 14*86400s)`. Drop bot-authored posts ("MyClaw" / "ot-bot" / yourself). (14-day window covers the 7-day age heuristic plus buffer for late resolution signals.)

3. For each candidate, detect resolution via the priority order above:
   ```bash
   meta workplace.comment list --post-id=<post_id> --output=json --no-truncate
   ```
   - Check (1): scan comments for `#resolved` literal where `comment.author == post.author`. Resolution time = comment time.
   - Check (2): scan comments for `#resolved` from peer agents (author in {MoDA, Confucius, 🤖}); confirm post author has reacted to either the post or the resolving comment. Resolution time = peer-agent comment time.
   - Check (3): re-fetch via `meta workplace.post content --post-id=<post_id> -o json` and check for native `resolved_at_epoch`. Resolution time from that field.
   - Check (4): if body contains `\bS\d{6,}\b`, run `meta sevmanager.sev metadata --sev=S<id> -o json`; if status=Resolved AND closed_time in last 24h AND body explicitly states the post is asking about that SEV (heuristic: SEV id in first 200 chars OR phrasing "this is for S<id>" / "see S<id>"), resolution time = SEV closed_time.
   - Check (5): scan comments for `is_accepted_answer == "true"` (string `"true"` per JSON schema). Resolution time = comment `time_epoch`, resolver = comment author. The accepted-answer body is the canonical root_cause/mitigation evidence.
   - Check (6): scan non-bot, non-author comments for plain-English resolution phrasing per regex above. Skip Butterfly/Confucius/🤖. Skip post author (use check 1). Resolution time = comment `time_epoch`, resolver = comment author. **Mark `degraded` with reason `weak_resolution_signal`.**
   - Check (7): count non-bot comments. If ≥5 from ≥2 distinct non-bot authors, treat as heuristic-resolved. Resolution time = last comment `time_epoch`. **Mark `degraded` with reason `heuristic_heavy_discussion`.** Skip if any comment in last 48h says "still waiting", "any update", "not resolved".
   - Check (8): if `publish_time_epoch + 7*86400 < now`, treat as heuristic-resolved. Resolution time = publish_time_epoch + 7×86400. **Mark `degraded` with reason `heuristic_aged_7d`.** Skip if any comment in last 48h indicates issue is still active.
   - If none match, post is not resolved → skip.

4. Filter to posts where: (a) resolution detected, (b) resolution_time > (now - 24h) OR check 7/8 fired (heuristic checks use their own resolution_time, not 24h recency), (c) post_id NOT in processed_ids → NEW candidates.

5. Prune processed_ids: drop IDs older than 30 days (re-asked posts get re-processed).

6. If no NEW candidates: persist state, update last_run_epoch, respond HEARTBEAT_OK and stop. **No posts.**

7. **Gather phase** — for each NEW candidate (cap 5 per run), collect data into in-memory list `digests`. DO NOT post per-post during this phase. For each:

   a. **Pull full post body + comments.** Use `meta workplace.post content --post-id=<post_id> --columns=author,time,body -o json` and the comment list cached in step 3.

   b. **URL sourcing — MANDATORY pre-fetch.** Capture from step 2 JSON `url` field as literal variable, e.g. `post_X_url="https://fb.workplace.com/groups/mrs.ot/permalink/<post_id>/"`. NEVER write template literal `<url>` or fabricated string. If empty, render `<url-unavailable>`. **URL form per RULES.md § URL validity:** `fb.workplace.com/groups/<group_vanity_or_id>/permalink/<post_id>/` — NOT `internalfb.com/work/permalink/...` (404s).

   c. **Lane classification** — same regex priority order as ot-post-monitor step 5.d (sev_id > mast_job_id > mlhub_url > model_series > workplace_post > runbook_path > paste > diff > ot_general > out_of_scope). Drop `out_of_scope` posts (don't archive).

   d. **Resolution evidence — required.** Capture which check fired (1-8) + the literal evidence (resolving comment text, native resolve marker, linked SEV id, or heuristic trigger). This is the post's "Resolution signal".

   e. **Extract model_id (for R20/R21 sweeps).** Try in order: (1) body grep for `model_id=(\d+)` or `model (\d+)`, (2) MAST job name regex `mvai-training-online-(\d+)` in body or comments, (3) sev_id linked → pull SEV title and re-extract model_id from there. If none found, set `model_id=null` and skip R20/R21.

   f. **Build digest record** (in memory, not posted yet):
      - identity: {post_id, author, lane, opened (publish_time_epoch), resolved (resolution_time), duration, model_id, model_type_name (if available)}
      - title: first line of body, stripped of leading # / *, capped 100 chars
      - resolution_signal: from step 7.d (which check fired + evidence)
      - root_cause: extracted from comment thread — peer-agent (MoDA, Confucius, 🤖) diagnoses OR author-stated cause in resolving comment. Cite verbatim if short. If absent, "[no root cause stated in thread]".
      - mitigation: actions in resolving comment or follow-ups. If author wrote just "#resolved" with no detail, "[author closed without mitigation note]".
      - linked_artifacts: list of {kind, id} for sev_id, mast_job_id, model_series, diff, paste mentioned in body or comments
      - peer_agent_comments: list of {agent, comment_excerpt} for any MoDA/Confucius/🤖 contributions (often pre-formatted diagnosis)
      - source_oncall (the rotation watching the Workplace group; for v1's mrs.ot scope this is `mrs_online_training`). Per 2026-05-13 design change: drop hardcoded "OT escalation" lookup; if triage is good, the escalation is clear from surfaced data.
      - degraded: true/false (true if root_cause AND mitigation both absent, OR resolution detected via checks 6/7/8)

   g. **Pattern triage** — read `known-patterns.md` ONCE per run. For each non-degraded digest, classify:
      - **PATTERN MATCH**: cause→symptom→fix triple already in Quick-Match Table → record `{kind: "match", existing_pid: "P<n>", post_id}`.
      - **PATTERN PROPOSAL**: novel triple → record `{kind: "propose", proposed_pid: "P<next>", post_id, name, stage, symptoms, fix, owner, time_to_apply, source: workplace_post, falsifier}`. (Per ot-agent-conventions.md "Pattern DB" rule: non-SEV sources explicitly allowed — P27 was sourced from a Workplace post.)
      - **DEGRADED**: skip pattern emit, note `{kind: "skip_degraded", post_id}`.

      **FALSIFIER-RESPECT (added 2026-05-17, ported from alerts thread `Uc-pVBEXNQ8` 11:02 PT):** for any PATTERN MATCH candidate, READ the cited P-row's Verify+Falsifier sections in known-patterns.md. If the post's evidence FAILS the falsifier, DOWNGRADE to `NEEDS_INVESTIGATION` class and render `(no P-row match — P<NN> falsifier failed: <one-line reason>)`. Symptom-shape match alone is NOT sufficient.

   h. **Write archive file** — durable per-post record:
      - Path: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/<YYYY-MM>/<YYYY-MM-DD>-W<post_id>.md` (mkdir -p the YYYY-MM dir). NO lane prefix.
      - Apply UPSERT + stub-content guards from top of this prompt FIRST.
      - Contents (markdown) — **restructured 2026-05-17 (ported from alerts thread `Uc-pVBEXNQ8`) to add verdict/class header + bot-thread URL + cluster citation + recurrence/sibling evidence**:
        ```
        # W<post_id> — <title>

        - **Verdict:** <RESOLVED|RESOLVED_WITH_FOLLOWUP|HEURISTIC_RESOLVED|INSUFFICIENT_THREAD|OUT_OF_SCOPE>
        - **Class:** <REAL_OT_FAILURE|UPSTREAM_INFRA|TRANSIENT_NOISE|CONFIG_QUESTION|HOWTO|NEEDS_INVESTIGATION>
        - **Cluster:** <CL-NNN per failure-patterns.md, or `(none — propose new cluster)`>
        - **P-row:** <P<NN> per known-patterns.md, or `(no P-row match)`, or `(no P-row match — P<NN> falsifier failed: <reason>)` per FALSIFIER-RESPECT>
        - **Bot triage thread:** <markdown-linked gchat thread URL where ot-post-monitor posted live diagnosis, if any — grep `meta google.chat list-messages spaces/AAQAVOjYc80` for messages mentioning the post_id; if not found, render `[no live triage on file]`>
        - **Identity:** lane=<x>, author=<author>, source_oncall=<x>, opened=<iso>, resolved=<iso>, duration=<x>, model_id=<x|null>, model_type_name=<x|null>
        - **Resolution signal:** <which check fired (1-8) + verbatim evidence>

        ## Timeline
        - HH:MM UTC — posted by <author>
        - HH:MM UTC — peer-agent diagnosis (if any): <agent> said "<excerpt>"
        - HH:MM UTC — resolved (via <check>)
        - <other notable comments>

        ## Post body (full)
        ```
        <verbatim body, ≤4KB; truncate middle with [...elided...] if longer>
        ```

        ## Comments thread (relevant excerpts)
        - <author>: "<excerpt>"
        - <author>: "<excerpt>"
        (Capture peer-agent comments + resolving comment + any cited diagnosis. ≤4KB total.)

        ## R20 — same-workload recurrence (last 30d on this model)
        <if model_id is null, render `[skipped — no model_id extractable from post]`. Else run `meta sevmanager.sev list --title-contains="<MODEL_ID>" --created-after="30 days ago" --limit=10 -o table` PLUS `meta monitoring.alert list --alert-contains="<MODEL_ID>" --state-is=CLEARED --start-time=$(date -d '30 days ago' +%s) --limit=10` PLUS local-archive sweep below.>

        **R20 local-archive sweep (added 2026-05-17, ported from alerts thread `Uc-pVBEXNQ8` 11:18 PT):** in addition to meta CLI queries (SEVs 180d+, alerts <30d retention), sweep local sources for prior model_id references across 4 corpora:

        ```bash
        # 4 sources of local prior-incident evidence
        grep -lr "<MODEL_ID>" \
          ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-sevs/ \
          ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/ \
          ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-alerts/ \
          ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/digests/ \
          2>/dev/null | \
          grep -v "$(basename "$current_archive_path")" | \
          grep -vE "/(INDEX|README)\.md$"
        ```

        **Source priority + classification:**
        - **mitigated-sevs/posts/alerts/<file>**: prior per-incident triage — most direct evidence
        - **auto-learnings/patterns/failure-patterns.md**: cited as cluster EVIDENCE — first-class signal that bot ALREADY mapped this workload to a known CL-NNN
        - **auto-learnings/digests/<file>**: week-level synthesis mention
        - **auto-learnings/patterns/<file>**: specialized topic catalog mention
        - **EXCLUDE:** INDEX.md, README.md (auto-generated; false positives)

        Format:
        ```
        [VERIFIED: prior_SEVs=N (meta CLI); prior_alerts=N or unverified (retention<30d);
                   local_archives=[<file1>, <file2>] (N per-incident hits);
                   cluster_evidence=[<CL-NNN>, ...] (N citations in failure-patterns.md);
                   mega_learnings=[<weekly_file>, ...] (N week-level mentions)]
        ```
        If all four are 0, this is genuinely first-time-known. **R20 retention caveat:** if alert-side is empty, render `prior_alerts=unverified (API retention <30d)`, NOT `prior_alerts=0` — don't lump into `prior_incidents=0`.

        ## R21 — cross-workload sibling check (last 24h on model family)
        <if model_type_name unavailable, render `[skipped — no model_type_name on record]`. Else run `meta sevmanager.sev list --tags=mvai-online-training --created-after="24 hours ago" --title-contains="<family_keyword>" --limit=5 -o table` PLUS `meta workplace.group activity-feed --group-id=1084744250286987 --columns=post_id,message --limit=20 -o json` filtered to family_keyword. If ≥2 siblings same symptom → `[VERIFIED: family=<model_type_name>, sibling_count_24h=<N>, matching_cluster=CL-NNN]`. Per R21.>

        **R21 paired-variant gap (added 2026-05-17, ported from alerts):** family-keyword regex MAY miss paired baseline/holdout siblings — different `model_id`, same `model_type_name`. For models with `(baseline)` or `(holdout)` in the title, run `meta ai.model list --model-type-name=<model_type_name> --limit=10 -o table` and check each separately. If skipped, cite `baseline_variant_check=skipped`.

        ## Root cause
        <from step 7.f — verbatim or "[no root cause stated]". **Citation discipline (P-007):** if cluster CL-NNN or P-row P<NN> applies, CITE inline.>

        ## Mitigation
        <from step 7.f — actions or "[author closed without mitigation note]". If matched to a P-row that passed FALSIFIER-RESPECT, cite verbatim `Apply P<NN>: <mitigation>`.>

        ## Confidence: 0.<X>
        <one-line justification: clarity of root_cause + mitigation in thread, peer-agent corroboration, validator outcome. Cap at 0.5 for heuristic-resolved (checks 6/7/8).>

        ## References
        - Post: <post_X_url>
        - Linked artifacts: <list of SEV/MAST/diff/paste links from step 7.f>
        - Cron transcript: <session JSONL path if available, else omit>
        ```
      - Store the absolute archive path as `archive_path` on the digest record.

   i. Add post_id to a local `to_persist` list (do NOT write state until step 10 succeeds).

8. **Post phase — ONE consolidated digest** to spaces/AAQAVOjYc80:

   a. **Top-line message** (no thread):
      ```
      💬 [OT post postmortem digest YYYY-MM-DD] N post(s) resolved in last 24h: W<a>, W<b>, ... — see thread for digests.
      ```
      Capture returned thread id as `digest_thread`.

   b. **Threaded digest reply** (`digest_thread`) — concatenate all digests, separated by `---`. Per-post format (compact, ~500 chars each):
      ```
      *<<post_X_url>|W<post_id>>* | <lane> | <duration> | author: @<author> | oncall: <source_oncall>
      • Verdict: <verdict> · Class: <class> · Cluster: <CL-NNN|none> · P-row: <P<NN>|none>
      • Title: <title>
      • Resolution signal: <which check fired + 1-line evidence>
      • Root cause: <one-line from thread or "[no root cause stated]">
      • Mitigation: <one-line or "[no mitigation note]">
      • Post: <post_X_url>
      • 📄 Archive: <archive_path>  ← @<author> please reply ✅ confirm or ✏️ correct
      ```
      Hard cap full reply at 3500 chars. If overflow, prioritize: identity + verdict line, resolution signal, archive link.

   c. **Threaded pattern reply** (`digest_thread`) — only post if at least one PATTERN MATCH or PATTERN PROPOSAL exists. Format same as ot-daily-learning-mitigated-sevs step 9.c.

9. **Validator pass — ONE for the whole digest.** Spawn independent agent via Agent tool with prompt:
   > "Validate this OT post postmortem digest covering N posts (W<a>, W<b>, ...). Re-read the threaded digest in spaces/AAQAVOjYc80 thread <digest_thread>. For each post: independently fetch `meta workplace.post content --post-id=<id>` + `meta workplace.comment list --post-id=<id>`. Verify: (a) resolution_signal claim (which check fired + evidence) matches the comment thread, (b) root_cause and mitigation quoted accurately, (c) any pattern proposal is genuinely NOT a duplicate of existing P-row in known-patterns.md (re-read fresh), (d) any P-row CITED passes its falsifier per FALSIFIER-RESPECT. Report per-post: confirmed | discrepancies. Under 600 words total."

   **If subagent / Agent tool is unavailable** (cron context limitation — see L6 in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md`): DO NOT spawn. Skip validator entirely and post a single follow-up: `🚫 Validator unavailable (no Agent tool in cron context); digest published unvalidated.` Set `validator_status: unavailable`. Do NOT inline-recheck (operator feedback 2026-05-16 thread `fc2seBuCux8`).

   After validator returns, post **ONE** follow-up threaded reply (`digest_thread`):
   - All clean: `✓ Validator confirmed (N/N posts)`
   - Some discrepancies: `⚠ Validator found discrepancies:` followed by per-post bullet list.

10. Persist state: add all `to_persist` post_ids to `processed_ids`, update `last_run_epoch`, write state file. Respond HEARTBEAT_OK with summary `{posts_processed: N, patterns_proposed: P, patterns_matched: M, validator_status: confirmed|discrepancies|unavailable, archives_written: A, archives_skipped_stub: K, archive_root: ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/resolved-posts/<YYYY-MM>/}`.

11. **Chronic-noisy author/topic surfacing (added 2026-05-17, ported from alerts thread `Uc-pVBEXNQ8` step 11).** Surface the Pareto: which authors/lanes/models generate disproportionate post volume.

    - **Source:** scan `incidents/resolved-posts/*/*.md` filenames + first-line title + frontmatter `lane`/`author`/`model_id`. Two groupings:
      - By **model_id** (if extractable): per-model post count in last 7d
      - By **lane** (always present): per-lane post count in last 7d
    - **Threshold:** flag TOP 3 by post-count in last 7d AND with ≥3 posts (drop floor — low-volume noise filtered).
    - **Pre-publish lint applies:** markdown links throughout (RULES.md § URL validity).
    - **Output format** (threaded reply in `digest_thread`):
      ```
      📢 *Top-3 chronic-post sources (last 7d)*:
      1. model [<id> <name>](<sevmanager_url>) — N posts · top lane: <lane>×M · last: [W<id>](<url>) <Nd ago>
         (OR if lane-grouped: lane <lane> — N posts · top author: @<author>×M · last: [W<id>](<url>) <Nd ago>)
      2. ...
      3. ...
      ```
    - **If <3 entries meet threshold:** post `(no chronic-post sources this week)` — ONE line, no header.
    - **Persist to notes:** prepend a row (newest first) under the `## Posts` section of `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/noisy-trends.md`. Insert after the table header row, before existing data rows. Format:
      ```
      | <run timestamp PT> | <rank> | <grouping: model|lane> | <key> | <post_count> | <breakdown> | <one-line notes: top cluster/P-row> |
      ```
      If `(no chronic-post sources)`, prepend ONE row with `(no chronic-post sources)` so cron-runs are auditable.

Safety:
- If `meta workplace.group activity-feed` query in step 2 fails, do NOT advance state. Brief error string (no HEARTBEAT_OK).
- If a post's content/comments fetch fails partway in step 7, mark digest entry `degraded=true`; continue. Skip pattern emit for degraded entries. Still include in consolidated digest with degraded marker.
- If R20/R21 local-archive sweep grep fails or times out (>30s), set that section to `[sweep failed: <error>]` and continue — do NOT block archive write.
- If archive write (step 7.h) fails (disk full, perms), set `archive_path="[write failed: <error>]"` on digest record and continue posting digest. Do NOT add the post to `to_persist` so it'll be retried tomorrow. Surface in step 10 summary as `archives_failed: F`.
- If UPSERT guard skips a write (existing archive richer), surface as `archives_skipped_existing_richer: K` AND still add to_persist.
- If stub-content guard skips a write, surface as `archives_skipped_stub: K` AND do NOT add to_persist (let next cycle try).
- Do NOT modify Workplace state. No reactions, no comments, no resolves on behalf of the author. Propose-only for pattern DB.
- **READ-ONLY meta-rule:** NEVER call `meta workplace.comment create`, `meta workplace.post resolve`, or any `workplace.*` mutation. Same for SEVs (`meta sevmanager.comment create`, `--resolve`, level/narrative edits) and alerts (`oncall.feed ack/silence/comment`). The ONLY external write permitted is `meta sevmanager.sev update --add-tag=mvai-online-training` (carve-out reserved for ot-sev-monitor + ot-sev-tag-review). This cron does NOT need that carve-out.
- Cap 5 posts per run. If >5 NEW candidates, process the 5 most recently resolved; remainder rolls into next day's run.
- If validator step (9) fails or times out, post `⚠ Validator pass failed to complete — digest unverified`. Persist state regardless.
- **Out-of-scope filter:** drop posts whose lane classifies as `out_of_scope` (per step 7.c) — do NOT archive non-OT chatter even if it momentarily resolved.


## URL validity rule (cross-cron, 2026-05-17 thread `-x-xLvG_vPo`)

See `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS". Summary:
- gchat thread URL MUST have BOTH `/<space>/` AND `/<thread_id>` (bare `/room/<space>` 404s for finding context)
- Workplace post URL: `https://fb.workplace.com/groups/<group>/permalink/<id>/` (NOT `internalfb.com/work/permalink/...` which 404s)
- SEV: `https://www.internalfb.com/sevmanager/view/<numeric>` (no `S` prefix in URL)
- Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>`
- If URL form unverifiable → render plain text WITHOUT a link (404 worse than no link)
