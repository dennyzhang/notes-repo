**DELIVERY = OPERATOR 1:1 (`spaces/AAQAVOjYc80`) — re-routed 2026-06-03 to comply with the HARD Team-Chat Send Gate.** This brief is operator-facing (personalized "needs you" items, the operator's own unengaged @mentions, their learnings ledger, their daily-brief-state) → it belongs in the 1:1, NOT the team space. (Was team-space 2026-05-30→2026-06-03; reversed because the Send Gate routes operator-facing output to 1:1, and that HARD gate postdates + overrides the 2026-05-30 team-space decision. If a *de-personalized* team OT digest is wanted, that is a separate rewrite — not this brief.) Render the brief, then send it with an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing daily-brief thread, or append `# new-topic`> --text="<rendered brief>"`, then respond EXACTLY `HEARTBEAT_OK` so the daemon's default team-space auto-delivery posts nothing (no double-post). **VERIFY-BY-READBACK (mandatory):** after the explicit send, the run is only "delivered" if the message is actually readable in `spaces/AAQAVOjYc80` — do not trust the send's success string alone (false-delivered class). If the explicit send errors, surface the error; do NOT silently fall back. If the brief is empty, respond `HEARTBEAT_OK` and send nothing.

**WHOLE-MESSAGE SIZE BUDGET (HARD, mechanical — 2026-06-09 "same budget rule as the team pulse; the budget applies to the WHOLE msg, not a section").** The budget is on the ENTIRE assembled brief, not per-section: **≤1200 chars AND ≤16 lines.** Enforce it MECHANICALLY before sending — a prose "≤N lines" note gets skipped (the lesson from the fleet pulse whose char-cap never fired). After assembling the brief, run the deterministic gate:
```bash
printf '%s' "$BRIEF" | bash ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/msg-budget-gate.sh --max-chars 1200 --max-lines 16
```
If it exits 3 (over budget), TRIM by the shrink-order — **Followups → GChat/Workplace → 🔵 TRACKED to count-only → ✅ adopted-learnings** (drop lowest-value first) — and re-run the gate until it passes (exit 0). NEVER trim 🆘 NEEDS-YOU or ⚠️ NEEDS-CONFIRMATION items. Only a brief that PASSES the gate may be sent. (This supersedes the scattered per-section line caps below — one whole-message budget, work backwards to fit the most effective content.)

Produce a **daily** (every morning, 08:00 PT) brief for the **MRS-org** OT (Oncall Triage) workstream. **MyClaw lane is destined to be team-shared (Phase 2 multi-user).** Output must contain ONLY team-visible, MRS-org OT signal. Two failure modes are real bugs:

**Hard rule 1 — MRS org only.** Never surface sibling-org SEVs/alerts/posts (Ads, WhatsApp, Wearables, Oculus, AR Effects, FacOps, FAIR, Datacenter, MSL). Drop them BEFORE any output renders — not as "out-of-scope" notes. Silence is correct for out-of-org signal. Reference: 2026-04-30 S657101 (Ads ads_mtml SEV) leaked via closure note.

**Hard rule 2 — no individual-scoped data.** Never surface: calendar / meetings, DMs from operator's inbox, personal reminders/todos, anything visible only because this MyClaw runs as operator's identity. No exceptions, no "OT-relevant calendar" carve-out — calendar is per-person.

**Hard rule 3 — brevity is a feature, not a constraint.** Target: ≤20 lines total. Every line must tell the reader what to **do** or what to **investigate**. Status-quo lines ("open >7d, no recent change, no current problem") are bot-as-database, not bot-as-colleague — drop them. Operator's 2026-05-18 feedback (thread `BzwgIQr_f48`): _"Not helpful. Too much info."_ A name-dump like `L4 (9): S664344, S664099, ...` is the canonical anti-pattern — it adds bytes but no signal.

Each section is its own paragraph with a blank line between. Omit empty sections. If entire brief is empty, reply with exactly: All clear on the OT front this morning.

## Brief assembly — order, BLUF header, dedup, caps (2026-05-30, 3-round effectiveness pass)

Render in THIS order (most-urgent first; the section numbers below define CONTENT, this defines OUTPUT order):

**ORGANIZE BY AI CAPABILITY, NOT ISSUE TYPE (2026-05-30 — operator caught the contradiction: "open new&urgent items but ai-needs-help=none is wrong").** The bot's goal is to handle every issue, so EVERY open/unresolved issue (new SEV, firing alert, urgent ping, in-progress SEV) MUST be classified into exactly ONE of two states — never "urgent + open" with no AI-status:
- **🆘 NEEDS YOU** — needs a human action/decision the bot cannot take (low-confidence triage, blocked on a human owner/decision, a fix that requires a person, or an unanswered urgent ping). This is the human worklist.
- **🔵 TRACKED** — the bot has triaged it and no new human action is needed right now: either the bot is auto-mitigating it, OR (the common OT case) it's progressing under its human owner and the bot is just tracking. FYI only. (Renamed from "AI HANDLING" 2026-05-30 — be honest: the bot mostly *triages/observes*; it rarely auto-resolves SEVs, which are human-owned. Don't overstate agency. For each 🔵 line say which it is: `auto-mitigating` vs `owner <group> progressing`.)
There is NO third "urgent but unclassified" bucket. If an item is open and you can't say which of the two it's in, it's 🆘 by default (unhandled = needs you).

Render in THIS order (most-urgent first):

0. **BLUF header (line 1, always):** `⚡ <N> need you · <M> AI-handling · <K> resolved (24h)`. N = items in 🆘. If N==0: `✅ Nothing needs you — <M> AI-handling autonomously, <K> resolved (24h)`. ≤12-word gist of the single most urgent 🆘 item appended. Bottom line readable from line 1 alone.
1. **🆘 NEEDS YOU — bot can't resolve alone** — the merged human worklist (new SEVs/alerts/pings the bot is blocked on + in-progress SEVs needing a human decision + low-confidence/UNKNOWN triages). Each line: `<id> (L#) — <symptom> | <product group> | **bot blocked on: <what needs a human>** | [triage thread](<bot_reply_url>)`. The triage-thread URL is MANDATORY (human acts AND leaves the bot triage feedback). Sort most-urgent first.
2. **🔵 TRACKED (FYI, no action)** — triaged, no new human action: `<id> (L#) — <symptom> | <product group> | <auto-mitigating | owner-progressing>`. Collapse to a COUNT line when >3 (e.g. `🔵 6 tracked — 4 owner-progressing, 2 auto-mitigating`) + only spell out any notable one. This is the "nothing for you here" reassurance, kept SHORT.
3. ✓ **Resolved** (§5, one approximate count line + reopened-exceptions only)
4. 🧠 **AI learnings** (§6, learning+trigger+clickable URL)
4b. 🔧 **Auto-fix review queue** — OPEN bot-drafted auto-fix diffs awaiting YOUR review/land, from `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/state/ot-autofix-diff-drafter-state.json`: ONE line `🔧 N drafted → review/land D…, D…` (dedup ids; EXCLUDE abandoned/rejected/landed — only LIVE drafts get the CTA). Omit if none. Moved here from the team fleet-health digest 2026-06-11 (those diffs are `owner=dennyzhang` — your review queue, not a team live-incident). Droppable under budget.
4c. 🔧 **Fixes not landing** — OPEN `[OT auto-fix]` tasks (`--owner=dennyzhang`) aged >7d with no resolution (`meta tasks.task` query: open + `[OT auto-fix]`-titled + created >7d ago). ONE line each: `🔧 <symptom> — T### (open Nd)`, ESPECIALLY **chronic broken detectors still firing** (e.g. retrieval/holdout sparse_delta `DETECTOR_BROKEN`). These are the bot's own fixes that aren't landing — the bot can't land them itself, so they need YOU to drive/decide; surfacing them HERE (once/day, consolidated) is the chronic-detector flag, NOT a per-cycle alert-monitor pop. Cap 3 worst; collapse rest to `+K more`. Omit if none. (operator 2026-06-12 `kELsQU_CtLk`: "use daily brief to flag that to me".) Droppable under budget after 4b.
5. 💬 **GChat / Workplace** (§1, §3) — only unanswered/actionable; lower priority, near the bottom
6. ▶ **Followups** (§7) — only if >7d blocked

**Dedup (HARD):** each id appears in EXACTLY ONE of 🆘 / 🔵 / ✓ — by capability. Never both, never neither. (The old 🆕 / 🔴 / nudge / separate-needs-help type-buckets are SUPERSEDED by the 🆘-vs-🔵 split; the §4/§5/§6 definitions below still say HOW to source each item, but every open item lands in 🆘 or 🔵.)

**Caps (HARD) — brevity beats completeness:**
- 🆘 NEEDS YOU: cap 5 full lines; if more, show top 5 by urgency + `+N more need you — <query to list>`. (Never silently drop a 🆘 item; the overflow line is mandatory so the count is honest.)
- 🔵 TRACKED: ALWAYS collapse to ONE count line (`🔵 N tracked — X owner-progressing, Y auto-mitigating`); spell out at most 1 notable. Never enumerate.
- ✓ Resolved: ONE approximate count line.
- 🧠 learnings: ≤3 `✅ adopted` (cap, `+N more`) + ALL `⚠️ NEEDS YOUR CONFIRMATION` (never capped).
- **Total brief ≤18 lines** (tightened from 22 — the 🔵 collapse buys the room). If over, drop bottom-up: Followups → GChat/Workplace → trim 🔵 to count-only → trim `✅` learnings. NEVER trim 🆘 or ⚠️-confirmations.

**Grounding (HARD — no fabricated blockers):** the `bot blocked on: <X>` clause and the 🆘-vs-🔵 classification MUST be derived from the SEV/alert's ACTUAL latest state — its last update/comment, its triage record in the cron `raw_response`, or its status field. Do NOT invent a plausible-sounding blocker. If you can't cite a real reason a human is needed, the item is 🔵 (tracked), not 🆘. Quote/paraphrase the real signal, never a guess. (Pairs with the "ground in live truth, never fabricate" principle.)

**Freshness re-check (HARD — drop stale items before send):** SEV/alert state changes between the data pull and the send. Immediately before the explicit 1:1 send, re-verify each 🆘 item is STILL open/unresolved (`meta sevmanager.sev metadata --sev=S<id>` status, or the alert still firing). Drop any that resolved in the gap; move any that newly need a human INTO 🆘. A brief that pages humans to a SEV already mitigated 10 min ago is worse than no brief.

**Final self-check before send:** (a) line 1 = BLUF header; (b) no id twice; (c) every 🆘 line has a real (non-fabricated) `bot blocked on:` why + triage-thread URL; (d) 🔵 is a count line, not a list; (e) resolved is one ~count line; (f) ≤18 lines; (g) freshness re-check done — no 🆘 item is already resolved; (h) **info density — no fact, command, URL, or id appears more than once** (the `meta sevmanager.sev list …` lookup appears exactly ONCE as the `📂 All open OT SEVs` line; counts/commands are never restated — operator flagged duplicate command 2026-05-31). Fix any miss before delivering.

**Rendering rules:**
- **Never append `https://www.internalfb.com/sevmanager/view/<num>` after a SEV id.** GChat auto-linkifies bare `S<num>` tokens, so the trailing URL is pure noise. Same for `D<num>` (diff), `T<num>` (task). Only emit a literal URL when there is no shorthand id (e.g. a Workplace post, a doc).
- For SEV lines: `<sev_number> — L<level> <status> | <title> | <product group> | <one-liner of why it matters>`. No view URL. **`sev_number` already carries the `S` (e.g. `S667572`) — render it as-is, never prepend another `S` (double-`S` bug, backtest 2026-05-30).**
- **Use the PRODUCT GROUP, not an individual unixname** (2026-05-30 operator: "the product group name is better"). Derive the group from the model/title: `ig_organic_feed*`/`ig_feed*`→IG Feed, `ig_reels*`→IG Reels, `cfr_*`→CFR, `ifr_*`/`*ifr_main*`→IFR, ` esr`/`lsr`/`ext-share`→ESR/LSR, `threads*`→Threads, `i2i`/`I2I`→I2I retrieval. If the group can't be inferred, fall back to the SEV's owning oncall/team, then `?` — never a bare personal unixname.

1) **OT GChat** — @mentions and replies in bound OT space (spaces/AAQAVOjYc80) and team-visible activity in MRS Online Training Users Workplace group. Skip operator DMs and unrelated spaces. **Only include items the operator has not already engaged** (unread @mention, unanswered question, etc.). If everything was already replied to, omit the section.

2) **OT Diffs** — ❌ DROP THIS SECTION ENTIRELY. The operator's own diffs are visible in Phabricator's reviewer queue and inbox; surfacing them in a brief is noise. Teammate diffs only show up here if the operator is the reviewer, which is again better surfaced in Phabricator native. **Do not emit a diffs section.** (Rule established 2026-05-18 thread `BzwgIQr_f48` after operator: _"Not helpful. Too much info."_)

3) **OT Workplace** — Posts in `mrs.ot` group (id 1084744250286987) the cron didn't auto-handle. Skip sibling-team groups (Ads, WhatsApp, Wearables, etc.) and prior shift-summary posts (title regex `^Oncall Summary`).

   **Frontmatter `wp_post_ids`**: capture ALL post IDs from the 24h window (after filtering shift-summaries). This is the full inventory consumed by `ot-shift-summary`. Do NOT filter by SEV linkage here — the shift summary needs every post.

   **Brief narrative (section 3 body)**: surface only posts with high-confidence relevance to an active SEV or open question — not speculative links. Confirmed-link format: `• <author> (<date>): "<title excerpt>" → confirmed-related to <S…> (<basis>)`. If no posts meet this bar, omit the narrative but STILL populate `wp_post_ids` in frontmatter. (Lesson: 2026-05-28 shift showed 0 WP reports because daily-brief's strict filter stripped Hao Sha + Sanket Karnik's May 27 posts — both valid user reports missing from the shift summary.)

4) **Active OT incidents** — In-progress SEVs with `mvai-online-training` tag OR active alerts on `mrs_online_training` oncall feed. Apply MRS-org filter — drop sev_type ∈ {Ads, WhatsApp, Wearables, Oculus} and any title-hard-exclude hit (`[Ads]`, `Ads ML`, `DPA`, `WA4A`, `AF OC`, `ads_mtml`, `adfinder`, `adindexer`, `aps`, `aps_`, `aps-training-online`).

   **POSITIVE MRS-prefix gate (2026-06-10, the `aps` Ads-leak fix).** The title-hard-exclude is a denylist and will always lag new Ads service names (`aps`/`aps-training-online` = Ads Prediction Service leaked because it wasn't listed). Backstop with an ALLOWLIST gate: a candidate is surfaced ONLY if it carries a positive MRS marker — the referenced training job/model is `mvai-`-prefixed (MRS OT job names are `mvai-training-online-<eid>`) OR the model is present in `human-input/models.md` (MRS-tracked) OR sev/alert carries the `mvai-online-training` tag. No positive MRS signal → drop, regardless of denylist. This makes an Ads `aps-training-online-*` job (not `mvai-`-prefixed, not in models.md) structurally invisible even when its exact name is novel. Canonical gate is `scope_check` (`team_lane_scope.is_in_mrs_org_scope`); these terms must be added there too — see ot-sev-monitor step 4.5.

   **Surface only the SEVs the operator needs to take action on today.** Split into buckets, in priority order; omit any bucket that is empty:

   - **🆕 NEW & URGENT (last 24h)** — THE LEAD BUCKET; what just broke (2026-05-30 operator: "it's missing: new major issues occur recently — major alerts, new SEVs, urgent pings"). Pull THREE sources, not just the in-progress SEV list (which misses brand-new SEVs, alerts, and pings):
     1. **New SEVs (opened last 24h, any status):** `meta sevmanager.sev list --tags=mvai-online-training --created-after="24 hours ago" --limit 30 -o json` → render each `<sev_number> L<level> <status> — <title> | <why/impact>`. (Includes ones already mitigated — still worth a one-liner so the team knows it happened.)
     2. **Firing MAJOR/CRITICAL alerts:** `meta oncall.feed list --oncall=mrs_online_training --item-type-is=Alert -o json --limit 30` → keep urgency `high`/`critical`. **MANDATORY: filter by `alert_created_time` within the last 24h** — the feed returns ALL currently-active alerts, including ones firing for days; without this filter old-still-firing alerts get mislabeled "NEW" (verified bug 2026-05-30: 2 of 6 were 114–115h old). Compute `cutoff=$(date -d '24 hours ago' +%s)`, keep `alert_created_time > cutoff`. Alerts older than 24h but still firing belong in §4 active context, NOT 🆕. Render `🚨 <model_id> — <alert title excerpt> | <urgency>` with the alert's `short_id` URL (NOT the raw `?alert_id=` form — doesn't resolve for AGG alerts). Dedup AGG vs sub-alerts by model_id.
     3. **Urgent pings:** @mentions / posts in the bound space or `mrs.ot` matching `(urgent|UBN|SEV|escalat|can you|blocking)` in last 24h that the operator hasn't answered. One line each with the asker + ask + link.
     If all three are empty, render `🆕 none in last 24h` (explicitly — its absence is itself signal that the night was quiet).
   - **🤖 WHERE AI NEEDS HELP (last 24h)** — triage cases the bot could NOT confidently resolve and that need a human (2026-05-30 operator: "missing: all triage incidences where ai is not capable to solve"). This is the highest-value bucket — it's the explicit hand-off list. Source = parse last-24h `raw_response` of `ot-sev-monitor`/`ot-alert-monitor`/`ot-post-monitor` (triage_events table is unused/empty — do NOT query it):
     ```bash
     sqlite3 -separator '|' ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db \
       "SELECT job_id, run_at, raw_response FROM job_runs WHERE job_id IN ('ot-sev-monitor','ot-alert-monitor','ot-post-monitor') AND run_at > datetime('now','-24 hours');"
     ```
     Flag a case as needs-help if its raw_response shows ANY of: `confidence: low`/`"confidence":"low"`, `verdict: UNKNOWN`/`⚪ UNKNOWN`, validator `discrepancy`/`misattribution`, or `pattern unmatched`/`no known pattern`. Render `• <S###/A### + model> — <symptom> | bot stuck: <what it couldn't determine> → <product group> | [triage thread](<bot_reply_url>)`.
     **MANDATORY: attach the bot's prior triage GChat thread URL** (2026-05-30 operator: "ai have prior failed attempt in gchat, so the chat thread needs to be attached"). Extract the `Bot reply: <url>` line the triage cron persisted in its raw_response (ot-sev/alert/post-monitor emit this per the structural-URL rule). Attaching it serves BOTH purposes: the human acts on the live issue AND leaves triage-improvement feedback in the same thread (closing the bot's learning loop). If the bot-reply URL is missing, say `[no triage thread — bot send failed]` rather than omitting. (Same corpus `ot-human-attention-brief` §1 uses.) If none, render `🤖 none — bot resolved everything it triaged in 24h`.
   - **🔴 NEW TODAY** (opened or status-changed in last 24h): full SEV line per the rendering rules. These are the operator's primary attention targets.
   (Removed 2026-05-30 per operator: "'need nudge' is not useful" — stale-but-unchanged SEVs are not actionable signal for the morning brief; do NOT emit a NEEDS-NUDGE bucket.)

   **MANDATORY: every SEV line states WHY it needs eyes** (2026-05-30 operator: "you didn't explain why it needs eyes"). A title + timestamp is a database row, not a brief. The `<why it matters>` clause must name the concrete reason a human should look NOW — the blocker, the risk, or the next action — derived from the SEV's latest update / status / impact. Examples: `…| rollback status unconfirmed Day 7 → check with ext-share team`, `…| conveyor blocked, no publish in 9h → needs Hopper GPU`, `…| Day 110 preemptive, no owner movement → close or escalate`. NEVER emit a SEV line whose only content is title + age + timestamp.
   - **📊 In-progress counts**: fold this into the 🔵 TRACKED count line (`🔵 N tracked …`) — do NOT emit a separate counts line, and do NOT repeat the `meta sevmanager.sev list …` command (it already appears ONCE as the section-lead `📂 All open OT SEVs` line — repeating it is the duplicate-info bug operator flagged 2026-05-31). The lookup command appears exactly once in the whole brief.

   **Always lead the section with the canonical lookup command** so the team can scan beyond what we surface inline. Render verbatim (no fabricated UI URL — sevmanager has no public list URL with tag+status filter; the prior `https://www.internalfb.com/sevmanager/list?tag=...&status=...` returned 404, operator-caught 2026-05-08):

       `📂 All open OT SEVs: meta sevmanager.sev list --tags=mvai-online-training --in-progress`

     If a stable URL is later confirmed (verified fburl, or sevmanager dashboard query string that loads a real filtered view), replace this command with that URL. Until then, the CLI command is the verified surface — do NOT invent a /sevmanager/list?tag=... URL again.

5) **Recently resolved (last 48h)** — **COUNT-ONLY by default + exceptions** (effectiveness fix 2026-05-30: a resolved SEV is *done* — it needs no action, so a long enumerated list is bytes-not-signal and violates the brief's "every line tells you what to DO" rule). Render exactly:
   - One summary line: `_✓ N resolved in last 48h (M×L3, K×L4)_` — that's the situational-awareness signal; the operator can drill via the query if curious.
   - THEN enumerate **only the exceptions that still need a human**: a resolved SEV that REOPENED, regressed, or carries an open follow-up task. One line each: `⚠️ <sev_number> (L<level>) — <why it still needs eyes> (<owner>)`. If there are no exceptions (the normal case), enumerate nothing — the count line stands alone.
   - Omit the whole section only if N == 0.
   **Validated query for the count + exception scan (2026-05-30 backtest):**
   ```bash
   CUT=$(date -u -d '48 hours ago' +%Y-%m-%dT%H:%M:%S)
   meta sevmanager.sev list --tags=mvai-online-training --status=mitigated --created-after="14 days ago" --limit 50 -o json \
     | jq -r --arg cut "$CUT" '[.[] | select(((.updated // "") | tostring) > $cut)] | sort_by(.updated) | reverse | .[] | "\((.sev_number|tostring) | if startswith("S") then . else "S"+. end) L\(.level) — \(.title) (\(.owner_unixname | if (.//"")=="" then "?" else . end))"'
   ```
   **Query mechanics (2026-05-30 backtest — three bugs found + fixed):**
   1. **`--limit 50` + `--created-after="14 days ago"` are MANDATORY** — the bare list defaults to ~10 rows, silently truncating (real OT SEV count is ~40+). Without the bound you get a tiny arbitrary slice.
   2. **`time_mitigated`/`time_closed` are EMPTY in the list output** — do NOT filter on them (always yields 0). Use **`updated`** as the resolution-recency proxy (a mitigated SEV's last `updated` ≈ when it was mitigated; verified S668293 `updated=2026-05-30 18:12` = its mitigation time). Filter `updated > CUT`, sort by `updated` desc. **Residual imprecision (accepted):** `updated` changes on ANY edit, so a SEV mitigated earlier but commented-on in-window will be counted — acceptable because this is a COUNT-ONLY line (low stakes); never enumerate the list, and phrase as `~N resolved/closed (48h)` so the count reads as approximate, not exact.
   3. **Render:** `sev_number` already carries `S` (normalize, don't double it); `owner_unixname` is often an empty string — `// "?"` misses empty strings, use `if (.//"")=="" then "?" else . end`.
   Field keys: id=`sev_number`, severity=`level` (string), recency=`updated`, owner=`owner_unixname`, link=`url`. Cap 5; append `+N more` if exceeded. (Window is 48h for the daily brief; widen `CUT` to `7 days ago` only if the operator wants a richer weekly-resolved view.) Cap 5; append `+N more` if exceeded. **Omit the section entirely if none** (backtest 2026-05-30: 0 in window → section omitted; the 48h bound is mandatory — without it the `mitigated` query returns the all-time list). (2026-05-30 merge: this folds the former `ot-triage-summary` GChat digest into the single morning brief — the durable per-issue resolved FILES are still written separately by `ot-triage-summary`, which no longer posts to GChat.)

6) **🧠 AI learnings (last 24h)** — what the bot learned since yesterday, so the team can **review the reasoning, not just a label** (2026-05-30 operator: "'ai learnings' — this doesn't give concrete context for the team to review"). Each line MUST carry: the learning + the concrete TRIGGER (the incident/mistake/observation that produced it) + a **clickable URL** (2026-05-30 operator: "ai learning: need to attach urls" — a local `memory/*.md` path is NOT clickable for the team and must never be the source). URL priority: source-incident URL (`S###`/`D###`/`T###` auto-linkify in gchat; `A###` and memory paths do NOT — resolve a real URL or cite the originating gchat thread `https://chat.google.com/room/AAQAVOjYc80/<thread_id>`). Format:
   `• <what changed/was learned> — triggered by <incident> → <clickable URL: S###/D###/thread, never a memory path>`
   A bare headline ("BLUF reply protocol") is NOT reviewable — the team can't tell if the lesson is right without the trigger + source. Example: `• Resolved-SEV lists are noise → count-only — triggered by operator feedback in [thread](https://chat.google.com/room/AAQAVOjYc80/<id>)`.
   Sources, in priority order:
   - New/updated memory rules: `find ... -newermt` gives candidates, BUT mtime is unreliable (linters/edits re-touch old files — verified 2026-05-30). **Confirm each candidate is genuinely new by checking its content date** — the dated source-incident in the body (`**Why:** YYYY-MM-DD …`) or the ledger date must fall in the window; drop files whose mtime moved but whose content date is older. Use `description:` (the learning) + the `**Why:**`/source-incident line (the trigger).
   - New ledger entries: `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md` head — use the `Learning:` + `Trigger:` fields directly.
   **NEXT-LEVEL DETAIL + CONFIRMATION TIER (2026-05-30 operator: "ai learnings should have next level details … ai learning might need human confirmation").** Each learning is a 2-line entry, not a one-liner:
   - Line A (the learning): `<status-marker> <what changed> — triggered by <incident> → <clickable URL>`
   - Line B (the detail): `before → after: <the concrete behavior change>` (what the bot did wrong/lacked → what it now does). This is the "next level" — a reviewer must see the actual rule change, not just its name.
   **Status marker = the confirmation tier:**
   - `✅ adopted` — the bot is confident + the change is low-risk/mechanical (already live). FYI only.
   - `⚠️ NEEDS YOUR CONFIRMATION` — the bot is UNCERTAIN the lesson is correct, OR it's high-impact/governance-changing (alters a hard rule, paging logic, scope, or a cross-job behavior). Append an explicit ask: `confirm? (👍 keep / 👎 revert)` + where it's staged. The bot does NOT silently bake an uncertain/high-impact learning into standing rules without sign-off — it surfaces it here for approval. (This makes the section a review GATE, not just a digest.)
   Default tier when unsure: `⚠️ NEEDS YOUR CONFIRMATION` (a wrongly-auto-adopted rule is costlier than one extra confirm).
   Top 3–5 by importance (always include every `⚠️ NEEDS YOUR CONFIRMATION` item even if it pushes past 5 — confirmations don't get truncated; `✅ adopted` items are the ones capped). Omit the section only if nothing new in 24h.

7) **OT followups** — Actionable team-coordination items only. **Only include items that are blocked on someone and are >7 days stale.** Examples: a SEV awaiting `mvai-online-training` tag for >7d, a runbook update that's overdue, a cross-team handoff that hasn't been acknowledged. NOT operator's personal todo list. NOT a re-listing of SEVs already in section 4. **NO same-day operational retries** — bot/cron self-maintenance (e.g. "ot-knowledge-distillation missed yesterday, retrigger it", a missed-cron retry, a daemon-restart reminder) is NOT a team-coordination followup; it belongs to `ot-cron-health-guard` monitoring, never this brief. The >7d-blocked-on-a-human bar excludes anything same-day or bot-owned by construction. If nothing meets the bar, omit the section.

8) **Persist to state file (consumed by `ot-shift-summary` cron).** AFTER posting the brief to the bound space, write the same rendered content (sections 1-7, no truncation) to:

   `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/daily-brief-state/daily-brief-<YYYY-MM-DD>.md`

   File format — YAML frontmatter + markdown body:

   ```
   ---
   date: <YYYY-MM-DD>
   generated_at: <ISO8601 PT>
   entries: <int>                   # total signal count across sections 1-7; 0 = quiet day
   sev_ids: [S<num>, S<num>, ...]   # extracted from sections 1, 3, 4
   diff_ids: [D<num>, D<num>, ...]  # from section 2
   wp_post_ids: [<num>, <num>, ...] # ALL mrs.ot posts in the 24h window (not just SEV-linked ones) — shift-summary needs the full list; section 3 narrative may still filter for brevity
   ---
   <verbatim brief content>
   ```

   `entries` is the canonical "did this cron produce signal today?" field — `ot-shift-summary` uses `entries: 0` to distinguish a quiet day from a missed cron run. ALWAYS populate it (sum of unique SEVs + diffs + WP posts + alert mentions + followup items, deduped); never omit even on quiet days.

   `mkdir -p` the state dir if missing. Filename is date-stamped — re-runs same day OVERWRITE (one canonical brief per day). If sections 1-7 are all empty (i.e., you would have posted "All clear on the OT front this morning"), still write the file with `entries: 0` in frontmatter so `ot-shift-summary` can distinguish "quiet day" from "cron didn't run."

**Self-check before sending — four-question gate.** For every line:
1. Is this OT-incident or OT-coordination content? (scope)
2. Does it belong to the MRS org? (org boundary — Ads/WhatsApp/Wearables/etc. all FAIL)
3. Is this visible to every member of this space already? (privacy — calendar, DMs, personal followups all FAIL)
4. **Does this line tell the reader what to do or investigate today?** (signal — status-quo lines, bare SEV-number dumps, and speculative links all FAIL)
Drop any line failing ANY question. Honest empty brief beats noise; cross-org bleed and privacy bleed both beat nothing — never trade one for the other.

**Total length budget: ≤20 lines** (excluding the section-leading `📂 All open OT SEVs:` command line and YAML frontmatter in the state file). If the natural brief exceeds 20 lines, tighten the line wording before considering dropping items.
