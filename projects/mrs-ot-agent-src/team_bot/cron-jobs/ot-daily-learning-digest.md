[ot-daily-learning-digest cron] Daily 7:50 AM PT. ONE consolidated summary of what the bot LEARNED in the last 24h, delivered to Denny's 1:1 (spaces/AAQAVOjYc80) so he can (a) audit the learning quality and give feedback, (b) learn alongside the bot daily. Purpose: collapse 6+ learning surfaces (memory deltas, notes commits, cron-prompt amendments, mega-learnings, validator catches, draft diffs) into ONE skim-in-60-sec digest. Not a replacement for the per-surface crons — a meta-view over them.
Created 2026-05-28 per Denny request in team-space thread (he asked "what's the point of this brief?" + "I'm thinking to polish this daily msg as a summary for what your ai daily auto-learning").

Files:
- Output channel: gchat post to spaces/AAQAVOjYc80 (1:1 with Denny — NOT team space)
- State (dedup last-run timestamp): /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/ot-daily-learning-digest-state.json
- DB: /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db
- Ledger reference (read-only): /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md

Procedure:

1. **Establish window.** Read `ot-daily-learning-digest-state.json`. Window = `[last_run_iso, now]` capped at 36h to bound runaway recovery. If state file missing, default window = `now - 24h`.

2. **Gather signals** — collect from 6 surfaces in parallel. For each, capture: source pointer (file/D-number/URL), one-line headline, link to source incident (where applicable).

   a. **Memory deltas** — files under `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/memory/*.md` with mtime in window. Classify as `new` (file didn't exist before window start) vs `updated`. Extract `name:` + `description:` from frontmatter for headline. Skip `MEMORY.md` itself.
      ```bash
      find ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/memory -name '*.md' -not -name 'MEMORY.md' -newermt "$WINDOW_START"
      ```

   b. **Notes-repo learning commits** — sl log on `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/` and `~/notes/users/dennyzhang/cheatsheets/` for window. Capture commit hash + first line of message + files changed.
      ```bash
      cd ~/notes/users/dennyzhang && sl log --rev "date('>$WINDOW_START')" --template "{node|short}|{desc|firstline}|{files}\n" -I "projects/mrs-ot-agent-src/**" -I "cheatsheets/**"
      ```

   c. **Cron-prompt amendments** — files in `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/cron-prompt-backups/` created in window (mtime). Filename encodes which cron + timestamp. For each backup pair (notes.md + sqlite.txt), diff against current to summarize the appended rule.
      ```bash
      find ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/cron-prompt-backups -name '*.md' -newermt "$WINDOW_START"
      ```

   d. **ot-knowledge-curation output** — last in-window run from `job_runs`. Extract: mega-learnings appended count, drafted diff D-numbers, validator-status verdict.
      ```bash
      sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "SELECT raw_response FROM job_runs WHERE job_id='ot-knowledge-curation' AND run_at > '$WINDOW_START' ORDER BY run_at DESC LIMIT 1;"  # was job_runs.db (nonexistent → silent empty); fixed 2026-06-07 audit
      ```

   e. **ot-postmortem-validator catches** — last in-window run. Extract count + class of misattributions/fabrications caught.

   f. **ot-daily-learning-* ledger appends** — in-window runs of `ot-daily-learning-{debugging,mitigated-alerts,mitigated-posts,mitigated-sevs}`. Extract: count of NEW learnings appended (operational vs domain), pattern proposals (P-IDs), implementation-deltas drafted, validator-discrepancies harvested.

3. **Dedup against `learnings.md` headlines.** If a signal's headline appears verbatim in ledger entries already cited in a prior digest run (check state file's `cited_headlines` list, capped at last 200), skip it. Prevents the same learning re-appearing across consecutive digests.

4. **Score each signal for "is this worth Denny's attention?"** Drop signals that score 0. Scoring rubric:
   - +2 if it's a HARD-RULE/feedback memory (governs future behavior)
   - +2 if it's a draft diff with D-number (concrete artifact ready for review)
   - +1 if it's a new domain pattern (P-row proposed)
   - +1 if it's a validator catch (auto-correction loop closed)
   - +1 if it's a notes-cheatsheet update (durable knowledge)
   - 0 if it's a routine cron-prompt amendment with no behavioral change (e.g., URL fix)
   - -1 if headline is already in `cited_headlines`

5. **URL discipline.** Every cited reference MUST be a verifiable URL, not bare shorthand. Resolve before writing per ot-daily-learning-debugging step 4a table (S→sevmanager, W→workplace.post describe, A→onedetection, D→phabricator.diff URL, T→tasks URL). Forbidden: bare `W<digits>` token. If resolve fails: `<unresolvable post id N>`.

6. **Render digest.** Single gchat post to spaces/AAQAVOjYc80. Cap total length ≤3000 chars. **Each `<headline>` is the substantive LEARNING itself — what changed + why it matters, in plain words — NOT a topic-label or a filename; the `<file_path>`/URL is the drill-in link, not the content (CLAUDE.md §Cron Output Effectiveness: every line tells the reader what they now KNOW / should DO, never bot-as-database). `why:` is a one-line reason, not a bare URL.** Format:

   ```
   🧠 *Daily learning digest — <YYYY-MM-DD>*  (window: <hours>h, <N> signals)

   ━━━ 📜 New rules / feedback memories (<count>) ━━━
   • <headline> — <file_path>
     why: <source incident URL>

   ━━━ 🔧 Cron-prompt amendments (<count>) ━━━
   • <cron_name>: <one-line change summary>
     diff: <backup_path>

   ━━━ 📚 Notes / cheatsheet updates (<count>) ━━━
   • <commit_short_hash>: <commit message firstline>
     files: <path1>, <path2>

   ━━━ 🩺 Validator catches (<count>) ━━━
   • <class>: <one-line> — <source thread URL>

   ━━━ 🆕 New domain patterns (<count>) ━━━
   • P<N> <pattern name> — proposed by <cron>
     source: <S/A/W URL>

   ━━━ ✉️ Draft diffs queued (<count>) ━━━
   • D<num> — <title> — status: <draft|pending-review>

   ━━━ 📊 24h roll-up ━━━
   • memory files touched: <N> (<X> new, <Y> updated)
   • notes commits: <N>
   • cron prompts amended: <N>
   • validator discrepancies: <N>
   • pattern proposals: <N>
   ```

   Section omitted if its count == 0. If ALL counts == 0, send a one-liner: `🧠 Daily learning digest — <date>: no new learnings in last 24h.`

7. **Update state file** with `last_run_iso`, `cited_headlines` (append today's headlines, trim to last 200), `last_digest_message_url` (returned by gchat send).

8. **Respond EXACTLY `HEARTBEAT_OK {digest_sent: <true|false>, signals: <N>, sections: <M>}`** — the literal token plus the same-line `{metrics}` object for the auditor, and NOTHING else: no preamble, no "now sending the digest", no run-summary, no narration before OR after. The digest is the explicit gchat post in step 6 — that IS the delivered message; step 8 only suppresses the daemon's double-delivery. Any text wrapping `HEARTBEAT_OK` is auto-delivered to chat verbatim (the narration-leak class — ot-prompt-change-validator 2026-06-07).

Safety:
- NEVER post to team space (spaces/AAQA2bZMw24) or any space other than spaces/AAQAVOjYc80. This is a private audit channel for Denny only.
- NEVER include content from team-space private discussions or other operators' 1:1s in this digest — only the bot's own learning artifacts (memory files, cron prompts, ledger, validator output).
- If a signal cites a sibling-org SEV (Ads/WhatsApp/Wearables/Oculus/AR Effects/FacOps/FAIR/Datacenter/MSL) — drop it per ot-daily-learning-debugging step 3 scrub.
- Cap signals per section at 10. Surplus → "+N more, see ledger".
- If sqlite/sl/gchat fails: log error, do NOT silently send empty digest. Surface failure as one-liner: `🧠 Daily learning digest — <date>: FAILED (<error>)`.

Schedule rationale: 7:50 AM PT lands ahead of `daily-brief` (8:14 AM weekdays) so Denny sees learning context before the brief. Weekends INCLUDED (bot learns 7 days/week; digest delivery cadence shouldn't gap on weekends).

## Learned Rules (auto-appended)

<!-- New numbered items inserted here by ot-daily-learning-debugging or this cron's own self-amendments. Format: [YYYY-MM-DD LN] <rule>. Never modify body above this line. -->
