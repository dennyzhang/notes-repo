# Cheatsheet Routing Index

Load the matching cheatsheet before starting a task. Larger folders also carry a folder `INDEX.md` for lazy loading — read it first, then load only the specific file you need.

## Categories

| Category | Folder | Files | Load When |
|----------|--------|-------|-----------|
| **Code & Diffs** | `diff/` | 13 | Any diff operation, code review |
| **Google Docs** | `gdocs/` | 2 | Any gdocs CLI operation |
| **Oncall & Reliability** | `oncall/` | 16 | SEV, SEV-gchat catch-up, oncall, MAST debugging, design review, handoff, shift summary, customer support, triage methodology, issue report, bot reply format, escalation, SEV follow-up diffs, reliability practices, templates, metrics |
| **Comms** | `comms/` | 3 | GChat operations (send/read/thread), message tone coaching, paste formatting |
| **Career & Impact** | `career/` | 17 | PSC, SLO, project docs, impact, communication, capacity, roadmap, knowledge sharing, launch/sharing posts, slides, impact metrics, four axes, level expectations |
| **Research & Thinking** | `research/` | 3 | Deep research (+ scoring rubric), doc analysis |
| **Agents & Automation** | `agents/` | 11 | Building & running AI agents/automations: agent design, AI failure modes, workflow/cron design, autonomous principles, auto-save learnings, cheatsheet flywheel, agent evals, MyClaw ops/delete |
| **System** | `system/` | 4 | Harness wiring & execution: architecture map, sync rules, task-execution discipline, Meta Task CLI |
| **Calendar & Meetings** | `calendar/` | 1 | Creating meetings, attaching VC (Zoom / Google Meet), `create-meeting.py` workarounds |
| **Notes Repo Ops** | `notes-repo-operations.md` (top-level) | 1 | Any `sl` operation in `~/notes`: commit/push/pull/rebase, divergence recovery, file recovery. ALWAYS load before push-divergence troubleshooting (7 file-tracking casualties 2026-05-16 prove this is high-friction). |


## Quick Routing

| Task | Load |
|------|------|
| Diff operations | `diff/common.md` + repo-specific (`diff/fbcode.md`, `diff/configerator.md`, `diff/www.md`) |
| Diff can't land / LAND_RECENTLY_FAILED | `diff/common.md` § Diff Can't Land — Diagnosis Checklist |
| Optimizing a diff for RADAR auto-stamp (zero human review) | `diff/radar-autostamp.md` |
| "Why does this diff rule exist?" / pattern research / dated D-numbered evidence | `diff/diff-learnings-log.md` |
| Diff review | `diff/review.md` |
| Google Docs operations | `gdocs/rules.md` |
| Diagrams/images in docs (readability gate, sizing, gdoc insert) | `gdocs/diagrams-images.md` |
| Infra reliability practices (agent guardrails, SLI gates, change safety, risk-weighted review) | `oncall/infra-reliability-practices.md` |
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
| Building a slide deck / presentation | `career/slides.md` |
| Deep research | `research/deep-research.md` |
| Doc analysis, document review | `research/doc-analysis.md` |
| Building agent evals (replay-eval, scoring harness) | `agents/building-agent-evals.md` |
| Building workflows, hooks, cron | `agents/workflow-design.md` |
| Meta Tasks: create, update, link | `system/meta-tasks.md` |
| Task execution discipline, multi-step | `system/task-execution.md` |
| Touching `.gitattributes`, `git-review.sh`, hooks, HANDOFF, or any paired state file | `system/sync-rules.md` |
| Recurring AI mistakes (load before non-trivial work) | `agents/ai-failure-modes.md` |
| Designing prompts, classifiers, hooks, or any agent automation (Marty Dumaual research synthesis) | `agents/agent-pressure.md` |
| Coaching the operator to give better/higher-leverage prompts | `agents/prompt-coaching.md` |
| Giving AI feedback that sticks — rule format, anti-patterns, when to codify | `agents/giving-ai-feedback.md` |
| Deleting a MyClaw instance | `agents/myclaw-delete.md` |
| Autonomous agent design principles (output density, correctness, safety) | `agents/autonomous-workflow-principles.md` |
| Closing a topic / thread — save & route session learnings to cheatsheets | `agents/auto-save-learnings.md` |
| Creating a meeting (with Zoom + AI meeting notes — boss's default), or fixing a meeting missing AI summary | `calendar/google-meet.md` |
| OT customer support, Workplace post responses | `oncall/customer-support.md` |
| Triage quality rules (R1-R13), per-fact tagging, cluster discipline | `oncall/triage-methodology.md` |
| **Bot reply draft formatting** (triage, SEV, DM to owner) | `oncall/bot-reply-format.md` |
| One-pager, pitch | Use `10x-engineer:one-pager` skill |

Deep/overflow reference files live in their domain folder alongside the core cheatsheet (e.g. `diff/diff-summary-writing.md`, `career/impact-metrics.md`, `oncall/oncall-templates.md`) — load them on demand.

## Conventions

- **Folder naming**: lowercase, matches the category
- **File naming**: lowercase with hyphens, no `cheatsheet-` prefix inside folders
- **Size cap**: 800 lines per file. Overflow splits into a deep/reference file **in the same domain folder** (e.g. `diff/diff-common-gotchas.md`), not a separate `references/` tier.
- **One folder per domain, no overlap**: each folder is a distinct activity (diff, oncall, career, comms, research, gdocs, calendar, agents, system). A file lives with the domain that consumes it — there is no cross-cutting "tier" folder.
- **Lazy loading**: Larger folders (`diff/`, `oncall/`, `career/`, `agents/`, `system/`) carry a folder `INDEX.md` — read it first, then load only the specific file. Policy: a folder with ≥4 files should have an `INDEX.md`. Smaller folders route directly via this central index.
- **New cheatsheet**: Drop it in the matching folder. If no folder matches, create one. Add a `_Last updated: YYYY-MM-DD. Maintainer: <unixname>._` footer and a routing-table row here (or in the folder INDEX) — otherwise the health-check flags it.
- **Health-check**: `bash ~/notes/users/dennyzhang/scripts/lint/lint-cheatsheets.sh` audits size cap, provenance footers, broken links, and orphans. Run before pushing cheatsheet changes; `--stamp` emits real-date footers for files missing one.
