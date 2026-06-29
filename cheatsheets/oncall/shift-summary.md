# Shift Summary — Cheatsheet

> **Sibling cheatsheets:** [handoff.md](handoff.md) (lightweight rotation handover) · [issue-report.md](issue-report.md) (cross-team write-up) · [INDEX.md](INDEX.md)
>
> A **shift summary** is the comprehensive weekly record of an oncall shift. Audience: outgoing oncall (review), incoming oncall (context), team leads (trends). Target: **3-4 pages max, scannable in 2 minutes.**

---

## 0. Goals and principles

**Goal:** a report that the incoming oncall trusts, team leads scan in 2 minutes, and future oncalls search for precedent.

| # | Principle | Test |
|---|---|---|
| 1 | **Impact over activity** | Does every highlight answer "so what changed?" not "what did I do?" |
| 2 | **Timeline is the story** | Is every SEV, alert, and post placed in the day it happened? |
| 3 | **Engaged vs observe-only** | Do only oncall-engaged items get full treatment? |
| 4 | **Every item is clickable** | Can the reader click through without searching? |
| 5 | **3 pages max** | Can you cut one more section? Merge two sections? |

**Decision framework — what deserves full treatment (HIGH-TOUCH):**
- Oncall **filed** the SEV → HIGH-TOUCH (strongest signal)
- Oncall PAGE'd someone, posted to WP, filed a diff, or joined a SEV chat → HIGH-TOUCH
- Bot triaged it, oncall never touched it → one FYI line
- Alert auto-resolved in 30 min → don't mention at all
- Same SEV appears in carryover AND timeline → put it in the day you engaged, cross-ref from FYI

**Generic linking rules:**
- ALL SEVs must be clickable: `https://www.internalfb.com/sevmanager/view/<number>`
- ALL WP posts must be clickable: `https://fb.workplace.com/groups/mrs.ot/permalink/<id>/`
- ALL diffs must be clickable: `https://www.internalfb.com/diff/D<number>`
- No bare names or IDs anywhere — if it's referenced, it's linked

---

## 1. Structure (7 sections, not 11)

```
Title + Outgoing → Incoming

1. Overview
   - Headline numbers table (4-6 rows max)
   - Shift metrics (bullets: difficulty, hours, wakeups, noise)
   - Shift character: 2-sentence summary of what dominated

2. Impact this shift (not "what went well" — what CHANGED)
   - Outcomes that altered system state, quantified
   - Key failing patterns identified

3. Pain Points (systemic issues + proposed fix + CC owner)

4. Hand-off (action items for incoming, sorted by urgency)

5. Daily Timeline (MAIN SECTION)
   Per day: SEVs engaged, WP posts, alerts, diffs landed

6. FYI (one section, not three)
   - Observe-only SEVs: one line
   - Auto-resolved alerts: one line
   - Alerts resolved with diffs: brief list with task IDs

7. Diffs (closed + open tables)
```

**Why this order:** Overview in 10 seconds → impact + pain points for leadership → hand-off for incoming → daily story for anyone who wants depth → FYI/diffs for reference.

**Reference post:** Li Lu's 5/12-5/19 shift summary (https://fb.workplace.com/groups/mrs.ot/permalink/1329661585795251/) — narrative-first, 150 lines, covers the same volume we do in 3x fewer pages.

---

## 2. Impact this shift — what CHANGED, not what you did

This section is NOT "what went well" (self-congratulatory). It's **what's different now vs when the shift started.** Each bullet should pass the "so what?" test from a team lead.

| Activity (bad) | Impact (good) |
|---|---|
| Landed D106194663 (i2i SLI fix) | 2 weekly UBN alerts permanently eliminated — D106194663 + D105890355. These fired every week; now resolved. |
| Investigated S667544 DPP spike | 3 key failing patterns identified and documented: zombie jobs (SJD gap), DPP 20-day restart (~280 dips/half), publish-path fragility. 12 new sub-mechanisms added to failure-patterns.md. |
| Posted to user group about DPP | DPP team looped in for graceful session rotation — if adopted, eliminates ~280 non-actionable alerts/half fleet-wide. |

**Test:** if the bullet doesn't make a team lead say "the system is better now," rewrite it.

---

## 3. Daily timeline — the main section

**The shift story is chronological, not categorical.** Don't separate SEVs, alerts, and user reports into their own sections. Group them by the day they happened.

Per day, include:
- SEVs the oncall engaged with (not observe-only)
- WP posts and user reports
- Key actions taken (diffs, analysis, broadcasts)
- Alerts that needed investigation

**Example:**
```
5/22 Thu
- S665454 L3: Threads U2M trainer stuck 14h — QPS zero, TMS didn't restart.
  Manually killed. Same root as S665478.
  WP broadcast: "Threads U2M stuck 14h — nobody noticed"
- Hongzhang Yin WP: sparse delta volume IGR ESR
- Wei Zheng WP: T2I 2145491885 SPARSE_DELTA stopped (11 comments)
```

---

## 4. Observe-only items — one FYI line, not full narratives

SEVs where the oncall was NOT engaged get ONE consolidated line:

**Bad (takes 10 separate paragraphs):**
```
S659671 L3 — m875961478 5+% error rate
(OT oncall: observe-only, no direct oncall engagement.)
Next oncall: Monitor.
[repeat 9 more times]
```

**Good (one line):**
```
FYI — 8 carryover SEVs (observe-only): S659671 L3 (14d, ajfoiani),
S659917 L3 (13d, prgzz), S657071 L3 (23d zombie), ...
Next oncall: ping zombie owners (S657071, S654768, S635148) or close.
```

Same for alerts: "21 of 24 alerts auto-resolved. No action needed."

---

## 5. Alerts — only actionable items

Don't enumerate all triaged alerts. List only:
- False alarms needing config fixes (with follow-up task ID + fix diff)
- Threshold changes needed
- Notable patterns

**Example:**
```
Publishing Stability: model 2132070936 missing SPARSE_DELTA, DENSE_DELTA
False alarm — alert expects dense delta which this model doesn't publish.
Follow-up: T272053606 — fixed by D106194663
```

---

## 6. Pain points — name the problem, propose the fix

Each pain point: problem statement → proposed fix → CC owner.

**Example:**
```
Training job zombies: OT jobs hang 6-28h — main process dead but
container alive (sidecars). SJD cannot detect. Only manual kill.
Proposed: rank-error + alive-process SJD rule.
Owner: managed_training_service oncall
```

Track across shifts — when the same pain point appears 5+ times, escalate.

---

## 7. Shift metrics — bullet points, not table

```
- Difficulty: 4/5
- Hours: 40
- Wakeups: 3
- Alert noise: 3/5
- What drove difficulty: High SEV volume, concurrent conveyor failures,
  DPP restart investigation, L3 zombie backlog
```

---

## 8. Hand-off — sorted by urgency, no duplicates

- SEV-blocking items first
- No already-committed diffs (those go in Diffs section)
- No "just monitor" items
- No duplicates (check for copy-paste artifacts)
- Embed `Next oncall:` in the daily timeline per-SEV entries too

---

## 9. "Shift character" replaces theme bullets

The old format had 10 theme bullets — duplicating the timeline. Replace with a **2-sentence "shift character"** in the Overview:

```
Shift character: Heavy week — 23 SEVs touched (4 HIGH-TOUCH), dominated
by training job zombie pattern (S665478+S665454) and DPP restart
investigation. Three concurrent conveyor/publish failures unresolved.
```

If a cross-incident pattern needs more than 2 sentences, it belongs in Pain Points, not a bullet list.

---

## 10. Common mistakes (from this session)

- **Tables for SEVs.** Tables compress out the oncall's contribution. Use narrative for engaged SEVs, FYI line for observe-only.
- **10 theme bullets.** The timeline covers events. Themes should be 5 max — only cross-incident patterns.
- **Observe-only SEVs get full narratives.** 10 paragraphs each saying "(bot-triaged, no engagement) Next: Monitor." → one FYI line.
- **Category sections (SEVs, Alerts, User Reports) alongside Daily Timeline.** Pick one structure. Timeline is the main section; category sections duplicate it.
- **Highlights that describe activity, not impact.** "Landed 2 diffs" vs "Eliminated 2 weekly UBNs."
- **Hand-off duplicates.** Items #3 and #4 identical — always dedup.
- **Wrong day-of-week labels.** Always verify with `python3 -c "from datetime import date; print(date(Y,M,D).strftime('%A'))"`.
- **W21 digest URLs 130+ chars.** Use short display text, not full paths.
- **Headline table buried below other sections.** It should be the first thing after the title.
- **Meta-commentary in the doc.** "OT-IC active-involvement filter (per Denny 2026-05-25)..." — the reader doesn't care about your methodology. Just show the content.
- **Claiming a fix without verifying.** API "OK" means the request was accepted — not that it worked. After every batch-update (especially link operations), re-read the doc structure to confirm the change landed on the right text. Link styling bleeds into adjacent elements silently.
- **Checking content text but not label text runs.** Google Docs splits bold labels and plain content into separate text runs. A search for "observe-only" misses the bold "SEVs" text run at a different index. Always dump ALL text runs in the index range around a comment, not just runs matching the visible content.

---

## 11. Pre-send checklist

- [ ] 3-4 pages max
- [ ] Highlights communicate impact, not activity
- [ ] Headline table is first thing after title
- [ ] Daily Timeline is the main section (no separate SEVs/Alerts/Posts sections)
- [ ] Observe-only SEVs consolidated into one FYI line
- [ ] Max 5 theme bullets (cross-incident patterns only)
- [ ] Hand-off sorted by urgency, no duplicates
- [ ] Every SEV/diff/alert/post is a clickable link
- [ ] Day-of-week labels are correct
- [ ] Shift metrics as bullets (not table)
- [ ] Pain points have proposed fix + CC owner
- [ ] No meta-commentary or methodology notes

---

_Last updated: 2026-05-25. Maintainer: dennyzhang. Sibling: [handoff.md](handoff.md) · [issue-report.md](issue-report.md)._
