# Cheatsheet Routing Index

Load the matching cheatsheet before starting a task. Each category has a folder with an INDEX.md for lazy loading — read the folder INDEX first, then load only the specific file you need.

## Categories

| Category | Folder | Files | Load When |
|----------|--------|-------|-----------|
| **Code & Diffs** | `diff/` | 5 | Any diff operation, code review |
| **Google Docs** | `gdocs/` | 1 | Any gdocs CLI operation |
| **Oncall & Reliability** | `oncall/` | 9 | SEV, SEV-gchat catch-up, oncall, MAST debugging, design review, handoff, shift summary, customer support, triage methodology |
| **Comms** | `comms/` | 3 | GChat operations (send/read/thread), message tone coaching, paste formatting |
| **Career & Impact** | `career/` | 10 | PSC, SLO, project docs, impact, communication, capacity, roadmap, knowledge sharing, launch posts, sharing posts |
| **Research & Thinking** | `research/` | 2 | Deep research, doc analysis, initiatives |
| **System & Automation** | `system/` | 7 | Hooks, cron, workflows, Meta Tasks, task execution, sync rules, AI failure modes, agent pressure, MyClaw deletion |
| **Calendar & Meetings** | `calendar/` | 1 | Creating meetings, attaching VC (Zoom / Google Meet), `create-meeting.py` workarounds |
| **Notes Repo Ops** | `notes-repo-operations.md` (top-level) | 1 | Any `sl` operation in `~/notes`: commit/push/pull/rebase, divergence recovery, file recovery. ALWAYS load before push-divergence troubleshooting (7 file-tracking casualties 2026-05-16 prove this is high-friction). |


## Quick Routing

| Task | Load |
|------|------|
| Diff operations | `diff/common.md` + repo-specific (`diff/fbcode.md`, `diff/configerator.md`, `diff/www.md`) |
| Diff can't land / LAND_RECENTLY_FAILED | `diff/common.md` § Diff Can't Land — Diagnosis Checklist |
| Diff review | `diff/review.md` |
| Google Docs operations | `gdocs/rules.md` |
| SEV response | `oncall/sev.md` |
| Joining a SEV gchat mid-flight — catch-up reading method | `oncall/sev-gchat-catchup.md` |
| Issue report, XFN post, user group post, paste about a finding, cross-team write-up, document a recurring issue | `oncall/issue-report.md` + `comms/paste-formatting.md` (always co-load) |
| Weekly shift summary, oncall report, end-of-shift post, shift doc review | `oncall/shift-summary.md` + `gdocs/rules.md` (always co-load for doc edits) |
| Oncall assessment | `oncall/assessment.md` |
| MAST job debugging | `oncall/mast-debugging.md` |
| Design doc / RFC review | `oncall/design-review.md` |
| Oncall rotation handoff | `oncall/handoff.md` |
| GChat operations (send/read/thread reply) | `comms/gchat.md` |
| GChat message coaching, recipient playbook | `comms/gchat-coaching.md` |
| Paste formatting (pastry, plaintext surfaces) | `comms/paste-formatting.md` |
| PSC, self-review | `career/psc.md` |
| Quantifying impact | `career/impact-quantifier.md` |
| SLO definition | `career/slo.md` |
| Project docs | `career/project-doc.md` |
| 1:1 prep, cross-team asks, feedback | `career/communication.md` |
| Capacity planning, GPU sizing | `career/capacity.md` |
| Half roadmap planning | `career/roadmap.md` |
| Knowledge sharing, tech talks | `career/knowledge-sharing.md` |
| Launch posts, Workplace announcements | `career/launch-post.md` |
| Sharing posts, team updates | `career/sharing-post.md` |
| Deep research | `research/deep-research.md` |
| Doc analysis, document review | `research/doc-analysis.md` |
| Building workflows, hooks, cron | `system/workflow-design.md` |
| Meta Tasks: create, update, link | `system/meta-tasks.md` |
| Task execution discipline, multi-step | `system/task-execution.md` |
| Touching `.gitattributes`, `git-review.sh`, hooks, HANDOFF, or any paired state file | `system/sync-rules.md` |
| Recurring AI mistakes (load before non-trivial work) | `system/ai-failure-modes.md` |
| Designing prompts, classifiers, hooks, or any agent automation (Marty Dumaual research synthesis) | `system/agent-pressure.md` |
| Deleting a MyClaw instance | `system/myclaw-delete.md` |
| Creating a meeting (with Zoom + AI meeting notes — boss's default), or fixing a meeting missing AI summary | `calendar/google-meet.md` |
| OT customer support, Workplace post responses | `oncall/customer-support.md` |
| Triage quality rules (R1-R13), per-fact tagging, cluster discipline | `oncall/triage-methodology.md` |
| **Bot reply draft formatting** (triage, SEV, DM to owner) | `oncall/bot-reply-format.md` |
| One-pager, pitch | Use `10x-engineer:one-pager` skill |

Shared deep references live in `references/`.

## Conventions

- **Folder naming**: lowercase, matches the category
- **File naming**: lowercase with hyphens, no `cheatsheet-` prefix inside folders
- **Size cap**: 500 lines per file. Overflow goes to `references/`
- **Lazy loading**: Read folder `INDEX.md` first (10 lines), then load only the specific file needed
- **New cheatsheet**: Drop it in the matching folder. If no folder matches, create one.
