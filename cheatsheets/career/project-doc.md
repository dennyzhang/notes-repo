# Project Doc Cheatsheet

<!-- Last updated: 2026-05-12 -->

Quick reference for Google Doc sync with project files. Covers linking, pushing, pulling, and comment handling.

## Hard Rules

These rules are non-negotiable. Every push, pull, and comment operation must follow them.

### Rule 1: Never delete a Google Doc — only replace content

When pushing local changes to a Google Doc, use clear-body + insert-markdown on the **existing** doc. Never delete and recreate. Deleting destroys the doc ID, sharing permissions, comment history, and bookmarks.

### Rule 2: Preserve open Google Doc comments

### Rule 3: Research docs must lead with hard problems

Every research doc must open with 3-5 **hard problems** before presenting solutions. Each problem must have: (1) what makes it genuinely difficult, (2) the approach taken, (3) the trade-off/gap that remains. Don't repeat the same information at different detail levels (e.g., a "DERP Applied" section that restates the hard problems table). If a section doesn't add new information beyond what the hard problems already cover, cut it. (Learned 2026-04-06: DERP section in reliability moat doc was redundant with hard problems table)

Before any push, check for unresolved comments. If comments exist:
1. Pull and address the feedback first (update local file)
2. Reply to each comment with action taken
3. **Ask Denny to resolve the comments** — Claude must NOT resolve Google Doc comments (CLAUDE.md rule). Use `google-mux api call POST` to Drive replies endpoint if needed for replies, but resolution is Denny's job.
4. Only push after Denny confirms comments are resolved

The clear-and-insert push workflow destroys comments. Never push over unresolved comments. If comments can't be resolved yet, skip the push and tell Denny.

### Rule 3: Regular comment pull cycle with clear attribution

Regularly pull open Google Doc comments and act on them. When replying:
- Claude replies: prefix with `[Claude]` — e.g., `"[Claude] Updated T12 status to DONE"`
- Human comments: no prefix (these are from Denny)

This makes it clear which feedback is from AI and which is from the human, since the Google Docs API authenticates as the same user for both.

## PROJECT-DOC.md Structure

Every project gets a `PROJECT-DOC.md` — the curated summary that syncs to Google Docs. Auto-generated from DISCOVERY.md + TASKS.md + CHECKPOINT.md.

### Template

```markdown
# <Project Name> — Project Doc

**Phase**: <current phase from META.yaml>
**Owner**: <owner>
**Last updated**: <date>

## Goals and Achievements

### Goals
- <from DISCOVERY.md "Goal" and "Done looks like">

### Achievements
- <1-3 sentence summary of key progress and impact so far>
- Completed tasks:
  - <key DONE tasks supporting the progress above>

## Major Open Tasks (top 10)

| # | Task | Phase | Status |
|---|------|-------|--------|
| <IN PROGRESS tasks first, then highest-impact TODO> |

## Tasks by Phase

### <Phase Name> (<X total> — <Y done>, <Z open>)
| ID | Task | Status |
|---|------|--------|
| <for large projects (>20 tasks): show counts + top 5 per phase> |
| <for small projects (<20 tasks): show all> |
```

### Generation rules

1. **Goals**: Pull from DISCOVERY.md "Goal" and "Done looks like" sections
2. **Achievements**: Scan TASKS.md for DONE/COMPLETE tasks + WORKLOG.md milestones
3. **Top 10 selection**: IN PROGRESS first, then TODO tasks by phase order (earlier phases first)
4. **Tasks by phase**: For projects with >20 tasks per phase, show count summary + top 5. For smaller projects, show all tasks.
5. **File name**: `PROJECT-DOC.md` in each project directory
6. **Google Doc sync target**: Sync PROJECT-DOC.md instead of raw TASKS.md

## Linked Docs

| Project | Doc ID | Local File |
|---------|--------|------------|
| ai-era-playbook-private | `12UN31uQaC3WpwcE622UzFSd6dCdcBs4hsuCceedWK0Q` | `projects/ai-era-playbook-private/PROJECT-DOC.md` |
| mrs-ml-training-reliability | `1LoPGTh0fkqpt__nPO0wpO3epzdY2PJPUpzsEtIC83yg` | `projects/mrs-ml-training-reliability/PROJECT-DOC.md` |
| technical-selling-skills | `120bYObQryYOFHvRgupYoJUe4LIgFvURTDGRVZuzscGE` | `projects/technical-selling-skills/PROJECT-DOC.md` |
| claude-auto-learn-framework | `123IRKaB01Kn-CM0fzbeeNrSEsFi81X2WXEpOCmslU-M` | `projects/claude-auto-learn-framework/SUBMISSION-DRAFT.md` |

## Push (Local to Google Doc)

Use `/my-gdoc push <file>` to push a specific file.

### Push workflow (replace content in existing doc)

```bash
# 1. Check for unresolved comments — MUST do this first (Rule 2)
gdocs comments list <DOC_ID> --json

# 2. If unresolved comments exist: address, reply, resolve each one

# 3. Get current doc length
gdocs content get-structure <DOC_ID> --json

# 4. Clear body (endIndex from step 3, minus 1)
gdocs batch-update <DOC_ID> --data '[{"deleteContentRange": {"range": {"startIndex": 1, "endIndex": <END-1>}}}]'

# 5. Insert updated markdown
gdocs content insert-markdown <DOC_ID> @<LOCAL_FILE> --index 1
```

## Pull (Google Doc to Local)

Use `/my-gdoc pull <file>` or pull all with `/my-gdoc pull`.

## Comment Workflow

### Pull and process comments

```bash
# List all comments
gdocs comments list <DOC_ID> --json

# For each unresolved comment:
# 1. Read the feedback
# 2. Update the local file accordingly
# 3. Reply with [Claude] prefix
gdocs comments reply <DOC_ID> <COMMENT_ID> "[Claude] <what was done>"

# 4. Ask Denny to resolve — Claude must NOT resolve comments (CLAUDE.md rule)
```

### Comment attribution

| Source | Format | Example |
|--------|--------|---------|
| Human (Denny) | No prefix | "Move T5 to phase 2" |
| AI (Claude) | `[Claude]` prefix | "[Claude] Done — T5 moved to Planning phase" |

## Link a New Doc

Use `/my-gdoc link <file>` to create a new Google Doc from a local file, or `/my-gdoc link <file> <url>` to link to an existing doc.

### Manual linking

```bash
# Create doc from local file
gdocs create "<TITLE>" --from <LOCAL_FILE> --json

# Move doc to the SAME Drive folder as the source markdown file.
# Look up the folder ID by listing the parent directory in Drive.
gdocs move <DOC_ID> <PARENT_FOLDER_ID> --json
```

### Folder placement rule

Place the Google Doc in the appropriate Google Drive folder. Use `gdocs list <PARENT_FOLDER_ID>` or the Drive UI to find the correct folder ID.

Do NOT dump all docs into the repo top-level folder.

## Common Pitfalls

- **One doc per project**: Keep one Google Doc per project. Don't create separate docs for the same file.
- **Doc naming**: Use `<PROJECT-SLUG>-TASKS` format (e.g., `MRS-INFRA-RELIABILITY-TASKS`).

## Design Doc Structure Rules

| Rule | Why |
|------|-----|
| **Every design doc must have a Key Decisions section** | Tracks architectural decisions with date, decision, and rationale. Prevents future sessions from re-deciding settled questions. Decisions made through doc comments should be captured here permanently. (Learned 2026-03-31: autolearn doc) |
| **Every design doc must have a clear Interface section** | Shows where to find key artifacts: logs, configs, dashboards, changelogs, audit trails. Don't make readers hunt for the interface. If the system produces observable outputs, the doc must say where they live. (Learned 2026-03-31: autolearn doc) |
| **Success criteria go at the top** | Success criteria guide improvement and solutions — they must be visible before the reader gets into details. Place them immediately after the problem statement, before architecture or implementation sections. (Learned 2026-03-31: ally-building doc) |
