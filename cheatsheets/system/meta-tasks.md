# Meta Tasks Cheatsheet

Quick reference for creating, updating, and tracking Meta Tasks. Covers the `meta` CLI (primary), the `/tasks` skill, and diff-to-task linking.

## Task Content Quality — scannable + convincing (HARD, read FIRST)

Operator rule (2026-06-05, thread `Thr_mFDIb2Q`: "the task is not scannable, and not convincing enough"): a task that isn't **scannable** AND **convincing** fails no matter how complete. Run this gate on EVERY task create/update before posting.

**Scannable — reader gets it in ~10 seconds:**
- BLUF first line: what + the one number that matters. No preamble, no "Tracking the…".
- Structure, not prose: `BLUF → Why it matters → Evidence → Scope (checklist) → Done when → Refs`. Bold the labels; bullets/checkboxes over paragraphs.
- No prose walls — any section >3 lines of running text → convert to bullets or cut. Abbreviate numbers (16.4K not 16,374).
- **Easy to follow = one idea per line, plain words, narrative order** (problem → fix → done). Kill compound lines: no `->` arrows, no inline quotes mid-sentence, no parenthetical that smuggles a 2nd/3rd idea. (2026-06-05: a structured-but-compound rewrite STILL got "hard to follow" — the structure was right, the individual lines were overloaded. Scannable headers don't save an unreadable line.)

**Convincing — reader cares + could act:**
- Lead with COST/RISK, not the work: "pings 5 owners for 1 shared incident → real incidents get missed" beats "improve clustering."
- ONE concrete example with a real number/SEV/date — not "sometimes it's noisy."
- `Done when:` = verifiable acceptance criteria, never "improve X."
- Scope = a checklist of concrete, individually-shippable items.

**Template:**
```
BLUF: <what + killer number>.
Why it matters: <cost/risk if unfixed — the hook>.
Evidence: <one concrete example: real number / SEV / date>.
Scope: [ ] item  [ ] item  [ ] item
Done when: <verifiable criteria>.
Refs: <files / SEV / thread>.
```

**Bad→good (real, 2026-06-05 — first draft of T274581215 WAS the bad one):**
- BAD: ~20 lines of prose listing every weakness in paragraphs, impact buried mid-text, no acceptance criteria → operator: "not scannable, not convincing."
- GOOD: BLUF + "pings 5 owners for 1 shared Scribe incident → incidents missed" + 4-box checklist + "Done when: shared-cause renders as ONE clustered line with the SEV ref."

**Pre-post check (every create/update):** BLUF present? cost/impact in the first 2 lines? one concrete example w/ a number? scope is a checklist? done-when verifiable? Any "no" → rewrite before posting. (Deeper guidance: § Writing Compelling Task Descriptions + § Task Fields Checklist below.)

## CLI Reference — `meta tasks.*` (Primary)

Use `meta tasks.*` commands directly — faster than the skill and always available. The object hierarchy is `meta tasks.<object> <action>`.

**Key objects**: `tasks.task` (CRUD on tasks), `tasks.comment` (add/list/delete comments), `tasks.task.tag` (tags), `tasks.task.project` (GSD projects).

### Most-Used Commands

```bash
# Create a task
meta tasks.task create --title="Title" --description="..." --priority=HIGH --owner=dennyzhang

# Show task details (use knowledge_load MCP or /tasks skill — meta CLI lacks a show command)
# Workaround: meta tasks.comment list --task=T259215482

# Update task fields
meta tasks.task update --task=T259215482 --progress=IN_PROGRESS --priority=HIGH
meta tasks.task update --task=T259215482 --description="Updated description"

# Add a comment (NOT meta tasks.task update --comment)
meta tasks.comment create --task=T259215482 --text="Progress note"

# Update + comment in one call
meta tasks.task update --task=T259215482 --comment="Progress note" --progress=IN_PROGRESS

# Close a task
meta tasks.task update --task=T259215482 --close --comment="Landed D96084025"

# Reopen a task
meta tasks.task update --task=T259215482 --reopen --progress=IN_PROGRESS

# Link/unlink diffs
meta tasks.task update --task=T259215482 --add-diff=D67890
meta tasks.task update --task=T259215482 --remove-diff=D67890

# Add/remove tags
meta tasks.task update --task=T259215482 --add-tag=mrs-reliability
meta tasks.task update --task=T259215482 --remove-tag=old_tag

# Add subscriber
meta tasks.task update --task=T259215482 --subscriber=username

# Set dates
meta tasks.task create --title="Task" --target-date=2025-06-30
meta tasks.task update --task=T259215482 --target-date=2025-06-30

# List comments
meta tasks.comment list --task=T259215482

# Delegate to AI agent
meta tasks.task create --title="Fix bug" --description="..." --delegate-to-agent=claude --repo=fbsource
```

### Common Mistakes to Avoid

| Wrong | Right | Why |
|-------|-------|-----|
| `meta tasks.update comment` | `meta tasks.comment create` or `meta tasks.task update --comment` | `update` is not an object type — use `tasks.comment` or `tasks.task update` |
| ``meta tasks.*` CLI (or `/tasks` skill) comment T123 "text"` | `meta tasks.comment create --task=T123 --text="text"` | ``meta tasks.*` CLI (or `/tasks` skill)` is only available inside the `/tasks` skill runtime |
| `meta tasks.comment create --message="..."` | `meta tasks.comment create --text="..."` | The flag is `--text`, not `--message` (learned 2026-04-23) |
| `--status IN_PROGRESS` | `--progress=IN_PROGRESS` | Field is called `progress`, not `status` |
| `--priority=NORMAL` (or MEDIUM) | `--priority=MID` | Valid values are HIGH/MID/LOW/WISHLIST only. NORMAL/MEDIUM are rejected and the create FAILS — easy to miss if you don't check the exit (silent no-task, 2026-06-05) |
| `meta tasks.task update --number=T123` | `meta tasks.task update --task=T123` | `update` does NOT accept `--number` (that's only on `tasks.task archive`); use `--task` / `--task-number` / `--task-id`. `comment create` uses `--task` (2026-06-05) |
| `meta tasks.task show T123` | Use `knowledge_load` MCP with task URL | No `show` subcommand on `meta tasks.task` |
| `meta tasks.task.tag add --task=T123 --tag=X` | `meta tasks.task update --number=T123 --add-tag=X` | `tasks.task.tag add` is deprecated (learned 2026-04-28) |
| `meta google.docs.comment add --doc=... --untrusted-authors-mode=...` | drop the `--untrusted-authors-mode` flag entirely | The flag is not accepted by `comment add`; works without it (learned 2026-04-28) |

## Auto-filed tasks (crons / workflows) — HARD rules for any job that files tasks

Auto-filed tasks land in the operator's queue unattended, so they must be self-sufficient,
traceable, and de-duped. Every cron/workflow that calls `tasks.task create`:

1. **Set `--priority` — NEVER leave it UNKNOWN.** An UNKNOWN-priority task doesn't sort or
   triage in the queue. Default by class: chronic/ongoing → `LOW`; a real shared-cause / fix
   → `MID`; page-worthy → `HIGH`. (2026-06-07 audit: 5 bot tasks sat at UNKNOWN because the
   filers omitted the flag.)
2. **Verify the create RESULT before retrying — capture the returned `T<num>`.** A create that
   *looks* failed (your grep/parse missed the id, output truncated) may have SUCCEEDED;
   retrying then files a DUPLICATE. On any uncertain create, dedup-search by title before
   re-filing. (2026-06-07: T274822960 ≡ T274823017 — identical task created twice from an
   unverified retry. The verify-after-write rule, applied to task creation.)
3. **N-correlated = ONE task, not N.** The same signal across ≥3 models/items is ONE systemic
   event — file one task listing them, not one per item. Per-item filing fragments the queue
   and hides the shared cause. (2026-06-07: four separate `[OT chronic] … training-age` tasks
   for one signal; the systemic-gap collapse only fired at ≥5, so 3-4 clusters fragmented.)
4. **Provenance — name the FILER (autonomous-workflow principle #19).** Title leads with / the
   description names the originating job-id, so an orphan task traces to which cron filed it
   (debug the filer; dedup its own items). `[ot-fleet-health] chronic: …`, not `[OT chronic] …`.
5. **Owner = dennyzhang ONLY, handhold-first** — no other subscriber/assignee; the operator
   routes it himself (auto-routing to another oncall lands on a confused stranger).

## Auditing the queue — recognize non-actionable task classes

When auditing dennyzhang's open tasks, classify before acting (and verify the marker, not
just a heuristic — `author != dennyzhang` is NOT proof of any class):

- **Workplace-post syncs — AUTO-CLOSE when >2 weeks old (operator rule 2026-06-07).** A
  **Butterfly Rule** mirrors mrs.ot Workplace group posts (group `1084744250286987`) into tasks
  (owner=dennyzhang, author = the WP poster). Marker: the description STARTS WITH
  `Synced to internal group post`. These are redundant mirrors — the real discussion lives in
  the WP post — so they're queue clutter. **Rule: a wp-synced task whose `created` (or last
  `updated`) is >14 days ago can be AUTO-closed without per-task review** — by then the post's
  discussion is long resolved and the mirror is pure stale clutter. (Recent <14d wp-syncs may
  still be active → leave them.) Closing the task does NOT touch the WP post. **The generator
  is the Butterfly Rule (operator's Workplace config), NOT a bot cron** — a bot can't fix the
  source; if re-syncing is unwanted, the operator tunes/disables the rule. Mechanical
  enforcement of the >14d auto-close (vs. doing it by hand each audit) is a thin task-hygiene
  cron — the prose-vs-mechanical follow-on (flywheel contract #4). (2026-06-07: 17 closed in
  one audit.)
- **Don't blanket-close by author.** Confirmed-NOT-wp (despite external author): CI bots
  (`generatedunixname…` "your diff broke tests"), `thriftbot`, and real human feature tasks
  (e.g. dkotfis logging/test work) — all author≠dennyzhang but legitimately open. Check the
  description marker.
- **Stale real tasks** (operator's own, no activity 30–60d) → flag as close-candidates, don't
  auto-close; closure of the operator's real tasks is the operator's call.

## `/tasks` Skill (Alternative)

The `/tasks` skill wraps ``meta tasks.*` CLI (or `/tasks` skill)` and provides richer output (search, batch ops). Use it for interactive task management. Commands within the skill use the `tasks` alias:

```bash
tasks create "Title" --description "..." --priority HIGH --owner dennyzhang
tasks show T259215482
tasks update T259215482 --status IN_PROGRESS --comment "Progress note"
tasks list --priority HIGH --status OPEN
tasks list --text "monitoring coverage"
```

**When to use which:**

| Situation | Use |
|-----------|-----|
| Quick comment or status update mid-session | `meta tasks.*` CLI |
| Creating tasks with rich descriptions | `meta tasks.task create` |
| Searching/listing/batch operations | `/tasks` skill |
| Reading full task details | `knowledge_load` MCP with `https://www.internalfb.com/T<number>` |

### Task Lifecycle

```
Create → IN_PROGRESS (when work starts)
       → BLOCKED (when waiting on dependency)
       → IN_PROGRESS (when unblocked)
       → CLOSED (when diff lands + impact measured)
```

## Diff-to-Task Linking

### At Diff Creation Time

Include the task number in the commit message `Tasks:` field. Phabricator auto-associates the diff to the task.

```
Add conf build validation for tier-1 model monitoring coverage

Summary: ...

Test Plan: ...

Tasks: T258955052

Differential Revision: ...
```

The `Tasks:` field goes in the commit message metadata block (after Test Plan, before Differential Revision). Phabricator uses this to show linked diffs on the task page.

> **⚠ ANTI-PATTERN — task id in the title/summary does NOT link.** Putting
> the task number in the diff *title* or *summary* as free text (e.g.
> `PROPOSAL: dedupe X (T272497510)`) creates **zero** association — Phabricator
> only links from the `Tasks:` commit-message field (or an explicit
> `--add-diff`). The diff will look linked to a human reading the title while
> the task shows **0 linked diffs**. (Source: D106049931 ↔ T272497510,
> 2026-06-08 — title carried the Txxx, `tasks:` field was empty, no link.)
> This bites hardest on **Unpublished / proposal** diffs that never go through
> a submit flow that would surface the missing field.

> **✅ VERIFY (do this every time a diff addresses a task):**
> `meta phabricator.diff tasks --number=D<n>` MUST list the task. Empty output
> = the `Tasks:` field was missing → fix it. (Pairs with the verify-before-claiming
> rule: don't claim "filed a diff for the task" without this check.)

> **🔧 RECOVERY (backfill a missing link — works even on Unpublished diffs):**
> `meta tasks.task update --task=T<n> --add-diff=D<n>`. Creates the link from
> the task side (bidirectional). Use when the `Tasks:` field was forgotten and
> the commit is no longer in your local checkout to amend + re-submit.

### After Diff Lands: Update Task with Measured Impact

When a diff associated with a task lands, update the task with concrete results. This is the bridge between "I shipped code" and "it had this impact."

**What to include in the task update:**

| Category | What to Measure | Example |
|----------|----------------|---------|
| Coverage | Models/systems now covered | "65 tier-1 models now have conf build validation" |
| Prevention | Failures this would have caught | "Would have caught S630911 (SEV1, 20% dwell time drop)" |
| Reduction | Alerts, pages, or toil eliminated | "PE oncall no longer paged for OT publishing alerts" |
| Automation | Manual steps replaced | "Replaced manual allowlist maintenance with automated conf build check" |
| Baseline | Before/after metrics | "Monitoring gap: 48 models → 0 models" |

**Template for task close comment:**

```
Landed D96084025.

Impact:
- 65 tier-1 models now validated for monitoring coverage on every conf build
- 48 models with monitoring gaps identified and tracked
- Prevents repeat of S630911 (SEV1) — new tier-1 models cannot bypass monitoring

Before: Manual allowlist, no enforcement. Tier-1 models could exist without monitoring.
After: conf build fails if any TIER_0/TIER_1 model lacks confirmed MVAI monitoring.
```

### Automation: Post-Diff Task Update

Use this pattern after landing a diff to auto-update the linked task:

```bash
# 1. Get the diff number and linked task
DIFF="D96084025"
TASK="T258955052"

# 2. Get diff details for impact summary
jf diff-properties $DIFF | jq -r '.message' | head -5

# 3. Update task with impact
meta tasks.task update --number=$TASK --comment="Landed $DIFF. Impact: <measured outcome>. Before: <state>. After: <state>."

# 4. Close if exit criteria met
meta tasks.task update --number=$TASK --close --comment="Exit criteria met: <evidence>"
```

**When to auto-update vs. manual update:**

| Situation | Action |
|-----------|--------|
| Diff lands, task has clear exit criteria | Auto-close with impact comment |
| Diff lands, task needs more diffs | Update with progress, keep open |
| Diff lands, impact needs time to measure | Comment with diff link, set follow-up to measure later |
| Multiple diffs for one task | Update after each diff, close after last one |

## Writing Compelling Task Descriptions

Tasks visible to partner teams need to sell the value, not just describe the work.

### Structure

```
## Problem

<What breaks today, who is affected, concrete example (SEV number, metric drop)>

## Proposal

<What the solution does, how each stakeholder benefits>

### How <team 1> benefits
- <specific value>

### How <team 2> benefits
- <specific value>

## Exit criteria

- <measurable outcome 1>
- <measurable outcome 2>

## Related

- <SEV/task/diff links>
```

### Rules

1. **Lead with the pain.** "OT SEVs take 30-60 min to triage" beats "Build a triage agent."
2. **Quantify everything.** "48 models have monitoring gaps" beats "some models lack monitoring."
3. **Show each team's benefit.** Partner teams ignore tasks that only help your team.
4. **Include a concrete example.** Reference a real SEV, a real metric, a real failure.
5. **Exit criteria must be verifiable.** "Agent triages SEV to component in <2 min" is verifiable. "Improve reliability" is not.

## Conversation-to-Task Flow

When Denny discusses a problem in free chat, follow this decision tree:

```
Problem discussed in chat
  → Quick fix (< 5 min, no tracking needed)? → Just do it.
  → Non-trivial? → Track it:
      1. Capture: problem, goal, plan, execution steps
      2. Find project: search ~/work/claude/projects/ for matching project
         → Found? → Add task to that project's TASKS.md
         → Not found? → ALERT Denny: "No matching project for X — create new or file under existing?"
      3. Needs collaboration or sizable? → Also create a Meta Task (`meta tasks.*` CLI (or `/tasks` skill) create)
         → Diffs from this work MUST include Tasks: T<number> in commit message
      4. Small, solo work? → Project TASKS.md only, no Meta Task needed
```

**What "non-trivial" means** — if any of these are true, track it:
- Requires more than one session to complete
- Involves code changes across multiple files
- Needs input from another person
- Has a deadline or priority implication
- Could be forgotten if not written down

**Task structure in TASKS.md** — every tracked task needs these fields:

```markdown
### Task title
- **Problem**: What's broken or missing (concrete, with evidence)
- **Goal**: What success looks like (measurable)
- **Plan**: Steps to get there (ordered)
- **Status**: NOT STARTED / IN PROGRESS / BLOCKED / DONE
- **Meta Task**: T<number> (if created) or "none — solo work"
```

## Task Hygiene

### When to Create a Task

| Situation | Project TASKS.md? | Also Meta Task? |
|-----------|-------------------|-----------------|
| Multi-diff project with partner dependencies | Yes | Yes — cross-team coordination |
| Sizable solo work (>1 session) | Yes | No — unless it needs visibility |
| Work needing colleague collaboration | Yes | Yes — shared tracking |
| Single diff, self-contained | No — diff is the tracking unit | No |
| SEV follow-up action | Yes | Yes — link to SEV |
| Recurring operational item | Yes | Depends on scope |
| One-time investigation | No — unless findings need follow-up | No |

### Task Fields Checklist

Before sharing a task with partners, verify:

- [ ] **Title**: Action-oriented, under 80 chars ("Add monitoring for tier-1 models" not "Monitoring work")
- [ ] **Priority**: Set based on blast radius, not effort
- [ ] **Owner**: Single person, not a team
- [ ] **Description**: Problem → Proposal → Exit criteria (see structure above)
- [ ] **Tags**: Team tag (e.g., `mrs-reliability`), SEV tag if applicable
- [ ] **Linked diffs**: All related diffs in the Tasks field or description

### Closing Tasks

Never close a task without:
1. **Stating what landed** — diff number(s)
2. **Stating measured impact** — what changed, before/after
3. **Confirming exit criteria met** — point to evidence

Bad: "Done, landed the diff."
Good: "Landed D96084025. 65 tier-1 models now validated on conf build. Before: no enforcement, S630911 went undetected. After: conf build fails on unmonitored tier-1 models."

## Project-Level Task Tracking

For multi-task projects, keep a `TASKS.md` in the project directory (e.g., `projects/mrs-ml-reliability/TASKS.md`). This is the source of truth — Meta Tasks are the communication layer.

| Layer | Purpose | Tool |
|-------|---------|------|
| `TASKS.md` | Full context, design notes, exit criteria | Local file |
| Meta Tasks | Partner visibility, status tracking, PSC evidence | `meta tasks.*` CLI (or `/tasks` skill) |
| Diffs | Actual code changes | jf submit |

Keep them in sync: when `TASKS.md` changes status, update the Meta Task. When a diff lands, update both.

## See Also

- `cheatsheets/diff/common.md` — diff workflows, commit message format, pre-submit checklist
- `cheatsheets/system/task-execution.md` — executing multi-step tasks reliably

_Last updated: 2026-06-08. Maintainer: dennyzhang._
