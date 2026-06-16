# Issue Report — Cheatsheet

> **Sibling cheatsheets:** [escalation.md](escalation.md) (live, real-time hand-off) · [INDEX.md](INDEX.md)
>
> **OT-bot binding:** the OT team bot's external-posting policy (crisp 5-element template + trigger phrases for `mrs.ot` / SEV GChat / cross-team) lives in its runtime corpus at `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-generic/report-templates/crisp-report-style.md` — that's the OT-agent application of this discipline; this file is the personal/general counterpart. Keep the shared 5-element kernel in sync between the two.
>
> An **issue report** is the *post-investigation, async, cross-team-visibility* artifact. Use it when a finding deserves broad async attention and a written record that a future operator can find by search. Not for every triage; not for live escalation.

---

## 0. Goals and guiding principles

**Goal:** produce a report that the right people read, trust, and act on.

Five principles, in priority order. When two conflict, the higher one wins.

| # | Principle | What it means | Test |
|---|---|---|---|
| 1 | **Audience-first** | Structure by who's reading (model owners, oncall, owning team), not by investigation steps. Each audience gets a section answering *their* question. | Can each reader find their section in 10 seconds? |
| 2 | **Transparent & auditable** | Every claim has a link. Every number has a query. Every oncall name is from a lookup. The reader can verify without trusting you on faith. | Can someone who doubts your numbers re-run a single command and confirm? |
| 3 | **Action-first, details-last** | Summary → action required → next step at the top. Code paths, timelines, reproduction at the bottom (REFERENCE zone). | Can the reader decide "do I care?" in 5 seconds without scrolling? |
| 4 | **Pain over mechanism** | Lead with what hurts (noisy alerts, oncall toil, SEV risk), not what causes it (DPP session rotation, Zeus TTL). Cause is context, not headline. | Does the title make sense to someone who's never heard of the internal component? |
| 5 | **Precise language** | Numbers, not adjectives. "~280 per half", not "recurring." "Non-actionable", not "avoidable" (unless fix is confirmed). Weight words match certainty level. | Could a lawyer hold you to every word? |

These five subsume the original three principles below (fact+evidence → #2, importance filter → unchanged § 3, facts↔viewpoints → #5). The additions are #1 (audience-first), #3 (action-first), and #4 (pain over mechanism).

---

## 1. The foundational rules (don't violate these — everything else is style)

| Principle | What it means in practice | Anti-pattern |
|---|---|---|
| **Fact + evidence** | Every quantitative claim has a `meta`/CLI command (or query / paste / commit hash) behind it. Every "owner" is from a lookup. Every "recurring" cites prior dates. | "It seems slow", "I think the owner is X", "this happens sometimes" |
| **Importance filter** | File only if **impact × recurrence × actionability ≥ threshold** — see § 3. | Filing trivia, single-occurrence noise, or "FYI" with no actionable ask |
| **Facts ↔ viewpoints separated** | Use weight words: **observed / measured / verified** vs **hypothesized / inferred / recommended**. No mixing inside a paragraph. Use labeled sections so a reader can extract just the facts. | "X is broken because Y" (mixes observation with attribution); buried recommendations inside a "what happened" section |

These three are the **only** non-negotiables. If your draft violates any of them, stop and fix before sending.

---

## 2. The 2-artifact rule

One issue report = **one short post** + **one linked paste**. One does not substitute for the other.

- **The post** is the *scannable announcement*. Optimized for someone deciding in 30 seconds whether to engage. Hard cap ~10 lines.
- **The paste** is the *reproducible record*. Optimized for someone who decided to engage and wants to verify, reproduce, and act. Length is whatever the evidence requires.

Use `pastry` / `meta pastry` to create the paste **first**; the post links to it. Never send a post without the paste, and never send a paste without the announcing post. **Pastry does NOT render markdown** — use plaintext aligned tables, not pipe tables. See `comms/paste-formatting.md`.

---

## 3. Importance filter — should you file?

Three gates, all must pass:

### Gate A — Impact

At least one of:
- ≥ 1 hour of production SLO breach OR ≥ 1 critical alert fired
- Affects ≥ 2 distinct downstream consumers / models / teams
- Recurring (see Gate B) even at low-per-incidence impact

### Gate B — Recurrence or novelty

At least one of:
- **Recurring**: ≥ 2 prior occurrences in the last 30 days (cite the dates)
- **Systemic**: the failure mode is shared across multiple instances (family-level event)
- **Novel + dangerous**: never seen before AND would cause user-visible regression if left unaddressed

A single auto-resolved transient incident with no recurrence and no systemic implications does NOT pass Gate B. Write it in your incident archive and move on.

### Gate C — Actionability

A clearly-named owner (oncall, team, or specific person) can take a specific action based on this report. If you can't name the owner OR can't name the action, you're not ready to file — investigate more first.

**Decision rule:** all three gates → file. Any one fails → don't file (write a private incident note instead).

---

## 3.5. Pre-filing investigation protocol

Gather all evidence BEFORE drafting. The report is the output, not the investigation.

### Step 1 — Pull the error (not the kill reason)

```bash
meta ai.mast-job error --name=<job> --no-truncate
```

Walk the exception chain bottom-up. The lowest concrete error with a subsystem name is the cause; each wrapper above is a consequence. Don't anchor on `killReason` or `TASK_STOP_GENERIC`.

### Step 2 — Get actual logs (dead jobs still have logs)

```bash
# Find TW handle from attempts
meta ai.mast-job attempts --name=<job> --version=<N> -o json

# Pull logs around the failure time
tw log <tw_handle> --file stderr \
  --start-time "<before_failure>" --end-time "<after_failure>"

# Or via mast with regex filter
mast get-logs <job> --job-version <N> --regex "<error_pattern>"
```

**Don't assume dead-job logs are gone.** `tw log` and `mast get-logs` work for DEAD tasks for days after termination. Check before claiming "logs unavailable" — that claim cost 30+ min of wasted investigation time (learned 2026-05-22).

### Step 3 — Establish scope (one-off vs recurring)

```bash
# Search ai_mlu for the error signature across all jobs
scuba -e "SELECT job_name, time
FROM ai_mlu
WHERE error_message LIKE '%<unique_error_substring>%'
  AND time >= <30_days_ago_unix>
ORDER BY time DESC LIMIT 20"

# Filter to OT jobs if relevant
# ... AND job_name LIKE 'mvai-training-online%'
```

A one-off with auto-recovery doesn't need an XFN report. A pattern across multiple jobs does. State the count and date range.

### Step 4 — Verify claims with shareable evidence

Every quantitative claim needs a query a reader can re-run. Create shareable Scuba URLs:

```bash
scuba --url -e "<query>"
```

---

## 4. The post template (the 30-second announcement)

```
🚨 <One-line headline: impact + scope + recurring-or-novel marker>

<2-3 sentence summary. State the FACT (measured impact) first, the
HYPOTHESIS (root cause) second, the SCOPE (one-off vs recurring vs
family-wide) third. No mixing.>

Two reproducible failure modes / mechanisms (if applicable):
• <Mode A — short name + 1-line description>
• <Mode B — short name + 1-line description>

<Numerical anatomy if applicable: "Total Xh gap = ~Ah <cause> + ~Bh <cause>">

Tasks filed: T<id> (<short desc>), T<id> (<short desc>)
Related open SEV/issue: S<id> (<short desc>) — contributing but not root

Full investigation + reproduction + open questions: P<paste-id>
```

**Headline test**: paste the headline alone into chat. If a stranger can't tell from one line (a) what's broken, (b) how much it matters, (c) is this new or chronic — rewrite.

**The headline is a FACT statement, not a viewpoint.** Bad: "Concerning trend in publishing". Good: "25% of FULL_SNAPSHOT intervals miss 100-min SLO over 4 days".

**Headline writing rules:**

1. **Lead with the pain, not the mechanism.** The audience cares about the impact they feel, not the internal cause. Put the cause at the end as context.
   - Bad: "DPP 20-day session restart causes recurring example age spikes"
   - Good: "~280 non-actionable example-age dips with UBN/SEV risk per half — planned DPP restarts"

2. **Use accurate weight words.** Don't overpromise or overstate:
   - "avoidable" → only if you've confirmed the fix is feasible
   - "non-actionable" → accurate when the issue self-recovers and no human action helps
   - "UBN/SEV risk" → accurate when each event *can* trigger one, without claiming they all do
   - "false alerts" → may make the owning team defensive; prefer "non-actionable"

3. **Keep it short.** One line, scannable. Scope and details go in the body, not the title. If you need "across X models — caused by Y — affecting Z" all in the title, cut the least important part.

---

## 5. The paste template (the reproducible record)

Eight required sections, in order. Use plaintext formatting (see `comms/paste-formatting.md` — pastry does NOT render markdown).

**Structure rule: two-zone paste.** Sections 1-6 are the scannable main body (~2 min read). Sections 7-8 plus any detailed evidence (verbatim errors, source code, timelines, per-model tables) go below a `REFERENCE` divider. Readers decide whether to engage from the top; they verify from the bottom.

**Opening rule: summary + action + next step first.** Before section 1, the paste must have:
1. A one-line summary with **quantified impact** (what + how often + business consequence). Don't say "recurring" — say "~280 example age dips with UBN/SEV risk per half." The reader needs the scale, not the adjective.
2. ACTION REQUIRED line (even if "None")
3. NEXT STEP — what happens next, who drives it, and **what problem it solves** (e.g., "loop in DPP team to reduce ~280 noisy alerts per half")

These three lines let the reader decide in 5 seconds whether to keep reading and what to expect.

**Bad summary:** "DPP session rotation causes recurring example age spikes across the OT fleet."
**Bad next step:** "Discuss with DPP team for graceful session rotation." (describes the mechanism, not the problem being solved)
**Good summary:** "DPP session rotation causes ~280 example age dips per half across 50+ OT models, each with UBN/SEV risk. Next step: loop in DPP team to combat noisy alerts via graceful session rotation."

4. **TLDR must include confirmation path and linked evidence.** Improves transparency — people can audit your claims without trusting you on faith.
   - **Confirmation path:** include the error signature or a one-liner check so the reader can say "yes, this is my issue" in 10 seconds.
   - **Linked evidence:** every quantitative claim in the TLDR (e.g., "140 hits") needs a link (Scuba URL, paste, etc.). Unlinked numbers are unauditable and look like guesses.
   - Bad: "140 hits across 50+ OT models in 90 days."
   - Good: "140 hits across 50+ OT models in 90 days (https://fburl.com/scuba/ai_mlu/xxx). Confirm: `meta ai.mast-job error --name=<job> --no-truncate` — look for 'higher than limit: 1728000 seconds'."

Use the literal headings (ALL CAPS + divider lines, NOT markdown `#`):

```
================================================================
<REPEAT THE POST HEADLINE>
================================================================
Author: <unixname> (<oncall name>)
Date:   <YYYY-MM-DD>
Status: issue report, <no SEV / SEV S____ / etc.>

TLDR
<One paragraph. Same content as the post body but standalone for
paste readers who didn't see the post. State fact, hypothesis,
scope. No new claims here.>

----------------------------------------------------------------
SCOPE

<Measurements. Time window. Population (which models / jobs / users).
Specifically what is being measured and over what period. Cite the query
that produced the numbers.>

----------------------------------------------------------------
WHAT <AUDIENCE-A> NEEDS TO KNOW          (principle #1: audience-first)
----------------------------------------------------------------
<Answer their question: "Am I affected? Do I need to do anything?"
Keep it to 3-5 bullets. No jargon from the owning team's domain.>

----------------------------------------------------------------
WHAT <AUDIENCE-B> NEEDS TO KNOW
----------------------------------------------------------------
<Answer their question: "How do I recognize this so I don't waste
time investigating?" Include the verification command.>

----------------------------------------------------------------
IMPACT (MEASURED)                        (principle #2: auditable)
----------------------------------------------------------------
<Numbers with linked evidence. Every count has a Scuba URL or
paste link. No unlinked numbers.>

----------------------------------------------------------------
ROOT CAUSE (SHORT VERSION)               (principle #4: pain > mechanism)
----------------------------------------------------------------
<One paragraph. What happens, why, what the downstream effect is.
No code paths — those go in REFERENCE.>

----------------------------------------------------------------
WHY THIS IS SYSTEMIC
----------------------------------------------------------------
<Recurrence evidence. Prior occurrences with dates. Pattern that
predates / outlasts any single contributing factor.>

----------------------------------------------------------------
OPEN QUESTIONS FOR OWNERS
----------------------------------------------------------------
<For each owning team (verified via meta oncall.rotation list),
list specific information requests they can answer in their domain.
NOT "what should we do" — actual questions.>

----------------------------------------------------------------
PROPOSED SOLUTIONS (RECOMMENDATIONS)
----------------------------------------------------------------
<Priority-ordered. Each fix: owner, what it does, what it doesn't.
This is the FIRST section where viewpoints belong.>

================================================================
REFERENCE
================================================================

EVIDENCE / REPRODUCTION
----------------------------------------------------------------
<Copy-pasteable commands. Future reader runs these and confirms
the observations from sections 1-3 are reproducible.>

    meta ai.model.instance list --model-id=<ID>
    meta sevmanager.sev metadata --sev=S<ID>

<Also move here: verbatim error signatures, source code paths,
detailed timelines, per-model tables, TTL chains — anything
needed for verification but not for the 2-minute scan.>

RELATED ARTIFACTS
----------------------------------------------------------------
- Task T<id> — <what it tracks>
- Adjacent task T<id> — <what it tracks>
- Active SEV S<id> — <contributing, not root>
- Notes archive: <path>
================================================================
```

---

## 5.5. Writing patterns (from SEV-review exemplars)

Cherry-picked from imoc `incident_report_guide.md` (2026-06-10).

1. **Progressive disclosure — 3 self-contained layers.** Structure any
   explanation as **summary → mechanism → scope**, where a reader can stop
   at any layer with a complete (if coarser) understanding.
   - *Layer 1 (1-2 sentences):* "A diff removing a privacy annotation caused
     360 loggers to silently drop all data for 7 hours."
   - *Layer 2 (1 paragraph):* the mechanism — what code path, why it failed
     silently.
   - *Layer 3 (breakdown):* scope — tier split, downstream consequence
     ($ / users / models affected).
   This is complementary to the §5 two-zone split (it shapes the *body*;
   two-zone shapes the *paste*).

2. **Known problem, honest context.** When the SEV exposes a known-but-
   unfixed issue, address the obvious reviewer question head-on instead of
   letting it derail review: (a) acknowledge it was known → (b) the competing
   priorities that delayed it → (c) the original fix plan → (d) why interim
   mitigations were insufficient → (e) how this SEV reprioritized it. Builds
   credibility; preempts "if it was known so long, why not fixed?"

3. **Preemptive Q&A.** Answer the predictable reviewer question inline with
   an explicit `Q: … A: …` block (e.g., "Q: why not use DB transactions
   instead of app-level locks? A: deadlock risk from bursty writes — we
   evaluated it, batons give equivalent safety with better ops"). Shows
   thoroughness, keeps the review on track.

4. **Blameless framing.** Explain decisions charitably — why a reasonable
   person made that choice given what they knew at the time. The deepest
   root cause is never "human error"; it's the system gap that allowed it.

## 6. Writing discipline — small rules that matter

1. **Numbers, not adjectives.** "25% of intervals" not "many intervals". "11.5h gap" not "a long gap". "p90 = 284 min" not "tail is bad".
2. **Verb tense matters.** Past for what was observed ("v149 attempt 0 FAILED at 20:31:46 PDT"). Conditional for what is hypothesized ("would have produced ~2 snapshots if attempt 0 hadn't crashed"). Imperative for what is recommended ("add CREATING + size=0 + age > 30min → FAILED transition").
3. **Quote error strings verbatim.** Future grep-ability depends on it. `Exception: Async publish process creation failed!` — not "publish error".
4. **Name failure modes.** "Mode A — CREATING zombie", "Mode B — silent skip". A named mode is searchable; an unnamed observation is anecdote.
5. **Cite owners by lookup, not by memory.** `meta scuba.dataset metadata --name=dai_modelstore` returns oncall — paste that command's output, don't say "I think model_store owns this".
6. **Each section answers one question.** If a section spans facts AND interpretation AND recommendations, split it.
7. **Hyperlinks survive copy-paste.** Use full URLs (or paste IDs / task IDs / SEV IDs) — not "see the dashboard above".
8. **Alert URLs must use the full compound alert_id.** OneDetection alert_ids have the form `<numeric>@#$<entity>@#$<key>@#$<title>`. URL-encode the full id (`@ → %40, # → %23, $ → %24`). Never strip the `@#$` suffix — the numeric prefix alone 404s or lands on the wrong sub-alert. The emitted URL should contain `%40%23%24` segments. If it's only a bare number, it's broken.
9. **Flag AI-authored causal diffs.** If a SEV's causal diff is ≥25% AI-generated, add an AI-Generated-Code callout (diff#, AI%, tool name). It matters: AI-authored (≥90%) causal diffs cost ~2.4× the eng-hours per SEV (21.4h vs 9.0h baseline). Source: `fct_devinfra_ai_code_landed_diff_spans_signal` (landed `fbsource`/`configerator` diffs, ~1-day lag). From imoc `sev-summarization.md`.

---

## 7. Anti-patterns (don't ship if any apply)

- ❌ "We should probably fix X" — viewpoint with no recommendation owner / no proposed action
- ❌ "This seems related to Y" — assertion without lookup
- ❌ A paste with no reproduction section — future reader can't verify
- ❌ A post with no paste link — no record beyond gchat's history limit
- ❌ Numbers without queries — "25% miss SLO" with no query a reader can re-run
- ❌ Recommendations buried in a "what happened" section — separate them
- ❌ Single-occurrence incident written as systemic — passes Gate B is required
- ❌ Open questions phrased as suggestions ("should we maybe...") instead of specific information requests
- ❌ Owner-team unnamed or named by vague description ("the model team") instead of `meta`-resolvable oncall name
- ❌ Creating a Meta Task when asked for a report — report = write-up for XFN to read; task = separate action requested explicitly
- ❌ Claiming "logs unavailable" for dead jobs without trying `tw log` / `mast get-logs` — they work for days after termination
- ❌ Diagnosing root cause from the MAST kill reason alone — walk the exception chain bottom-up to the lowest concrete error
- ❌ Mixing header styles in one paste (`== ==` for some, `---` underline for others, `#` for a third) — pick one style and use it throughout
- ❌ ACTION REQUIRED buried at the bottom — put it at the top, right after the header
- ❌ Flat paste with no two-zone split — long pastes need a scannable main body + a REFERENCE section for verification details
- ❌ "By design" or "every N days" without citing the code/config that makes it so — claims about designed behavior need source file + line number
- ❌ Shortening oncall names from error message tags (e.g., `DPP_DISTRIBUTED_DATA_READING` → `dpp_distributed_reading`) — always verify with `meta oncall.rotation list --name=<name>` before using

---

## 8. Worked example

Tonight's post: [Publish-path fragility on IG OT models — recurring FULL_SNAPSHOT SLO violations](https://fb.workplace.com/groups/mrs.ot/posts/1331638558930887) + paste [P2347269408](https://www.internalfb.com/intern/paste/P2347269408).

Maps to the template as follows:

| Cheatsheet section | Where in the example |
|---|---|
| § 4 post template | The Workplace post body (~10 lines, headline + 2-mode breakdown + numerical anatomy + tasks + paste link) |
| § 5 paste § 1 Scope | "Measured against model `878858380` … last 4 days" + cadence stats table |
| § 5 paste § 2 Failure modes | "Mode A — CREATING zombie", "Mode B — Silent skip" with evidence tables |
| § 5 paste § 3 Reconstruction | "Today's full reconstruction" — trainer version history table + snapshot timeline |
| § 5 paste § 4 Systemic | "Why this is systemic (not a one-off)" section listing recurrence evidence |
| § 5 paste § 5 Open questions | "Open questions for owners" — 5 specific Qs for `model_store` / `feed_ecosystem_core_modeling` / `mvai` |
| § 5 paste § 6 Proposed fixes | "Proposed fixes (priority-ordered)" — 4 fixes with owners |
| § 5 paste § 7 Reproduction | "Evidence / reproduction" — bash commands |
| § 5 paste § 8 Related artifacts | "Related artifacts" — tasks T272497510 + T272497752, SEV S667071, related notes |

**What the example does well**:
- Lead with measured impact (25% miss SLO) before any hypothesis
- Both failure modes have names + evidence tables — searchable forever
- Numerical anatomy makes attribution quantitative (6h40m NaN + 3h9m publish-spawn + 1h42m recovery)
- Open questions are specific information requests, not "what should we do"
- Every owner came from a `meta` lookup, no guesses

**What you could critique** (no example is perfect — this is the iteration material):
- Mode A vs Mode B naming is local to this report; would be stronger if linked to a registry of named failure modes (future work)
- Recurrence evidence is dense; a small visual timeline would help
- "S667071 contributing but not root" — could be more crisply attributed (which sub-system specifically)

### Example B — lighter-weight XFN escalation (2026-05-22, MAST zombie detection)

**Post (pasted into GChat/Workplace):**

> `mvai-training-online-2124122280` (Threads retrieval) had its training workers crash at 04:01 PDT on May 16 due to a CUDA CachingAllocator `free_block` assert (SIGABRT on rank 1). The main process (light.py) exited by 04:05, but the TW container stayed alive because sidecar processes (VipInjector) kept running. MAST continued reporting the task as RUNNING, so TMS never auto-restarted the job. It sat as a zombie for 13 hours until `wenping` manually killed it at 17:11.
>
> This isn't a one-off — 7 other OT jobs hit the same CUDA assert in the last 35 days. The core question for managed_training_service: does MAST track the main command PID separately from the container, and can it detect main process exit when sidecars keep the container alive? Details and evidence: P2347925094

**Why this works (maps to principles):**
- First paragraph = measured fact (13h zombie, specific times, specific crash)
- Second paragraph = scope (7 jobs) + specific question (not "please investigate") + paste link
- Attribution implicit but clear: "question for managed_training_service"
- No verbatim logs inline — all in the paste

**Contrast with Example A:** Example A is a full Workplace post for broad async attention (publish-path fragility affecting many models). Example B is a focused XFN escalation asking one team one question. Both follow the 2-artifact rule but at different scales.

**Investigation that produced this report (§ 3.5 applied):**
1. `meta ai.mast-job error --no-truncate` → surface kill reason was "STUCK" (misleading)
2. `tw log <dead_job_handle> --file stderr --start-time/--end-time` → found the actual CUDA SIGABRT crash + fuse-overlayfs exit + 13h of VipInjector-only logs
3. Scuba `ai_mlu WHERE error_message LIKE '%CUDACachingAllocator%' AND job_name LIKE 'mvai-training-online%'` → 7 other OT jobs
4. Scuba `dai_modelstore` event type counts → verified "zero training activity" (3,224 UMM-only events)
5. `scuba --url` → shareable Scuba URL in paste

---

## 9. Checklist before sending

**Principles (§ 0):**
- [ ] Audience-first: each reader group has their own section
- [ ] Transparent: every number has a linked query (Scuba URL, paste)
- [ ] Action-first: TLDR → ACTION REQUIRED → NEXT STEP before anything else
- [ ] Pain over mechanism: title leads with impact, not internal component name
- [ ] Precise language: numbers not adjectives, weight words match certainty

**Gates (§ 3):**
- [ ] All three gates pass — impact, recurrence, actionability

**Post (§ 4):**
- [ ] Headline is a measured-impact fact, not a viewpoint
- [ ] Headline is short (one line) and leads with the pain
- [ ] Paste created and linked from post

**Paste (§ 5):**
- [ ] TLDR includes quantified impact with linked evidence
- [ ] TLDR includes confirmation path (how reader checks "is this my issue?")
- [ ] ACTION REQUIRED at the top, not the bottom
- [ ] NEXT STEP names the problem being solved, not just the mechanism
- [ ] Every "owner" verified via `meta oncall.rotation list --name=`
- [ ] Facts and viewpoints in separate labeled sections
- [ ] Open questions are specific information requests
- [ ] Two-zone split: scannable main body + REFERENCE section
- [ ] Plaintext formatting (no markdown — see `comms/paste-formatting.md`)
- [ ] One header style throughout (no mixing)
- [ ] No manual word wrap
- [ ] Reproduction section has copy-pasteable commands
- [ ] Related tasks / SEVs / diffs linked
- [ ] Filed in `~/notes/.../incidents/` for future searchability

---

_Last updated: 2026-06-10 (added §5.5 writing patterns + AI-provenance rule, cherry-picked from imoc skill). Maintainer: dennyzhang. Sibling: [escalation.md](escalation.md)._
