# Proposal: Shared Claude Context for MRS ML Team

*Authors: Denny Zhang, Co-author | Date: 2026-03-10 | Status: Draft for TL Review*

## Problem

When an engineer from Training covers an Inference oncall issue, they start from zero. When someone discovers that a specific model fails silently with batch size > 512 on A100s, that lesson stays in their head. When a new team member debugs their first OT failure, they can't benefit from the patterns the team has already seen.

Two gaps hurt us most:

1. **Cross-pod support is harder than it should be.** Training and Inference pods hit overlapping issues — MAST scheduling, FARM quota, SEV triage, diff workflow. But each pod's debugging knowledge lives in individual heads. A Training engineer covering Inference oncall has no access to Inference-specific patterns, and vice versa.
2. **Team members don't learn from each other's work.** When one engineer figures out a tricky system behavior or a non-obvious debugging shortcut, that knowledge stays local. There's no mechanism for one person's hard-won lesson to benefit the next person who hits the same problem.

Multiple Meta teams (Ads PE Model Training, MVAI, and others) have addressed this by maintaining shared Claude Code context in the notes repo. We should do the same — but learn from what's already been tried.

## Proposal

Populate [`notes/shared/pe_mrsml/`](https://www.internalfb.com/code/notes/shared/pe_mrsml/) with a substantive [CLAUDE.md](https://www.internalfb.com/code/notes/shared/pe_mrsml/CLAUDE.md) that serves as a **routing layer** — mapping tasks to the right pod-specific skills and reference files. The CLAUDE.md itself stays lean: team identity, pod routing rules, and shared conventions. Detailed knowledge lives in pod-level skill files.

## What It Looks Like

```
~/notes/shared/pe_mrsml/
  CLAUDE.md          # Router: team identity, pod routing rules, shared conventions
  README.md          # Setup guide (2 commands)
  docs/              # Existing H1 planning docs (already here)
    2026H1_roadmap_overview.md
    2026H1_tracks_metrics.md
    2026H1_okrs.md
    2026H1_oncall_allocation_partners.md
    2026H1_investment_areas.md
    2026H1_h2_highlights.md
    2026H1_risks_mitigations.md
  training/          # Training pod skills (future)
  inference/         # Inference pod skills (future)
  reliability/       # Reliability pod skills (future)
```

A team member runs `cd ~/notes/shared/pe_mrsml && claude` and gets a session that routes to the right knowledge based on the task at hand.

**Why a router, not a monolith:** Our team has 14+ engineers across distinct pods. A monolithic CLAUDE.md that tries to hold all knowledge becomes unmaintainable. Instead, the root file routes to pod-specific skills where detailed knowledge lives. Each pod owns their own skill files — maintaining what they know best.

## What Goes in CLAUDE.md

The root CLAUDE.md has two jobs: (1) identify which pod/track a task belongs to, and (2) route to the right skill files and reference docs.

**Routing rules:**

| Task Domain | Route To | Reference Docs |
|-------------|----------|----------------|
| Online Training (OT) reliability, model staleness, ATS | Training pod skills | docs/2026H1_tracks_metrics.md (MOTR section) |
| Trunk health, release, model code age | Training pod skills | docs/2026H1_tracks_metrics.md (THnR section) |
| MVAI platform reliability, MLU, ETT | Training pod skills | docs/2026H1_tracks_metrics.md (MVAI section) |
| Agent for model iterations, MVAI agent | Training pod skills | docs/2026H1_tracks_metrics.md (AI4P section) |
| Model quality validation (UMQV), checkpoint validation | Inference pod skills | docs/2026H1_tracks_metrics.md (UMQV section) |
| Model inference reliability, serving SEVs | Inference pod skills | docs/2026H1_tracks_metrics.md (MIR section) |
| NRTU, new region turn-up | Inference pod skills | docs/2026H1_tracks_metrics.md (MIR section) |
| SLO definitions, MGS, TSD metrics | Reliability pod skills | docs/2026H1_tracks_metrics.md |
| SEV triage, oncall, incident response | Oncall playbook | docs/2026H1_oncall_allocation_partners.md |
| Half planning, OKRs, investment areas | Reference only | docs/2026H1_roadmap_overview.md, docs/2026H1_okrs.md |

**Shared conventions** (applies to all pods):

| Section | Content |
|---------|---------|
| Team identity | Who we are, what we own, pod structure |
| Coding conventions | Buck2, lint/Pyre, diff workflow rules that apply team-wide |
| Guardrails | What Claude should never do (comment on diffs, publish without ask) |

**What belongs in pod skill files (not in root CLAUDE.md):**

| Category | Example of GOOD content | Example of BAD content |
|----------|------------------------|----------------------|
| Debugging patterns | "Model X delta publish fails silently when embedding dim changes — check TorchArrow schema compatibility first" | "Check logs when a job fails" |
| System quirks | "MAST jobs on tenant Y have a 10-min scheduling delay after midnight PST due to quota rebalancing" | "MAST schedules jobs" |
| Incident patterns | "S608921: ATS spike caused by task naming collision in OT pipeline — fix was deduplicating task IDs" | "SEVs can happen" |
| Tool shortcuts | "Use `buck2 uquery 'deps(//target)' --output-attribute=srcs` to find all source files for a target" | "Use Buck2 to build" |

## How Content Gets Organized

The root CLAUDE.md is primarily a **mapping and rules** file. It stays stable — routing rules don't change weekly. The dynamic, evolving knowledge lives in pod-specific skill files, where domain experts maintain it.

**Pod skill files** get updated through existing events:

| Trigger | Who Updates | Where It Goes |
|---------|-------------|---------------|
| SEV post-mortem completed | Oncall engineer | Pod-specific skill file (debugging patterns) |
| New model onboarded to OT | Training engineer | Training pod skill file |
| Debugging session discovers non-obvious pattern | Any engineer | Relevant pod skill file |
| New engineer asks a question that took >30 min to answer | Whoever answered | Relevant pod skill file |

**Enforcement mechanism:** Add "Update shared Claude context if applicable" as a checkbox on the SEV post-mortem template. This ties the update to an existing process rather than creating a new one.

## How We Know It Worked

Vague adoption goals ("3+ people use it") are unfalsifiable. Concrete test:

**Pilot test (2 weeks):**

1. Pick one engineer about to do their first cross-pod oncall rotation
2. Give them the shared context before their shift
3. After their shift, ask: "Did the context help you resolve or triage anything faster? What was missing?"

**Success metric:** The engineer identifies at least one incident where the shared context saved them time, AND contributes at least one new pattern back.

**Failure metric:** The engineer didn't open it, or opened it and found nothing useful. If this happens, the content isn't good enough — fix the content, don't blame adoption.

## Questions for Discussion

### 1. What are the rules and expectations for this team shared Claude context?

We need clear guidelines for what goes in the root CLAUDE.md vs. pod skill files, who can edit what, and what the review process is (if any).

*My position:* Root CLAUDE.md changes require TL review (since routing affects everyone). Pod skill files are owned by pod TLs — they can update without cross-pod review. No stale content reviews — content earns its place through usage.

### 2. Who seeds the initial content?

This is the real blocker. Populating content requires someone to build the routing rules and create initial pod skill files.

*My position:* Each TL contributes 2-3 entries from their pod's recent incidents. That's 30 minutes of work each, and it produces content that's immediately useful. The alternative — asking a volunteer to interview everyone — will take weeks and produce generic summaries.

### 3. What stays out? (Stage 2)

The notes repo is readable by anyone at Meta. Some team knowledge (partner dynamics, strategy, people context) needs a private surface. One approach is mounting Google Drive for private context.

*My position:* Stage 1 is strictly technical — routing rules, debugging patterns, coding conventions. Stage 2 can explore private context via Google Drive mounting or personal directories. Don't let the privacy question block the technical content.

## Action Items

| # | Action | Owner | Target Date |
|---|--------|-------|-------------|
| 1 | TLs review this proposal, answer the discussion questions | Peer TLs | 2026-03-19 |
| 2 | Each TL contributes 2-3 debugging patterns from recent incidents to seed pod skill files | All TLs | 2026-03-24 |
| 3 | Populate pe_mrsml/CLAUDE.md with routing rules and shared conventions | Denny | 2026-03-26 |
| 4 | Pilot: one engineer uses shared context during cross-pod oncall, reports back | TBD | 2026-04-07 |
| 5 | Decide: continue, expand, or stop based on pilot feedback | Co-author | 2026-04-14 |

## References

- Ads PE Model Training Team Runbook: [wiki](https://www.internalfb.com/wiki/Ads_PE/Ranking/Ads_ML_PE%3A_Model_Training/Team_Runbook/) — Subteam directories, persistent storage, clear setup guide.
- MVAI shared folder: [notes repo](https://www.internalfb.com/code/notes/shared/mvai/) — Simpler structure with docs, oncall, and project-specific directories.
- Notes Repo Wiki: [setup guide](https://www.internalfb.com/wiki/Source-Control-Users/Notes_Repo:_AI_Agent_Context_Management/) — Official guide for using notes repo with Claude Code.
- Existing pe_mrsml folder: [notes repo](https://www.internalfb.com/code/notes/shared/pe_mrsml/) — Current folder with H1 planning docs.
