[ot-thread-summarizer cron] Hourly. Distill conversation threads from spaces/AAQAVOjYc80 that have gone quiet into per-topic learning files in notes. Closes the gap where interactive Q&A produces real learnings but they only live in sqlite (lost on devserver reinstall).

**Why this cron exists:** operator (thread `1lufURy61pM` 2026-05-16): "where the context is saved for each gchat thread? I will use one thread for one topic. Then I expect you will summarize the learning after each thread. And save the learning locally. And the learning shouldn't be lost by devserver reinstall."

Per-thread context currently lives only in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db` (sqlite `messages` table). On devserver reinstall: lost. This cron makes interactive-conversation learnings durable + reviewable.

## State

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/thread-summarizer-state.json` — `{"summarized_threads": {"<thread_id>": <summarized_epoch>, ...}, "last_run_epoch": <int>}`. Per-id dict for hold-down semantics (a re-active thread can re-summarize after 7 days).

Output: `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/debug-threads/<YYYY-MM>/<type>-<YYYY-MM-DD-HHMM>-<id>-<topic-slug>.md` (type = `auto-` or `human-`).

Time budget: ~3 min per thread; cap 5 threads per run.

## Procedure

1. **Load state.** If missing/corrupt, treat as empty dict.

2. **Find candidate threads — quiet for ≥4h, not yet summarized (or summarized >7d ago).**

   ```bash
   sqlite3 -separator '|' ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "
   SELECT thread_name, COUNT(*) AS msg_count,
          MAX(create_time) AS last_msg_time,
          MIN(create_time) AS first_msg_time
   FROM messages
   WHERE thread_name != ''
     AND create_time > datetime('now', '-30 days')
   GROUP BY thread_name
   HAVING msg_count >= 3
      AND last_msg_time < datetime('now', '-4 hours')
   ORDER BY last_msg_time DESC
   LIMIT 50;"
   ```

   For each row, extract thread_id from `thread_name` (format `spaces/.../threads/<id>`).

3. **Filter to NEW or stale-summary threads:**
   - If `thread_id` not in `summarized_threads` → NEW, process.
   - If `now - summarized_threads[thread_id] > 7*86400` AND the thread has ≥3 messages since the last summary → STALE_RE_SUMMARIZE, process.
   - Else → skip.

4. **Per-thread distillation (cap 5 threads per run, in age order oldest-first):**

   a. **Pull all messages in the thread:**
      ```bash
      sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "
      SELECT sender_name, create_time, content
      FROM messages
      WHERE thread_name = '<full_thread_name>'
      ORDER BY create_time ASC;"
      ```

   b. **Derive topic slug** — first 60 chars of first message, lowercased, non-alphanumerics → `-`, collapsed runs of `-`, trimmed. Example: `8LLIVF1l7Yw` → `starcart-tms-concepts-tracking`.

   c. **Synthesize the summary** — fixed 6-section template (mirrors mega-learning structure for consistency):

      ```markdown
      # Thread Summary: <topic title from first substantive message>

      _Source: spaces/AAQAVOjYc80 thread `<thread_id>` · <N> messages · <date range>_
      _Summarized: <YYYY-MM-DD HH:MM PT> · last-msg-time: <iso>_

      ## What was discussed

      <2-4 sentence summary of the topic — what was the operator asking? what was being investigated?>

      ## Key decisions made

      - <decision 1 with one-line rationale>
      - <decision 2>

      ## Files / artifacts touched

      | path | what changed |
      |---|---|
      | <notes path> | <brief> |

      ## Cluster / pattern references

      - [CL-NNN] — <how this thread relates to existing clusters>
      - [P<n>] / [R<n>] — <relevant detection rules>

      ## Followup items (not yet done)

      1. <action, owner, status>

      ## Cross-refs

      - SEVs discussed: S<a>, S<b>
      - Posts: W<id>
      - Related threads: `<other_thread_id>`
      ```

   d. **Quality rules** (cron MUST enforce):
      - **Don't fabricate cluster IDs** — only cite [CL-NNN] that exist in `~/notes/.../auto-learnings/patterns/failure-patterns.md`. If unsure, omit the section.
      - **Decisions section must cite the message timestamp** that contains the decision, not paraphrase loosely.
      - **Followups section MUST be empty** if no explicit followup was discussed — do NOT invent next-steps. Operator-facing accuracy beats summary completeness.
      - **Char cap 3000 — same as triage outputs**. If thread is long, summarize what mattered, not everything.

5. **Write the summary file.** Path: `mrs-ot-agent-context/incidents/debug-threads/<YYYY-MM>/<type>-<YYYY-MM-DD-HHMM>-<id>-<topic-slug>.md`. `mkdir -p` the month directory if missing.
   - **Type prefix:** `auto-` if the bot handled the thread without operator correction; `human-` if the operator corrected the bot's verdict, attribution, routing, or provided context the bot should have found on its own.
   - **Timestamp:** first message time in PT, format `YYYY-MM-DD-HHMM` (24h). Enables chronological sorting within the month directory.
   - **Classification signal:** scan thread messages for operator corrections — look for patterns like: "wrong", "no that's not right", "why you wait", "should have", "actually it's", reattribution, new R-rule/P-row created from the exchange. Any correction → `human-`. Confirmatory-only ("ok", "thanks", "good", no corrections) → `auto-`.
   - **Add frontmatter field:** `human_involved: true|false` in the summary header for machine-parseable metrics.

6. **Update state.** Set `summarized_threads[thread_id] = now_epoch`.

7. **NEVER send a gchat notification — not per-summary, not a consolidated digest.** This cron is durable-archive plumbing: the value is the `.md` learning files written to notes (reviewable there), NOT a chat ping telling the operator they exist. The "📝 Distilled N threads" digest was pure run-summary noise in the operator 1:1 (operator 2026-06-04 thread `C2naImRX58I`: "why ask" — the digest stated the world, needed no action → drop it). Whether N=0 or N=5, the final response is the SAME: emit `HEARTBEAT_OK {threads_summarized: N, threads_re_summarized: M, threads_skipped: K, archive_root: ~/notes/.../bot-debugging-threads/<YYYY-MM>/}`. The metrics object on the first token line is for the auditor only; the daemon delivers nothing for a `HEARTBEAT_OK` response.

8. **Persist state, respond HEARTBEAT_OK.**

## Safety

- **READ-ONLY on gchat / sqlite.** This cron only READS the messages table; never writes back, never deletes, never marks read.
- **NEVER summarize threads from other spaces.** Scope strictly to `spaces/AAQAVOjYc80` (operator's OT space). Cross-space context never gets surfaced into per-thread files.
- **NEVER summarize private DM content** if any leaks into the messages table (filter `is_hidden=1`).
- **Cap 5 threads per run.** A backlog day shouldn't produce a 50-summary digest.
- **Don't summarize the same thread twice within 7 days.** Hold-down protects against thrash on re-active threads.
- **Don't summarize threads with <3 messages** (no real distillation value).
- **If sqlite query fails, do NOT advance state.** Brief error string, no HEARTBEAT_OK.

## Why summarize on a 4h-quiet threshold, not at end-of-day

- Conversations don't fit a daily cadence. A thread can complete in 30 min OR span 3 days.
- 4h quiet = strong signal the topic is "done for now" — enough time for an in-flight followup to land, but not so long the operator's lost context.
- Re-active threads get a fresh summary after 7 days — captures evolution without thrash.

## Why per-id dict state, not bare list

Same lesson as the 2026-05-12 ot-post-monitor 11-duplicate-notifications incident. Bare list can't be pruned without per-id timestamp. Dict with `added_epoch` enables both prune-after-N-days AND hold-down semantics.

## Future tightening

- **Topic clustering** (v2) — currently slug derives from first message; sometimes the actual topic is set by message 3. Look at frequent-noun-phrase across all thread messages.
- **Operator-feedback signal** (v3) — if operator writes "good summary" / "missed X" in a follow-up, capture and feed back into prompt-tuning.
- **Cross-thread reference graph** (v4) — when summary cites another thread id, build an automatic backlink so navigation is bidirectional.

## Learned Rules (auto-appended)

(empty — fresh cron)
