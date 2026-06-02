# Deep Research Cheatsheet

Research methodology for understanding unfamiliar topics — company initiatives, org projects, strategy shifts, buzzwords, or any concept you've heard but don't fully grasp.

## Source Matrix

Search all sources in parallel. Each surface catches different signal.

| Source | Tool | Search Parameters | Catches |
|--------|------|-------------------|---------|
| Workplace group posts | `knowledge_filtered_search` | `doc_types: ["GROUP_POST"]`, keywords | Announcements, leadership framing, team discussions, reactions |
| Wiki pages | `knowledge_filtered_search` | `doc_types: ["WIKI_PAGE"]`, keywords | Official definitions, specs, onboarding docs |
| Static docs | `knowledge_filtered_search` | `doc_types: ["STATIC_DOCS"]`, keywords | Engineering guides, technical specs, API docs |
| Google Docs | `knowledge_filtered_search` | `doc_types: ["GOOGLE_DOCUMENT"]`, keywords | Strategy docs, proposals, design docs, planning docs |
| Meeting notes | `knowledge_filtered_search` | `doc_types: ["MEETING_NOTE"]`, keywords | All-hands takeaways, decisions, context |
| Tasks | `knowledge_filtered_search` | `doc_types: ["TASK"]`, keywords | Execution plans, timelines, ownership |
| External web | `three_pai_external_web_search` | natural language query | Public blog posts, press coverage, industry context |

For high-signal results, load full content with `knowledge_load(url: "<URL>")`.

## Synthesis Template

After collecting results from all sources, synthesize into this structure:

```markdown
# Research: [Topic Name]
**Date**: YYYY-MM-DD | **Sources searched**: [N] | **Documents loaded**: [N]

## What Is It?
## Why Now?
## Key People and Teams
## What It Means for Your Org
## Current State

## Contested Points
[Where sources disagree. Specific examples with source references.
If none found, state: "No contradictions found across N sources —
this may indicate under-exploration of alternative viewpoints."
This section is MANDATORY — it catches harmonization bias.]

## Confidence Map
| Claim | Confidence | Basis |
|-------|-----------|-------|
| [key claim] | VERIFIED | [source URL + specific data point] |
| [key claim] | INFERRED | [reasoning from available data] |
| [key claim] | SPECULATIVE | [single source, or reasoning only] |

## What I Didn't Find
[Topics searched for but couldn't answer. Honest reporting, not failure.
Also: questions the user should ask a human expert about.]

## Recommendations
[Conditional: IF [constraint], THEN [action], BECAUSE [reason].]

## Self-Critique
[3+ attacks. Each: Attack → Validity (VALID/PARTIAL/INVALID) → Mitigation.]

## Related Research
[Other artifacts covering overlapping territory, or "none found."]

## Follow-Up
**Review date**: [2 weeks from creation]
**Review question**: [one question that validates or invalidates findings]
**Action items**:
- [ ] [concrete action 1]
- [ ] [concrete action 2]
**Status**: OPEN

## Sources
| # | Type | Title | Date | URL |
|---|------|-------|------|-----|
| 1 | Workplace post | [title] | YYYY-MM-DD | [link] |
| 2 | Wiki | [title] | YYYY-MM-DD | [link] |
```

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Saving research as local .md only — no Google Doc, no overview table row | ALWAYS create gdoc + add overview table row. Local file alone is invisible to the user for commenting/sharing. (Learned 2026-03-23) |

## Output Location

Save research artifacts to `research-and-rampup-private/RESEARCH-<SLUG>.md`. This is the shared briefings library (research + ramp-ups). If research is project-specific, also cross-link from the project's `TASKS.md`.

## Workflow

### The Full Loop

```
Plan → Queue → Research → Review → Save → Google Doc → Index Table → Remind → Surface
```

1. **Plan**: Produce a research plan with sub-questions covering: definition/scope, ownership, current state, competing views, relevance to your org, and gaps. Generate multi-perspective questions (Builder, Skeptic, User, Measurer — 3 questions each). These become the search queries.
2. **Queue**: User says "research X" or adds a row to INDEX.md with status `queued`
3. **Research**: Background agent runs the full methodology (parallel fan-out, load top hits, synthesize). Must include searches for contrarian viewpoints and failure cases (sub-question 4 from plan). Enforce source diversity: 2+ source types per key claim, else mark SPECULATIVE.
3b. **Cross-finding synthesis**: After collecting findings, analyze interactions — dependency map, compounding effects, root vs symptom, "the one thing." Add as a section before recommendations.
3c. **Conditional recommendations**: Rewrite all recommendations as IF [condition] → THEN [action] → BECAUSE [mechanism], with EVIDENCE and ALTERNATIVE.
4. **Hostile reviewer pass**: Self-critique the draft against 7 dimensions: breadth, depth, source quality, synthesis, contradictions, actionability, confidence. Any dimension below 7/10 → targeted improvement. Cap at 1 critic pass (2+ degrades through over-hedging).
5. **Save locally**: Artifact written to `research-and-rampup-private/RESEARCH-<SLUG>.md` or `projects/<project>/RESEARCH-<SLUG>.md`
6. **Create Google Doc**: `gdocs create "Research: [Topic Name]" --from <artifact.md>`. Then post-creation cleanup: remove `───` separators, set proportional column widths on all tables. **If redoing an existing research topic** (topic already has a Google Doc in INDEX.md): NEVER create a new doc. Instead, push new content into the original doc via `gdocs replace --tab-id t.0 --from <artifact.md> --full-replace-removes-comments`, then re-apply post-creation cleanup. The URL must stay stable. (Learned 2026-04-05: created a new doc instead of reusing the original, breaking existing bookmarks and index links.)
7. **Add to research overview table**: Add a row to the [research overview gdoc](https://docs.google.com/document/d/1T7aiSRJTQMXToSzbnCoikcAczvEGNdm_TmplmHpZfsY/edit). **ALWAYS read the header row first** to confirm column order. Use `batch-update insertTableRow` + `insertText` (reverse index order) + `updateTextStyle` (link on Topic cell). Verify row content after insertion.
8. **Index**: Update `research-and-rampup-private/INDEX.md` — set status to `done`, add one-line summary, and Google Doc URL
9. **Remind**: If async, notify user with both the local path and the Google Doc link
10. **Surface**: On `/my-start`, if a research topic appears in today's calendar meetings, mention it with the Google Doc link

**CRITICAL**: Steps 6-7 are NOT optional. **ANY Google Doc Claude creates** — research, planning, impact plan, proposal, analysis — MUST have a row in the [research overview table](https://docs.google.com/document/d/1T7aiSRJTQMXToSzbnCoikcAczvEGNdm_TmplmHpZfsY/edit). This applies regardless of whether the doc was created via the research workflow, `/my-think`, or any other path. A doc without an overview row is invisible and untracked. (Learned 2026-03-23: H1 Impact Plan created without overview row because enforcement was scoped to "research" only.)

### Google Doc as Collaboration Layer

The markdown file is the source of truth. The Google Doc is the collaboration copy.

- **Pre-flight**: Before any `gdocs` operation, load `cheatsheets/cheatsheet-gdocs.md`. This is a standing rule.
- **Creating**: Use `gdocs create --from <markdown-file>` after research completes. Title format: `Research: [Topic Name]`
- **Sharing**: User adds collaborators directly in Google Docs. Claude never shares docs automatically.
- **Updating**: If research is refreshed or redone, push into the SAME Google Doc — never create a new URL. Use `gdocs replace --tab-id t.0 --from <artifact.md> --full-replace-removes-comments`, then re-apply post-creation cleanup (column widths, header colors). Update INDEX.md content/score but keep the same doc URL.
- **Comments**: User and collaborators comment in Google Doc. Claude reads comments on demand but never resolves them.

## Quality Bar

Scoring rubric (5 dimensions, 0-2 points each, 10 total) is in `references/deep-research-scoring.md`. Load on demand when scoring reports.

**Mandatory quality gates (5 gates — append results as `## Quality Gate` section to every artifact):**

| # | Gate | Pass criteria |
|---|------|---------------|
| 1 | **Sources tagged** | Every factual claim has `[VERIFIED: source]` or `[INFERRED]`. Zero untagged. |
| 2 | **Contradictions surfaced** | "Contested Points" section exists if 2+ sources consulted. If all agree, state explicitly. |
| 3 | **Synthesis + conditional recs** | Cross-cutting analysis answers "which finding makes all others worse?" AND recs are conditional (IF X THEN Y BECAUSE Z). |
| 4 | **Self-critique (3 attacks)** | "Self-Critique" section with 3+ attacks, each VALID/PARTIALLY VALID/INVALID. |
| 5 | **Related research linked** | "Related Research" section lists overlapping artifacts, or "none found." |

**Gate results (append as HTML comment at top of artifact — author audit trail, not reader-visible):**
```markdown
<!-- Quality Gate: Sources=PASS(X verified, Y inferred) | Contradictions=PASS(N points) | Synthesis=PASS | Self-critique=PASS(N attacks) | Related=PASS(N docs) -->
```
If this comment is missing from an artifact, the gates weren't run.

**Follow-up section (mandatory at end of every artifact):**
```markdown
## Follow-Up
**Review date**: [2 weeks from creation]
**Review question**: [one question that validates or invalidates findings]
**Action items**:
- [ ] [concrete action 1]
- [ ] [concrete action 2]
**Status**: OPEN
```

**Iteration protocol (when revisiting existing research):**
When `/my-think` is called on a topic with an existing artifact:
1. Load existing artifact first
2. Check Follow-Up section — action items done? Review date passed?
3. Search for new information since creation date (delta research)
4. Update existing artifact — add `## Revision [date]` section, don't create new doc
5. Update Follow-Up with new review date and revised action items

## Research Library

`research-and-rampup-private/` is the maintained folder (shared with ramp-ups):
- `INDEX.md` — registry of all topics with status, score, one-line summary
- `RESEARCH-<SLUG>.md` — individual research artifacts
- Not synced to notes repo (excluded by rsync). Backed up locally.
- On `/my-start`, if a research topic comes up in today's calendar meetings, surface it.

## Multi-Agent Orchestration (for complex deep dives)

When `/my-think` deep dive triggers on a system-level or initiative-level topic, use phased orchestration instead of flat parallel agents.

### Step 1: Quick reconnaissance (orchestrator, 3-5 tool calls)
Before spawning agents, do a lightweight scan to understand the landscape:
- Run a few targeted searches (fbgs/knowledge_filtered_search)
- Read 1-2 key files to grasp structure
- This informs task design — don't spawn blind

### Step 2: Create phased tasks with dependencies
Use `addBlockedBy` so agents don't deep-dive before the landscape is mapped.

```
Phase 1 (foundation — no dependencies):
  Task #1: "Map directory structure and key entry points"
  Task #2: "Find internal documentation on architecture"

Phase 2 (deep-dive — blocked by Phase 1):
  Task #3: "Investigate subsystem A" (addBlockedBy: [1])
  Task #4: "Investigate subsystem B" (addBlockedBy: [1])
  Task #5: "Investigate subsystem C" (addBlockedBy: [1, 2])

Phase 3 (cross-cutting — blocked by Phase 2):
  Task #6: "Cross-reference patterns across subsystems" (addBlockedBy: [3, 4, 5])
```

Agents automatically respect dependencies — they only pick up tasks whose blockers are complete.

### Step 3: Spawn typed agent pool (all with `run_in_background: true`)
Match agent type to task nature. Spawn all in a single message for parallel launch.

| Task Nature | Agent Type |
|---|---|
| Code exploration, Buck targets, diffs | `meta_codesearch:code_search` |
| Internal docs, wiki, workplace posts | `meta_knowledge:knowledge_search` |
| General-purpose / synthesis | `general-purpose` |

Pool size: 3-5 agents for most research. Up to 8 for very broad topics. Hard cap: 10.

### Step 4: Active orchestration (steer the team, don't be passive)

| Trigger | Action |
|---|---|
| Agent A reports finding relevant to Agent B | **Cross-pollinate**: forward key context to B |
| Phase 1 tasks complete | **Unblock**: summarize Phase 1 findings for Phase 2 agents |
| Early finding changes the landscape | **Redirect**: message affected agents with new direction |
| Agent appears stuck | **Check in**: ask for status, suggest alternative approach |
| Finding contradicts another thread | **Cross-reference**: message both agents to reconcile |
| Dead-end thread | **Reassign**: redirect agent to a new or replacement task |

### Step 5: Synthesis agent (for 8+ task research)
Spawn a dedicated synthesis agent instead of synthesizing in the main thread:
- Reads all completed tasks via TaskList/TaskGet
- Integrates findings, identifies consensus and conflicts
- Produces the final artifact
- Keeps the orchestrator's context clean

### When to use phased vs flat orchestration
- **Use phased** when findings from one task are prerequisites for another (most system-level dives)
- **Use flat** when threads are genuinely independent (most initiative-level research)
- **Mix both** for depth-first queries: flat within a phase, dependencies between phases

## Common Mistakes

Specific errors from the research quality audit (2026-03-29, 10 docs scored).

| What happened | Correct approach |
|---|---|
| 8 of 10 docs harmonized all sources into one clean narrative, hiding disagreements | ALWAYS include Contradictions section. If sources genuinely agree, state so explicitly — don't just skip it. |
| 9 of 10 docs had no review date or follow-up mechanism — findings went stale | ALWAYS end with Follow-Up: review date (2 weeks), review question, action items, status. |
| 7 of 10 docs presented findings as fact with no "here's where I might be wrong" | ALWAYS include 3+ self-attacks before delivery. Each labeled VALID/PARTIALLY VALID/INVALID. |
| IC7 doc had 58 lines of claims with 0 source citations | EVERY factual claim gets `[VERIFIED: source]` or `[INFERRED: reasoning]`. Zero tolerance for untagged claims. |
| 4 OT-related docs (Model Freshness, OT Reliability, SilverTorch, MRS Infra) covered the same pipeline but never referenced each other | ALWAYS add "Related Research" section listing overlapping artifacts. Build the knowledge graph. |
| Research quality improvements identified on Mar 22 were only applied in 1 of 7 subsequent docs | Quality gates must be in the TEMPLATE, not in memory. If a gate isn't in the artifact template, it won't fire. |
| Recommendations said "do X" without conditions — reader can't judge when the advice applies | Every rec: "IF [constraint], THEN [action], BECAUSE [reason]." No unconditional recommendations. |
| Transcript-derived speaker name committed to filename + body without verification (Shamla → Syamla, 2026-04-27) | When extracting names from auto-generated video/meeting transcripts, FLAG with `[INFERRED, transcript-derived]` or run a verification step (employee search, ask Denny). Never commit a transcript-derived name silently to filenames or proper-noun mentions. |

## See Also

- **area monitor gdoc** (see CLAUDE.md Daily Docs) — for scanning leadership priorities (different: scans people, not topics)
- `cheatsheet-doc-analysis.md` — for analyzing a specific document in depth
