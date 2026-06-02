[ot-knowledge-curation cron] Nightly 23:00 PT (90 min after the three mitigated-* crons finish at 21:00/21:15/21:30). Consume postmortem archives written by `ot-daily-learning-mitigated-{sevs,posts,alerts}`; produce three deliverables: (D1) up to 2 engineering diffs for immediate small gaps, (D2) up to 5 "mega learnings" appended to a weekly curated digest, (D3) one systemic-gap report per month. Complementary to `ot-knowledge-distillation` which operates on real-time triage records — this cron operates on postmortems.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/knowledge-curation-state.json` —
```
{
  "distilled_archive_paths": ["<rel_path>", ...],
  "diffs_drafted": ["D<num>", ...],
  "mega_learnings_count": <int>,
  "last_systemic_gap_month": "<YYYY-MM>" | null,
  "last_run_epoch": <int>
}
```
Time budget: ~10 min on D1+D2-only nights, ~25 min when D3 fires (monthly).

Inputs (three corpora, all written by sibling crons):
- `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/mitigated-sevs/<YYYY-MM>/L<level>-<date>-S<sev>.md`
- `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/mitigated-posts/<YYYY-MM>/<lane>-<date>-W<post>.md`
- `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/mitigated-alerts/<YYYY-MM>/<class>-<date>-A<id>.md` (cron may produce 0 — directory may not yet exist; treat as empty corpus, do not error)

Existing knowledge bases to read fresh on every run (for dedup):
- `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/known_patterns.md` (P-rows)
- `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/human-input/triage-discipline.md` (R-rules)
- `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/human-input/ot-failure-mode-catalog.md` (catalog entries)

## Procedure

1. **Read state file.** If missing/corrupt, treat as empty initial state and create on first write.

2. **Enumerate NEW archives from last 7 days.** Glob all three corpora; filter to files with mtime within 7d; drop paths already in `distilled_archive_paths`. If <3 NEW archives across all three corpora combined → respond `HEARTBEAT_OK` (need cross-issue signal), do NOT post to GChat.

3. **Parse each NEW archive into a structured record.** Files follow the same loose markdown shape used by sibling crons; extract:
   ```python
   {
     "corpus": "sev" | "post" | "alert",
     "id": "S<num>" | "W<id>" | "A<id>",
     "level": "L1"|"L2"|"L3"|"L4" | None,
     "date": "YYYY-MM-DD",
     "title": <first heading or title line>,
     "root_cause": <Root cause / Likely cause text>,
     "mitigation": <Mitigation / Fix text>,
     "owner": <unixname>,
     "rule_cited": "R\d+|P\d+" (regex extract, list),
     "false_alarm": <bool from text patterns>,
     "duration_min": <int if extractable>,
     "model_id": <extract \b\d{8,}\b if present>,
     "stage": "T1"|"T2"|"T3"|"T4" | None,
     "archive_path": <absolute path>
   }
   ```
   Skip records that fail to parse (log only, do not error the run).

4. **Pattern detection across all NEW records.** Two passes:
   - **Pass A (cause-keyword clustering):** normalize root_cause text (strip punctuation, lowercase, stem); cluster records by shared 3+ keywords or matching regex hypothesis IDs (P\d+); record the cluster keyword set and member count.
   - **Pass B (self-correction clustering):** find records where mitigation text says "originally diagnosed X, actually Y" or similar; group by correction class.

   For each cluster of size ≥2, score:
   - `signal_strength = cluster_size + cross_corpus_bonus` (cross_corpus_bonus = +2 if cluster spans ≥2 of {sev, post, alert}, else 0)
   - `novelty = 0 if any keyword matches an existing P-row in known_patterns.md, else 1`
   - `actionability = 1 if cluster has a clear fix mechanism in mitigation text, else 0`

   Rank clusters by `(novelty * 2 + actionability + signal_strength)`. Take top 5 → MEGA_CANDIDATES.

## Deliverable 1 — Engineering Diffs (≤2 per run, NEVER auto-land)

5. **Diff candidates.** From MEGA_CANDIDATES, select up to 2 that meet ALL gates:
   - `novelty == 1` (new pattern, not already in P-rows)
   - `actionability == 1` (clear fix mechanism in source)
   - `cluster_size >= 3`
   - Source archives all in last 7d
   - Validator pass (step 8 below) passed

   For each diff:
   - Determine target file:
     - New pattern → `known_patterns.md` (append next P-row at end of Quick-Match Table)
     - New triage rule → `references/triage-discipline.md` (append next R-rule)
     - Cron prompt fix → `team_bot/cron-jobs/<cron>.md` (targeted edit)
   - Apply edit locally in `~/notes/`.
   - `cd ~/notes && sl add <path>` + `sl commit -m "[OT bot] <one-line> from <archive ids>"`.
   - Skip `jf submit` for now (notes is not a Phab-tracked repo; commits are surfaced via the new `ot-notes-commit-push` cron to fb:notes). If the file lives in fbcode (it doesn't — bot only writes to notes-side per the canonical split), `jf submit --draft --publish-when-ready` would apply there.
   - Record commit hash; surface in GChat output.

   **Diff cap:** stop at 2 even if more candidates qualify. The rest roll to next run.

## Deliverable 2 — Mega Learnings (≤5 per run)

6. **Mega-learnings file.** `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/digests/<YYYY>-W<ISO_WEEK>.md` (one file per ISO week; create if missing with header).

   For each of the top 5 MEGA_CANDIDATES (regardless of whether also became a diff), append a 5-line entry:
   ```
   ## <YYYY-MM-DD HH:MM PT> — <short title>

   - **Pattern:** <what crossed multiple incidents> (N=<count>)
   - **Surface:** <comma-separated SEV/post/alert IDs>
   - **Root mechanism:** <actual underlying cause, not the symptom>
   - **Detection gap:** <why the bot/team didn't catch earlier>
   - **Generalization:** <broader principle>
   ```

   If a candidate became a diff in step 5, append also: `- **Diff:** <commit-hash | D-num if available>`.

   No external surfaces touched. Just the append.

## Deliverable 3 — Systemic Gap Report (monthly)

7. **Monthly trigger.** If `state.last_systemic_gap_month != current month (YYYY-MM)` AND today's date >= 25 (give the month enough resolved corpus), generate report:
   - File: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/systemic-gaps/<YYYY-MM>.md`
   - Read ALL archive files from the current month (not just last 7d) across all 3 corpora.
   - Compute aggregations:
     - Top 5 recurring root-cause keyword clusters (sev count)
     - Bot self-correction count by class
     - Total false_alarm count, by alert family
     - Top 3 model_ids appearing across multiple SEVs/posts (recurrence pressure)
     - Top 3 stages (T1/T2/T3/T4) by SEV count
   - Sections in the report:
     ```
     # Systemic Gap Report — <Month YYYY>

     **Generated:** <ts>  **Corpus:** N SEVs + M posts + K alerts across <month>

     ## 1. Recurring Root Causes
     - <cluster> (N=, sample SEVs: ...) → systemic-fix hypothesis: <text>
       ...

     ## 2. Detection Gaps
     <where the bot's monitors missed real signals or fired late>

     ## 3. Triage Gaps
     <where the bot's reasoning was wrong N times for the same reason>

     ## 4. Tooling / Infra Asks
     <what the team should ask other orgs to fix; one bullet per ask, with sample SEV evidence>

     ## 5. Asks to Operator
     <decisions only the operator can make>
     ```
   - Update `state.last_systemic_gap_month = current_month`.

## Validator pass (gates D1 diff land + flags D2 entries)

8. **Validator.** Spawn independent agent (Agent tool) with prompt:
   > "Validate this OT knowledge-curation run. I will give you N MEGA_CANDIDATE summaries (cluster keywords, member archive paths, claimed root mechanism, proposed action). For each: (a) independently re-read the cited archive files, (b) check whether the cluster claim is supported by the source text, (c) for any proposed diff: re-read existing P-rows / R-rules and confirm the proposal is NOT a duplicate. Report per-candidate: confirmed | discrepancy + which evidence is missing. Under 500 words. Do NOT see my reasoning, only the cited archive paths and the proposal text."

   **If subagent / Agent tool is unavailable** (cron context limitation — see L6 in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md`): DO NOT spawn. Treat as `validator unavailable` per the gating rule below (D2 still appends with `⚠️ [validator unavailable]` prefix; D1 blocked). Do NOT inline-recheck — inline recheck is self-consistency, not validation, and the 2026-W20 mega-learning run proved this produces false confidence (operator feedback 2026-05-16 thread `fc2seBuCux8`).

   Gating:
   - Any D1 diff with `discrepancy` from validator: HOLD the diff (do not commit). Surface in GChat with the validator note.
   - Any D2 mega-learning with `discrepancy`: append the entry with prefix `⚠️ [validator: <discrepancy>]`.
   - If validator fails entirely (timeout, error): proceed with D2 only (mark all entries `⚠️ [validator unavailable]`), skip D1.

## GChat output

9. **POST ONLY IF ACTIONABLE (2026-05-30, operator: "what's the point of sending me this msg?").** Send a GChat message to spaces/AAQAVOjYc80 **only when the run produced something the operator must see or act on** — i.e. `diffs_drafted > 0` OR `systemic_gap_generated == true` OR a D1 diff was HELD on a validator discrepancy. A mega-learnings-only run (0 diffs, 0 gaps) is **silent**: still append the mega-learnings to the ledger/archive per steps 5–7, just respond `HEARTBEAT_OK` and post nothing. Mega-learnings are reference material, not an interrupt — the operator reads them from the ledger or the daily-learning-digest, not from a per-run ping.

   When a post IS warranted, **one consolidated message** to spaces/AAQAVOjYc80 (the bot's home space), leading with the actionable item:
   ```
   📚 ot-knowledge-curation: <N> diff(s) drafted<, K systemic gap(s) surfaced if any>
   ```
   Then ONE threaded reply with the mega-learnings block (titles only, with archive paths) for context. NO inline diffs, NO inline full text — just titles and file links. Operator clicks through to read.

   **IDENTIFIER RENDERING — MANDATORY (2026-05-29 thread `HJG9Ec2LuX4`: operator flagged bare `A2449443538836650` as an "invalid link"):** when the mega-learnings block cites evidence, the source items are archive FILENAME stems like `high-2026-05-28-A2449443538836650.md`. Do NOT paste the bare `A<numeric>` token into GChat — bare alert IDs do NOT auto-linkify (unlike `S###`/`D###`/`T###`), so they render as broken-looking plain text. Two correct renderings:
   - **Preferred (clickable):** resolve each alert id to its real URL via `meta monitoring.alert metadata --alert-id="<full_alert_key>" -o json | jq -r .url` and emit `<url|A<id>>`. (The full alert key — `<numeric>@#$<entity>@#$<key>@#$<name>` — is stored in the archive file frontmatter; if only the numeric stem is available and the full key can't be reconstructed, fall back to the next option.)
   - **Fallback (explicit non-link):** render as a code-span archive reference `` `resolved-alerts/2026-05/high-2026-05-28-A<id>.md` `` so it`s visibly a FILE PATH, not a clickable link. NEVER emit a bare `A<id>` that looks like it should be clickable but isn`t.
   - Same rule applies to the mega-learnings markdown FILE written in step 6 — use code-span file refs or resolved URLs, never bare `A<id>`.
   - `S###` / `D###` / `T###` / `W###` auto-linkify in GChat — those can stay bare. Only `A###` (alerts), `m###`/model-ids, and `f###` (FBLearner) need explicit wrapping.

   If no NEW archives, OR a mega-learnings-only run (0 diffs, 0 systemic gaps, no held diff), NO GChat message. Just respond `HEARTBEAT_OK`.

10. **Persist state.** Append processed archive paths to `distilled_archive_paths`, append diff commit hashes, bump mega_learnings_count, set last_run_epoch, write state file. Respond HEARTBEAT_OK with summary `{archives_processed: N, diffs_drafted: D, mega_learnings: M, systemic_gap_generated: bool, validator_status: confirmed|partial|unavailable}`.

## Safety

- **READ-ONLY on external surfaces.** No Workplace comments, no SEV comments, no alert mutations, no Phab acceptance. Notes-side writes only.
- **Diff cap absolute:** 2 diffs per run. Mega-learning cap absolute: 5 per run. Systemic gap: 1 per month max.
- **Never auto-land** — diffs commit to working copy only; the new `ot-notes-commit-push` cron will surface them upstream on its next hourly run.
- **Idempotent on no-drift:** if 0 NEW archives, return HEARTBEAT_OK without writing anything.
- **Validator is a gate, not optional** — if it can't run, D1 is suppressed.
- **Cross-cron coordination:** runs at 23:00 PT, after siblings at 21:00/21:15/21:30 PT. If sibling crons hung/missed and produced 0 new archives, this cron correctly no-ops.
- **No PII / no individual-scoped data** in any output (per team_bot CLAUDE.md § "No individual-scoped data"). Mega-learnings and systemic gaps must be team-shareable.
- **State path discipline:** state file under `mrs-ot-agent-src/state/`, never elsewhere.

## Why this exists

Operator clarified 2026-05-15 23:26 PT: "Need you to create a nightly knowledge-curation cron job ... shall provide three values: (1) better engineering diffs for immediate issues and small gaps, (2) create mega learning from the issues, (3) identify key gaps and systematic fix."

The existing `ot-knowledge-distillation` cron drafts diffs from real-time triage records. This cron operates on the *postmortem* corpus produced by the mitigated-* crons. Together they cover both the "as-it-happens" and "after-the-fact" learning surfaces.

## Learned Rules (auto-appended)

(none yet — cron is new 2026-05-15)
