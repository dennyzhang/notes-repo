[ot-human-attention-brief cron] Daily 8:00 AM PT. The ONE thing the operator should read every morning to know:

1. **Where AI needs human help** — bot triages from the last 24h where confidence was low / verdict was UNKNOWN / validator flagged misattribution / pattern unmatched
2. **Key daily learnings** — non-obvious insights from the last 24h (new clusters, new P-rows, surprising reattributions, recurrence escalations, cross-workload patterns)

Goal: replace operator's need to scan every cron post in gchat. One ~500-line brief per day. Skim in 60 sec, drill in 5 min for items that need attention.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-human-attention-brief-state.json` — `{"last_run_epoch": <int>, "last_brief_id": "<sqlite job_runs.id of last brief>", "low_confidence_seen_24h": [<list of bot-run-ids already surfaced>], "learnings_seen_24h": [<list>]}`. Time budget: ~5 min per run.

## Background

Operator (2026-05-17 thread `suPsRC2fGdc` 08:08 PT): "Most of issues are handled by ai. Everyday as human we need to know two things: 1/ issues ai was unconfident, so human can step in. 2/ key daily learnings, so human can review. The output should be very concise and easy to trace down the context."

Existing crons each emit per-event posts (per-alert triage, per-SEV postmortem, per-thread summary, etc.) — operator has to skim ~30 posts/day to find the ~3 that need action. This cron aggregates the operator-attention surface into ONE morning brief.

## Procedure

1. **Read state file.** Extract `low_confidence_seen_24h` + `learnings_seen_24h`. If missing/corrupt, default empty.

2. **Collect low-confidence triages from last 24h** — query sqlite:
   ```bash
   sqlite3 -separator '|' /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db \
     "SELECT id, job_id, run_at, raw_response FROM job_runs \
      WHERE job_id IN ('ot-sev-monitor','ot-alert-monitor','ot-post-monitor') \
      AND run_at > datetime('now','-24 hours') \
      AND status='ok' \
      ORDER BY run_at;"
   ```
   Parse each raw_response for low-confidence signal:
   - `"confidence": "low"` OR `confidence: low` in prose
   - `"verdict": "UNKNOWN"` OR `verdict: UNKNOWN` / `⚪ UNKNOWN`
   - `"root_cause_status": "not_found"` OR `not found` in prose
   - `"validator_status": "discrepancy: ...` OR `⚠ Validator found` markers
   - Operator-flagged misattributions (search for `[misattribution]` / `reattribut` keywords)
   - PAGE verdicts where bot escalated but assignee is unassigned (orphan pages)

3. **Collect key daily learnings from last 24h** — multi-source:

   a. **Cluster registry changes** — diff `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/patterns/failure-patterns.md` against 24h ago:
      ```bash
      sl --cwd=~/notes log -r 'date(-1, now) and modifies("users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/patterns/failure-patterns.md")' -T '{node|short}|{date|isodate}|{desc|firstline}\n'
      ```
      Extract: new CL-NNN added, status changes (🟡→🔴 etc.), cadence escalations.

   b. **Known-patterns.md changes** — same diff for `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-domain/how/known-patterns.md`. Extract: new P-rows landed.

   c. **Mega-learning weekly file changes** — `mrs-ot-agent-context/auto-learnings/digests/2026-W<NN>.md` for this week. Extract: new entries that match the ≥3-instance D1-eligibility threshold.

   d. **ot-knowledge-curation cron output** — last 24h run's `raw_response`. Extract: drafted-diffs count, mega-learnings appended count, validator-status.

   e. **ot-postmortem-validator cron output** — last 24h. Extract: misattributions caught, corrections issued.

   f. **Cron-health transitions** — `ot-cron-health-state.json` for last 24h state-machine transitions (new failures, persistent failures, recoveries).

   g. **Auditor findings** (added 2026-05-19 thread `2w5Schmk83U` per the ot-triage-auditor cron launch) — read last 24h of `ot-triage-audit-log.jsonl`:
      ```bash
      tail -200 ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-triage-audit-log.jsonl | \
        jq -s 'map(select(.audit_epoch > (now - 86400))) | group_by(.tier)'
      ```
      Extract per-tier counts (page / nudge / self-heal / pass) AND top-3 recurring R-rule ids across all findings. Emit ONE section in the brief if any non-zero tier exists; OMIT section entirely if all-zero (no noise).

4. **De-duplicate against state file.** Don't re-surface items already in `low_confidence_seen_24h` or `learnings_seen_24h`. (Operator already saw them — repeating is noise.)

5. **Compose the brief** — strict format (≤3500 chars hard cap):

   **CRITICAL link discipline (operator-flagged 2026-05-17 thread `Y3qbdh2hC20`):** Every URL MUST use markdown link syntax `[short label](url)` — NOT raw inline URLs. The reader skimming on mobile / phone sees a CONCISE one-line bullet with one or two clickable phrases, not a pool of URL text. Bad: `• ⚪ UNKNOWN — model 877766932 — https://chat.google.com/room/AAQAVOjYc80/abc123def456`. Good: `• ⚪ UNKNOWN — [model 877766932](https://chat.google.com/room/AAQAVOjYc80/abc123def456)`.

   gchat renders `[text](url)` as a clickable hyperlink. Concise scan, drill-in on tap. Each item under 120 chars visible width.

   **Link extraction per source type (backtested 2026-05-17 09:20 PT):**
   - **For triage cron run** (`ot-sev-monitor`, `ot-alert-monitor`, `ot-post-monitor`): the cron raw_response now includes per-cluster `Bot reply: <url>` + `Original alerts: <url>` lines (mandatory as of 2026-05-17 thread `Y3qbdh2hC20`). Extract these directly. Wrap them as `[model <id>](<bot_reply_url>)` for the human bullet.
   - **For validator cron** (`ot-postmortem-validator`): the validator output cites the parent thread URL. Wrap as `[validator pass](<thread_url>)`.
   - **For knowledge-curation** (`ot-knowledge-curation`): cite the commit hash. Wrap as `[commit <short_hash>](<commit_url>)`.
   - **For SEV/alert/post mentioned by ID** in any source: render markdown-linked: `[S<id>](<sev_url>)` / `[A<id>](<alert_url>)` / `[post W<id>](<workplace_url>)`.
   - **For cluster / pattern changes**: `[CL-<NNN>](<cluster_anchor_url>)` / `[P<NN>](<known_patterns_url>)`.

   **If multiple IDs in one raw_response (cluster of N alerts):** use the FIRST/PRIMARY alert URL. Cluster context can be a parenthetical.

   **Format (revised 2026-05-17 thread `Y3qbdh2hC20` for link discipline):**

   ```
   ☕ *Morning brief — <YYYY-MM-DD>*  (last 24h)

   ━━━ 🔴 Where AI needs you (N items) ━━━

   [If N=0]: All triages confident. ✓

   [Per low-confidence item, ONE line:]
   • <icon> <one-line summary> — <id> — <CLICKABLE_URL>
     <one-line why bot was uncertain>

   Examples (markdown-linked, concise per operator feedback Y3qbdh2hC20 09:29 PT):
   • ⚪ UNKNOWN — [model 877766932 vdd_hstu](https://chat.google.com/room/AAQAVOjYc80/<thread_id>)
     Low conf: checkpoint_training_data_age_mins not queryable; llu6/charlesz verify Scuba
   • ⚠️ AGG unmatched — [A2126294138 ig_feedrec_esr_ttsn 27h+](https://www.internalfb.com/onedetection/alert?alert_id=2126294138)
     Sub-alerts inaccessible; operator routing needed
   • 🔴 PAGE unassigned 3h — [S665135 Shampoo NaN](https://www.internalfb.com/sevmanager/view/665135)
     CL-017 recurrence on PROD CFR baseline

   ━━━ 📚 Key learnings (N items) ━━━

   [If N=0]: No new patterns / cluster changes / P-rows.

   [Per learning, ONE line:]
   • <emoji> <topic> — <one-line insight> — <CLICKABLE_DERIVATION_URL> · <CLICKABLE_ARTIFACT_URL>

   **Two URLs per learning are required** (operator-flagged 2026-05-17 thread `Y3qbdh2hC20` second message: "I may need to debug how you learned that"):
   1. **DERIVATION URL** — the source the bot used to derive this learning. E.g., the gchat thread URL where the misattribution surfaced, the cron-run gchat post URL where the pattern emerged, the validator thread URL that caught the discrepancy. Operator can drill in to verify the bot's reasoning.
   2. **ARTIFACT URL** — the file/commit/cluster where the learning was codified. E.g., the failure-patterns.md cluster anchor, the known-patterns.md P-row, the commit URL.

   Derivation URL per source type (backtested 2026-05-17):
   - Learning from triage cron raw_response → the **original alert/SEV/post URL** that triggered the triage (NOT the bot's gchat thread, which isn't queryable from raw_response). Operator clicks alert URL → reaches alert page → finds bot's reply on the alert's discussion thread
   - Learning from operator-conversation → the operator's gchat thread URL (extractable from gchat skill output)
   - Learning from validator misattribution → the validator's reply thread URL (validator output contains `thread <id>` references)
   - Learning from sl commit diff → the commit URL: `https://www.internalfb.com/code/notes/commit/<hash>` (commits often quote the source thread in the message)
   - Learning from mega-learning entry → the weekly file URL with the cited evidence anchor
   - Learning from operator-direct gchat thread (e.g., operator says "do X") → the operator's thread (parse the thread_id from the gchat message metadata)

   Examples (markdown-linked; both derivation + artifact in compact form):
   • 🆕 [CL-018](https://www.internalfb.com/code/notes/...#cl-018) registered: AGG-rule blind-spot (3 instances/24h) — origin: [operator thread](https://chat.google.com/room/AAQAVOjYc80/LqKW1jLtNeM)
   • 📈 [CL-017](https://www.internalfb.com/code/notes/...#cl-017) accelerating: 4 NaN events in 18h — origin: [S665135 reattribution](https://chat.google.com/room/AAQAVOjYc80/gMO2L7p9xaM) · [commit](https://www.internalfb.com/code/notes/commit/819fc7701ac2)
   • 🆕 [P56](https://www.internalfb.com/code/notes/...#p56) landed: Shampoo NaN cascade — origin: [operator "act, don't ask"](https://chat.google.com/room/AAQAVOjYc80/gMO2L7p9xaM)
   • ⚠️ Misattribution: S665135 [CL-009→CL-017](https://www.internalfb.com/code/notes/commit/535ad143103f) — origin: [digest thread](https://chat.google.com/room/AAQAVOjYc80/gMO2L7p9xaM)
   • ⚠️ 10/10 recall miss — mvai-OT SEVs missing triage_events 7d — origin: [metrics-rollup thread](https://chat.google.com/room/AAQAVOjYc80/<thread>) · debug: [Scuba](https://www.internalfb.com/scuba/triage_events)

   **Compact form rules:**
   - Maximum 2 markdown links per bullet
   - The PRIMARY link is the topic itself (CL-NNN / P<NN> / S<id>) — reader skimming sees "CL-017" highlighted, clicks for context
   - The SECONDARY (origin) link is optional but recommended for learnings; prefix with "origin:" or use `·` separator
   - Avoid full URL text in bullet; reader should see compact descriptive labels, not URL paths

   If derivation URL not findable from cron raw_response, fall back to: `(derivation: cron-job-run sqlite id <N>)` — BUT only as last resort. Sqlite-only learnings are operator-hostile.

   ━━━ 📊 Bot autonomy stats (last 24h) ━━━

   Triages: <N total> ┃ Confident: <N (%)> ┃ Operator-touched: <N>
   Crons: <N total fires> ┃ Clean: <N (%)> ┃ Failures: <N>

   _Brief id: <sqlite job_runs.id> · State: ~/notes/.../state/ot-human-attention-brief-state.json_
   ```

   **Auditor section format** (insert AFTER 📚 Key learnings, BEFORE 📊 Bot autonomy stats — only emit if any non-zero tier; omit entirely otherwise):

   ```
   ━━━ 🔍 Auditor (last 24h) ━━━

   <N> triages audited
   • 🔴 Pages: <N> — top: <thread_url> <one-line>
   • 🟠 Nudges: <N> — top: <thread_url> <one-line>
   • 🟡 Self-heals: <N>
   • Top recurring R-rules: <top-3 R-rule ids comma-separated>
   • Trend: <delta vs prior day, e.g. "-2 nudges" or "first day">
   ```

   **Rules for auditor section** (operator-locked 2026-05-19 thread `2w5Schmk83U`):
   - Use `brief_summary_line` field from each audit log entry as the one-line text
   - Page entries: link with `🔴` tier emoji; thread URL clickable
   - Nudges: same shape, `🟠` tier emoji
   - Top recurring rules: sorted by frequency desc, capped at 3 (e.g., "R-XR1, R-XR2, R-EV1")
   - Trend: compare to prior day's audit-log entries (count nudges + pages); render as `+N` / `-N` / `same` / `first day`
   - If `🔴 Pages == 0 AND 🟠 Nudges == 0 AND 🟡 Self-heals == 0`: OMIT this section entirely. No noise.

   **NEVER emit sqlite `run <N>` IDs as the sole reference.** They're operator-unfriendly (require sqlite to drill in). The sqlite run_id can appear in parentheses as additional metadata IF a clickable URL also appears: e.g., `https://chat.google.com/... (run 285)`. URL first, ID parenthetical.

6. **Post to gchat** — single message to spaces/AAQAVOjYc80 (not threaded; this is a top-level daily brief). NEVER threaded — each day stands alone.

7. **Update state file** with all surfaced item-ids in `low_confidence_seen_24h` + `learnings_seen_24h` rolling lists. Update `last_run_epoch` + `last_brief_id`.

8. **Regenerate `incidents/open.md`** — auto-generated file, overwritten each run. Uses the same live data already queried in steps 2-4. Write the file at `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/incidents/open.md` with:
   - Header: `# Open Incidents` + `_Auto-generated by ot-human-attention-brief · <timestamp PT>_`
   - `## SEVs` — query `meta sevmanager.sev list --tags=mvai-online-training --in-progress --columns=sev_number,level,title,owner_unixname,status -o json --limit=50`. Sort by level ascending (L1→L4), then by age descending (oldest open first). Include Age column (days since created).
   - `## Alerts` — query `meta monitoring.alert list --oncall=mrs_online_training --state-is=ACTIVE -o json --limit=20`. Sort by urgency.
   - `## Posts` — placeholder unless ot-post-monitor state has open tracked posts.
   - Commit + push to notes repo only if content changed (diff check against prior version).

## Format rules

- **Concise > complete.** Each bullet ONE LINE. Anything that needs multiple lines goes in the source (cron post / commit / cluster entry) — link not inline.
- **Easy to trace.** Every bullet has a link or ID (gchat thread, commit hash, file path with anchor, sqlite run_id). Operator can drill from brief → context in ≤2 clicks.
- **No padding.** No "Have a great day", no "Brief generated by". Operator already knows.
- **Empty sections explicit.** "All triages confident. ✓" / "No new patterns." — silence is ambiguous; "nothing happened" is data.
- **Hard cap 3500 chars.** If overflow: prioritize 🔴 over 📚 over 📊. Spill 📚 to a paste, link from brief.

## Pre-publish lint (MANDATORY, added 2026-05-17 thread `Y3qbdh2hC20` after spec didn't take effect at 09:30 PT)

Before posting, scan the composed message text. If ANY of these conditions hold, FIX before sending:

1. **No raw URLs in bullets.** Any line starting with `•` that contains `https://` MUST also contain `](` (markdown link closing bracket). Regex check on bullet lines: `^• .*https://[^)]*(?!\))` (raw URL not followed by `)`) → FAIL.
2. **Maximum 2 markdown links per bullet.** Count `](` per line; if >2, condense.
3. **No URL text visible in bullet labels.** The text BEFORE `](url)` must be human-readable (e.g. `CL-017`, `model 878858380`, `operator thread`) — NOT a path or URL fragment.
4. **URL well-formedness (added 2026-05-17 thread `suPsRC2fGdc` after 404s shipped):**
   - `https://chat.google.com/room/<space>/<thread_id>` — MUST have BOTH `/<space>/` AND `/<thread_id>`. URL with only `/room/<space>` (no thread_id) routes to space root, NOT the thread → FAIL (operator can't find the relevant conversation). If thread_id unknown, render the bullet WITHOUT a URL rather than emit a space-root URL.
   - Workplace post URL: `https://fb.workplace.com/groups/mrs.ot/permalink/<post_id>/` — NOT `https://www.internalfb.com/work/permalink/...` (that 404s). The internalfb.com `/work/` path does NOT exist.
   - SEV: `https://www.internalfb.com/sevmanager/view/<sev_number_no_S>` — the `S` prefix is for our IDs only; URL uses the number alone.
   - Alert: `https://www.internalfb.com/onedetection/alert?alert_id=<id>` — numeric `<id>` only, NOT the `@#$` URL-encoded form (which may not deep-link).
5. **🔴 items MUST include the bot's gchat thread URL when available** (operator instruction 2026-05-17 thread `suPsRC2fGdc`: "the url should pointing to the gchat thread, instead of gchat space"). The triage cron's `Bot reply: https://chat.google.com/room/AAQAVOjYc80/<thread_id>` line in raw_response (added 2026-05-17 in commit `dcea1e7bc011`) is the source. For historical runs where this line is missing, OMIT the URL rather than emit a space-root URL.
6. **📚 learning bullets MUST state the actual LEARNING, not just the topic** (operator instruction 2026-05-17 thread `suPsRC2fGdc`: "I can see you have learned something for what issues. but I don't what you have really learned"). Format: `<emoji> LEARNED: '<actionable insight, 1-2 sentences>' — origin: [...] · [artifact](...)`. **Anti-pattern: bullet says "Shampoo NaN = distinct failure class; new P-row needed".** That's the TOPIC. **Good: "NaN at training step N taints checkpoint → v_{N+1} restart from tainted state crashes on Shampoo preconditioner. Mitigation: revert to N-2 snapshot."** That's the LEARNING.

If the lint fails: re-compose the offending bullet using markdown link syntax `[short-label](url)` with valid URL forms, AND restate learnings as actionable insights. Do NOT publish if lint fails — operator explicitly flagged 2026-05-17 09:29 PT ("pool of words") + 09:53 PT ("404s + topic-not-learning").

**Anti-regression evidence:** 09:29 + 09:30 PT briefs emitted raw URLs. 09:36 + 09:39 PT briefs had markdown syntax but 404-causing URLs (space-root, wrong domain) AND topic-header learnings. Spec without lint = unenforced. Spec without coverage = unenforced even with lint. Both gaps closed in this revision.

## Anti-spam

- Single post per day. Suppress repeats if rerun within 12h.
- De-dup against state file — items already surfaced yesterday don't re-appear today unless materially changed (new evidence, status flip).
- If both 🔴 and 📚 sections are empty AND no cron failures → still post the brief (signals "yesterday was clean," gives operator confidence the cron is alive). But shorten to 1-line: "☕ Morning brief — <date> · Clean day. ✓ <N> triages, <N>% confident. 0 failures."

## Self-escalation

- If 🔴 section >5 items: prefix brief with `⚠️ ATTENTION — N items need human` so it stands out in gchat.
- If brief itself fails 2+ days: ot-cron-health-watch escalates per persistent-failure rule.

## Distinct from sibling crons

- **daily-brief** (existing, weekday 8:14 PT): personal-calendar focused (meetings, diffs, oncall). NOT OT-bot-output focused.
- **ot-shift-summary** (existing, Tuesdays 8:30 PT): weekly handover for outgoing oncall to post in mrs.ot Workplace group.
- **ot-knowledge-curation** (existing, nightly 23:00 PT): cross-incident pattern detection + Phabricator diff drafting; consumer-of-corpus, not consumer-of-attention-surface.
- **ot-postmortem-validator** (existing, daily 22:30 PT): validates that day's mitigated-* digests for misattributions; outputs go to specific threads.
- **ot-human-attention-brief** (THIS): aggregates LOW-CONFIDENCE triages + KEY LEARNINGS into ONE morning post. Operator's first read of the day.

## Created

2026-05-17 in response to operator instruction (thread `suPsRC2fGdc` 08:08 PT): "Everyday as human we need to know two things: 1/ issues ai was unconfident, so human can step in. 2/ key daily learnings, so human can review. The output should be very concise and easy to trace down the context."

Schedule rationale: 8:00 AM PT is BEFORE the existing daily-brief (8:14 PT). Operator reads ot-human-attention-brief first (action items), then daily-brief (calendar context).
