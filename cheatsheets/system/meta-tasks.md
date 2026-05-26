# Meta Tasks Cheatsheet

Quick reference for creating, updating, and tracking Meta Tasks. Covers the `meta` CLI (primary), the `/tasks` skill, and diff-to-task linking.

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
meta tasks.task update --number=T259215482 --progress=IN_PROGRESS --priority=HIGH
meta tasks.task update --number=T259215482 --description="Updated description"

# Add a comment (NOT meta tasks.task update --comment)
meta tasks.comment create --task=T259215482 --text="Progress note"

# Update + comment in one call
meta tasks.task update --number=T259215482 --comment="Progress note" --progress=IN_PROGRESS

# Close a task
meta tasks.task update --number=T259215482 --close --comment="Landed D96084025"

# Reopen a task
meta tasks.task update --number=T259215482 --reopen --progress=IN_PROGRESS

# Link/unlink diffs
meta tasks.task update --number=T259215482 --add-diff=D67890
meta tasks.task update --number=T259215482 --remove-diff=D67890

# Add/remove tags
meta tasks.task update --number=T259215482 --add-tag=mrs-reliability
meta tasks.task update --number=T259215482 --remove-tag=old_tag

# Add subscriber
meta tasks.task update --number=T259215482 --subscriber=username

# Set dates
meta tasks.task create --title="Task" --target-date=2025-06-30
meta tasks.task update --number=T259215482 --target-date=2025-06-30

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
| `--task-id T123` | `--number=T123` or `--task=T123` | `task update` uses `--number`, `comment create` uses `--task` |
| `meta tasks.task show T123` | Use `knowledge_load` MCP with task URL | No `show` subcommand on `meta tasks.task` |
| `meta tasks.task.tag add --task=T123 --tag=X` | `meta tasks.task update --number=T123 --add-tag=X` | `tasks.task.tag add` is deprecated (learned 2026-04-28) |
| `meta google.docs.comment add --doc=... --untrusted-authors-mode=...` | drop the `--untrusted-authors-mode` flag entirely | The flag is not accepted by `comment add`; works without it (learned 2026-04-28) |

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
