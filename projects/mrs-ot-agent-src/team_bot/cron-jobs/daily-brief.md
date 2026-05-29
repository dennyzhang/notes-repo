Produce a weekday morning brief for the **MRS-org** OT (Oncall Triage) workstream. **MyClaw lane is destined to be team-shared (Phase 2 multi-user).** Output must contain ONLY team-visible, MRS-org OT signal. Two failure modes are real bugs:

**Hard rule 1 — MRS org only.** Never surface sibling-org SEVs/alerts/posts (Ads, WhatsApp, Wearables, Oculus, AR Effects, FacOps, FAIR, Datacenter, MSL). Drop them BEFORE any output renders — not as "out-of-scope" notes. Silence is correct for out-of-org signal. Reference: 2026-04-30 S657101 (Ads ads_mtml SEV) leaked via closure note.

**Hard rule 2 — no individual-scoped data.** Never surface: calendar / meetings, DMs from operator's inbox, personal reminders/todos, anything visible only because this MyClaw runs as operator's identity. No exceptions, no "OT-relevant calendar" carve-out — calendar is per-person.

**Hard rule 3 — brevity is a feature, not a constraint.** Target: ≤20 lines total. Every line must tell the reader what to **do** or what to **investigate**. Status-quo lines ("open >7d, no recent change, no current problem") are bot-as-database, not bot-as-colleague — drop them. Operator's 2026-05-18 feedback (thread `BzwgIQr_f48`): _"Not helpful. Too much info."_ A name-dump like `L4 (9): S664344, S664099, ...` is the canonical anti-pattern — it adds bytes but no signal.

Each section is its own paragraph with a blank line between. Omit empty sections. If entire brief is empty, reply with exactly: All clear on the OT front this morning.

**Rendering rules:**
- **Never append `https://www.internalfb.com/sevmanager/view/<num>` after a SEV id.** GChat auto-linkifies bare `S<num>` tokens, so the trailing URL is pure noise. Same for `D<num>` (diff), `T<num>` (task). Only emit a literal URL when there is no shorthand id (e.g. a Workplace post, a doc).
- For SEV lines: `S<num> — L<level> <status> | <title> | owner: <unixname> | <one-liner of why it matters>`. No view URL.

1) **OT GChat** — @mentions and replies in bound OT space (spaces/AAQAVOjYc80) and team-visible activity in MRS Online Training Users Workplace group. Skip operator DMs and unrelated spaces. **Only include items the operator has not already engaged** (unread @mention, unanswered question, etc.). If everything was already replied to, omit the section.

2) **OT Diffs** — ❌ DROP THIS SECTION ENTIRELY. The operator's own diffs are visible in Phabricator's reviewer queue and inbox; surfacing them in a brief is noise. Teammate diffs only show up here if the operator is the reviewer, which is again better surfaced in Phabricator native. **Do not emit a diffs section.** (Rule established 2026-05-18 thread `BzwgIQr_f48` after operator: _"Not helpful. Too much info."_)

3) **OT Workplace** — Posts in `mrs.ot` group (id 1084744250286987) the cron didn't auto-handle. Skip sibling-team groups (Ads, WhatsApp, Wearables, etc.) and prior shift-summary posts (title regex `^Oncall Summary`).

   **Frontmatter `wp_post_ids`**: capture ALL post IDs from the 24h window (after filtering shift-summaries). This is the full inventory consumed by `ot-shift-summary`. Do NOT filter by SEV linkage here — the shift summary needs every post.

   **Brief narrative (section 3 body)**: surface only posts with high-confidence relevance to an active SEV or open question — not speculative links. Confirmed-link format: `• <author> (<date>): "<title excerpt>" → confirmed-related to <S…> (<basis>)`. If no posts meet this bar, omit the narrative but STILL populate `wp_post_ids` in frontmatter. (Lesson: 2026-05-28 shift showed 0 WP reports because daily-brief's strict filter stripped Hao Sha + Sanket Karnik's May 27 posts — both valid user reports missing from the shift summary.)

4) **Active OT incidents** — In-progress SEVs with `mvai-online-training` tag OR active alerts on `mrs_online_training` oncall feed. Apply MRS-org filter — drop sev_type ∈ {Ads, WhatsApp, Wearables, Oculus} and any title-hard-exclude hit (`[Ads]`, `Ads ML`, `DPA`, `WA4A`, `AF OC`, `ads_mtml`, `adfinder`, `adindexer`).

   **Surface only the SEVs the operator needs to take action on today.** Split into three buckets, in priority order; omit any bucket that is empty:

   - **🔴 NEW TODAY** (opened or status-changed in last 24h): full SEV line per the rendering rules. These are the operator's primary attention targets.
   - **⚠️ NEEDS NUDGE** (L3 In-Progress for ≥7 days OR L4 In-Progress for ≥14 days, with no `time_updated` change in last 72h): full SEV line per rendering rules. These are escalation candidates.
   - **📊 In-progress counts** (only when buckets above are non-empty): one-line summary, e.g. `_11×L3, 9×L4 in progress — full list: `meta sevmanager.sev list --tags=mvai-online-training --in-progress`_`. Do NOT list SEV numbers without context. Operator can fetch the full list themselves.

   **Always lead the section with the canonical lookup command** so the team can scan beyond what we surface inline. Render verbatim (no fabricated UI URL — sevmanager has no public list URL with tag+status filter; the prior `https://www.internalfb.com/sevmanager/list?tag=...&status=...` returned 404, operator-caught 2026-05-08):

       `📂 All open OT SEVs: meta sevmanager.sev list --tags=mvai-online-training --in-progress`

     If a stable URL is later confirmed (verified fburl, or sevmanager dashboard query string that loads a real filtered view), replace this command with that URL. Until then, the CLI command is the verified surface — do NOT invent a /sevmanager/list?tag=... URL again.

5) **OT followups** — Actionable team-coordination items only. **Only include items that are blocked on someone and are >7 days stale.** Examples: a SEV awaiting `mvai-online-training` tag for >7d, a runbook update that's overdue, a cross-team handoff that hasn't been acknowledged. NOT operator's personal todo list. NOT a re-listing of SEVs already in section 4. If nothing meets the bar, omit the section.

6) **Persist to state file (consumed by `ot-shift-summary` cron).** AFTER posting the brief to the bound space, write the same rendered content (sections 1-5, no truncation) to:

   `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/daily-brief-state/daily-brief-<YYYY-MM-DD>.md`

   File format — YAML frontmatter + markdown body:

   ```
   ---
   date: <YYYY-MM-DD>
   generated_at: <ISO8601 PT>
   entries: <int>                   # total signal count across sections 1-5; 0 = quiet day
   sev_ids: [S<num>, S<num>, ...]   # extracted from sections 1, 3, 4
   diff_ids: [D<num>, D<num>, ...]  # from section 2
   wp_post_ids: [<num>, <num>, ...] # ALL mrs.ot posts in the 24h window (not just SEV-linked ones) — shift-summary needs the full list; section 3 narrative may still filter for brevity
   ---
   <verbatim brief content>
   ```

   `entries` is the canonical "did this cron produce signal today?" field — `ot-shift-summary` uses `entries: 0` to distinguish a quiet day from a missed cron run. ALWAYS populate it (sum of unique SEVs + diffs + WP posts + alert mentions + followup items, deduped); never omit even on quiet days.

   `mkdir -p` the state dir if missing. Filename is date-stamped — re-runs same day OVERWRITE (one canonical brief per day). If sections 1-5 are all empty (i.e., you would have posted "All clear on the OT front this morning"), still write the file with `entries: 0` in frontmatter so `ot-shift-summary` can distinguish "quiet day" from "cron didn't run."

**Self-check before sending — four-question gate.** For every line:
1. Is this OT-incident or OT-coordination content? (scope)
2. Does it belong to the MRS org? (org boundary — Ads/WhatsApp/Wearables/etc. all FAIL)
3. Is this visible to every member of this space already? (privacy — calendar, DMs, personal followups all FAIL)
4. **Does this line tell the reader what to do or investigate today?** (signal — status-quo lines, bare SEV-number dumps, and speculative links all FAIL)
Drop any line failing ANY question. Honest empty brief beats noise; cross-org bleed and privacy bleed both beat nothing — never trade one for the other.

**Total length budget: ≤20 lines** (excluding the section-leading `📂 All open OT SEVs:` command line and YAML frontmatter in the state file). If the natural brief exceeds 20 lines, tighten the line wording before considering dropping items.
