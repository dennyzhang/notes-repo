# AI Knowledge Sharing — Discussion Topics Research

Compiled research for PE Sharing presentation (`PE-SHARING-AI-WORKFLOW-2026-03.md`).
Five topics researched from internet best practices (March 2026).

---

## 1. AI Hallucination — Detection and Mitigation

### Why It Happens in Coding

- **Training data quality.** LLMs trained on inconsistent open-source code — mismatched docstrings, insecure implementations, outdated API docs baked into model weights.
- **Knowledge cutoff vs. fast-moving ecosystems.** Models confidently generate code for APIs that have changed or been deprecated.
- **Package hallucinations.** Tests of 16 code-gen models on 756,000 samples: ~20% recommended non-existent packages. Prompts asking for a library "from 2025" produced hallucinated libraries in up to 84% of tasks. (USENIX Security 2025)
- **Three hallucination types** (ACM 2025 taxonomy): task requirement conflicts (most common), factual knowledge conflicts (wrong API/library), project context conflicts (ignores codebase conventions).
- **Overloaded context windows.** "God Prompt" CLAUDE.md files that dump entire architecture docs paradoxically increase hallucination — the model can't prioritize what matters.

### Practical Mitigation

- **RAG grounding.** Coupling prompts with retrieved docs/specs shows 35–60% error reduction in hybrid architectures.
- **Mandate investigation before answering.** "Never speculate about code you have not opened. Read the file before answering."
- **Allow explicit uncertainty.** Give the model permission to say "I don't know." Dramatically reduces false confidence.
- **Plan Mode before execution.** Agree on approach before any code is written — catches faulty assumptions early.
- **Keep tasks small and scoped.** One function, one bug, one feature per prompt. Large scope = more hallucination surface.
- **Deterministic checks for factual verification.** Verify URLs, package names, and API endpoints with actual lookups — not a second LLM.
- **Multi-agent validation.** Separate critic/verifier agent checking output before execution reduces hallucination rates vs. single-agent.
- **Self-audit instruction.** "After implementing, list any spec requirements that are not addressed."

### Key Stats

- ~45% of AI-generated code contains security flaws — security review remains non-negotiable human work.
- GitClear 2025: 8x increase in code duplication from AI assistants; 67% of developers spend more time debugging AI code than writing manually.
- Even NeurIPS/ICLR researchers submitted papers with hallucinated citations that passed peer review.

### Sources

- [LLM Hallucinations in Code Generation — ACM ISSTA 2025](https://dl.acm.org/doi/abs/10.1145/3728894)
- [Package Hallucinations — USENIX Security 2025](https://www.usenix.org/publications/loginonline/we-have-package-you-comprehensive-analysis-package-hallucinations-code)
- [Reduce Hallucinations — Claude API Docs](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations)
- [AI Coding Workflow 2026 — Addy Osmani](https://addyosmani.com/blog/ai-coding-workflow/)
- [Claude Code Skills and Context Problem — OlioApps](https://www.olioapps.com/blog/claude-code-skills-context-problem)
- [Chain-of-Verification — LearnPrompting](https://learnprompting.org/docs/advanced/self_criticism/chain_of_verification)

---

## 2. Context Switching Across Multiple Tasks and Projects

### The Problem

- **Context rot.** AI output quality degrades as sessions grow longer — models pull in irrelevant earlier details.
- **The goldfish problem.** Each new session starts from zero. First 20–30% of every session spent re-explaining constraints and decisions.
- **Mental model fragmentation.** 49% of dev teams use 5+ AI tools (GitLab 2025), each with isolated memory. Portability nearly impossible by design.
- **Parallel workstream overhead.** High AI-adoption teams juggled 47% more PRs per day but orchestration cost consumed much of the speed gain (Faros AI, 10,000+ devs).
- **Switching cost.** 15–30 minutes lost per platform switch without proper context preservation (Atlassian 2025).

### Strategies

- **Context files as persistent memory.** CLAUDE.md, plan.md, claude-progress.txt — loaded at session start. Both humans and AI reference the same source of truth.
- **Session hygiene.** New session for each major phase (planning, implementation, testing). Use `/clear` aggressively. Monitor context window usage.
- **Precision over breadth.** "Read only `src/auth/login.ts` and fix line 42" reduces token consumption ~40% vs. vague prompts.
- **Keep CLAUDE.md lean.** Under 300 lines. Avoid code snippets (go stale); use file:line references. Every line competes with working context.
- **Spec-driven development.** Write plan.md before starting — becomes the contract AI references across all sessions.
- **Subagent delegation.** Isolated subtasks in their own context windows so complex tasks don't pollute the main session.

### Key Quote

> "The developers who thrive in the AI-assisted future won't be those who write the best prompts — they'll be those who build the best contexts."

### Sources

- [AI Context Switching Technical Challenge — DEV Community](https://dev.to/pullflow/ai-context-switching-the-technical-challenge-reshaping-artificial-intelligence-14g6)
- [Writing a Good CLAUDE.md — HumanLayer](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [Context Engineering for Claude Code — Thomas Landgraf](https://thomaslandgraf.substack.com/p/context-engineering-for-claude-code)
- [Effective Harnesses for Long-Running Agents — Anthropic Engineering](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Context Engineering: Definitive 2025 Guide — FlowHunt](https://www.flowhunt.io/blog/context-engineering/)

---

## 3. Parallelism Constraints — One Devserver, Ask-and-Forget

### The Bottleneck

- **Serial task queuing.** Single-agent tools flatten parallel thinking into a sequential queue.
- **Context is the real bottleneck, not tokens.** The gap between what engineers carry in their heads and what AI understands is the primary constraint.
- **AI can slow you down.** METR study (July 2025): AI tools made experienced developers 19% *slower* despite expecting a 24% speedup — unstructured usage creates overhead.
- **"AI dams."** AI accelerates code generation but creates new chokepoints where human review becomes the constraint.

### Git Worktrees + tmux: The Foundation Pattern

One git worktree per agent, one tmux window per worktree. Agents sharing the same working tree run into each other's type errors and broken builds.

```bash
git worktree add -b feature-branch ../path/to/worktree
# new tmux window → run Claude Code → one agent per window
```

### Tooling

| Tool | What It Does |
|------|-------------|
| workmux | Maps each worktree to a tmux window, shows agent status |
| cmux | Universal AI agent manager, runs Claude/Codex/Gemini side-by-side |
| par | Unified tmux control-center with separate windows per context |
| Uzi | 3–5 agents exploring different implementations, merges best solution |
| DevSwarm | Concurrent nodes per git branch with independent worktrees |

### The Ask-and-Forget Anti-Pattern

**What it is:** Treating AI as a stateless oracle. Ask, get answer, close session, lose all context. The AI doesn't "forget" — it never knew.

**Countermeasures:**
1. **Session-start ritual (30 seconds).** Read setup/decision files, state the goal, ask for a plan.
2. **Spec-driven two-session pattern.** Session 1: AI interviews you to produce a spec. Session 2: fresh context + spec as input.
3. **Living context files in the repo.** Every session loads them. Ask AI to update when conventions are established.
4. **Task tracking files as coordination layer.** Hand new sessions the task file — not conversation history.

### Boris Cherny's Setup

- 5 parallel Claude instances in terminal, numbered 1–5 by tab.
- 5–10 sessions on claude.ai in browser for longer tasks.
- Each local session uses its own full git checkout (not worktrees — full separate checkouts).
- Plan mode first, then auto-accept: "I go back and forth with Claude until I like its plan. From there, I switch into auto-accept and Claude usually 1-shots it."
- Key insight: "It's not about deep work, it's about how good I am at context switching."

### Sources

- [Boris Cherny Workflow — VentureBeat](https://venturebeat.com/technology/the-creator-of-claude-code-just-revealed-his-workflow-and-developers-are)
- [How Boris Uses Claude Code](https://howborisusesclaudecode.com)
- [LLM Codegen Parallelization — DEV Community](https://dev.to/skeptrune/llm-codegen-go-brrr-parallelization-with-git-worktrees-and-tmux-2gop)
- [workmux — Raine Virta](https://raine.dev/blog/introduction-to-workmux/)
- [Why Single-Agent Coding Is Obsolete — DevSwarm](https://devswarm.ai/blog/why-single-agent-ai-coding-is-already-obsolete)
- [Context Is AI Coding's Real Bottleneck — The New Stack](https://thenewstack.io/context-is-ai-codings-real-bottleneck-in-2026/)

---

## 4. Project Orchestration Tooling Gap

### The Gap

AI handles discrete tasks well but lacks project-level orchestration:
- No persistent state across sessions
- No dependency management between tasks
- No concept of "60% done" or "this milestone is blocked"
- Task horizons limited to minutes-to-hours; real projects span weeks
- 95% of AI initiatives fail to reach production (MIT) — attributed to missing governance and integration, not model capability

### Emerging Tools

| Tool | Type | Maturity | Best For |
|------|------|----------|----------|
| Claude Code Agent Teams | Multi-agent orchestration | Experimental (Dec 2025) | Coordinated code work, parallel research |
| Devin 2.0 | Autonomous agent | Commercial, maturing | Ticket-to-PR automation, repetitive tasks |
| OpenHands | Open-source agent | Active (64k+ GitHub stars) | Self-hosted, customizable workflows |
| SWE-agent | Research platform | Academic | Benchmarking, research |
| Factory AI | Commercial platform | Early | Ticket-to-PR, engineering teams |
| LangGraph | Framework | Production-ready | Stateful, mission-critical workflows |
| CrewAI | Framework | Growing | Fast prototyping, role-based teams |

### How Practitioners Bridge the Gap Today

- **CLAUDE.md as project constitution.** Conventions, patterns, routing rules — the agent's "constitution."
- **Task files with dependency tracking.** TASKS.md with explicit blocking relationships, cross-session persistence.
- **Builder-validator pattern.** Separate the agent that builds from the agent that reviews.
- **"Document and clear" session management.** Dump plan/progress to .md file, `/clear`, fresh session reads the file.
- **ALERTS.md as P0 blocker mailbox.** Lightweight async message bus between agent sessions.
- **Master-clone architecture.** Main agent decides when/how to delegate to copies of itself.

### What's Coming Next (Anthropic 2026 Trends)

1. Engineering roles shift — tactical coding moves to AI; humans focus on architecture/strategy.
2. Multi-agent systems replace single-agent workflows.
3. Task horizons expand from minutes to days/weeks.
4. "Agent architect" emerging as a distinct role.
5. No dominant tool yet handles full project lifecycle orchestration — market gap identified for 2026–2027.

### Key Insight

> The 40% project cancellation rate predicted by 2027 (Gartner) suggests the gap between AI capability and reliable project-level deployment is real. Organizations investing in orchestration patterns now will have a material advantage.

### Sources

- [Anthropic 2026 Agentic Coding Trends Report](https://resources.anthropic.com/2026-agentic-coding-trends-report)
- [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Swarms Guide — Zen van Riel](https://zenvanriel.com/ai-engineer-blog/claude-code-swarms-multi-agent-orchestration/)
- [Devin 2025 Performance Review — Cognition AI](https://cognition.ai/blog/devin-annual-performance-review-2025)
- [OpenHands — One Year](https://openhands.dev/blog/one-year-of-openhands-a-journey-of-open-source-ai-development)
- [Framework Comparison 2026 — O-Mega AI](https://o-mega.ai/articles/langgraph-vs-crewai-vs-autogen-top-10-agent-frameworks-2026)
- [Deloitte AI Agent Orchestration](https://www.deloitte.com/us/en/insights/industry/technology/technology-media-and-telecom-predictions/2026/ai-agent-orchestration.html)

---

## 5. Context Window Management

### Why It Matters

- **Context rot is measurable.** Chroma Research (2025) tested 18 LLMs: performance degrades non-uniformly as context grows — even on trivial tasks. Adding topically related but incorrect information (distractors) compounds degradation.
- **Maximum Effective Context Window (MECW)** is far shorter than advertised maximum. Peer-reviewed study (Jan 2026): "A few top models failed with as few as 100 tokens in context; most had severe degradation by 1,000 tokens." All models fell far short of their max by >99%.
- **Lost in the middle effect.** Information positioned in the center of a long context is more likely ignored than information at the beginning or end.
- **Auto-compact triggers at ~95% in Claude Code.** Before that threshold, reasoning quality has already progressively degraded.

### Practical Tips

- **The 70% rule.** Compact at 70% capacity, not 95%. Waiting until auto-compact means the model has already been operating degraded.
- **Start fresh at task boundaries.** Each commit, ticket, or phase change is a natural context reset point. The cost of re-loading context is lower than degraded output from a bloated session.
- **Monitor usage.** `/context` shows real-time token breakdown. `/usage` shows session and daily consumption. MCP servers add tool schemas to every request — check with `/mcp`.
- **Precision over breadth.** "Read only `src/auth/login.ts` and fix line 42" reduces token consumption ~40% vs. vague prompts that trigger broad exploration.
- **Correct by restarting, not in-place.** When the agent goes down a wrong path, revert changes and start a new session with a better prompt. Correcting in-place consumes more context trying to override bad reasoning.

### Common Mistakes

- **The "God Prompt" anti-pattern.** Front-loading everything into one massive prompt or endless session. Performance collapses as context fills.
- **Bloated MCP server configuration.** Active-but-unused MCP servers consume significant context before any work begins. Disable what you don't need.
- **Passive context management.** Assuming auto-compact handles everything. It does an "OK job" but introduces information loss.
- **Carrying stale context.** Outdated tool call outputs and completed task artifacts are not neutral — they actively reduce performance.

### Power User Patterns

- **Commit as context checkpoint.** Commit at end of every sub-task. Treat commits as save points and context reset boundaries.
- **Sub-agent isolation.** Delegate noisy tasks (file searches, test runs) to sub-agents. Main session accumulates only summaries, not verbose output. Can reduce token usage 80–90%.
- **Manual compact with preservation instructions.** "Preserve the current task requirements and API contract; discard the alternative approach exploration." Outperforms automatic compaction.
- **CLAUDE.md as session bootstrap.** Minimal bootstrap: conventions, architecture, file layout, what to avoid. Replaces re-explaining project context every session.
- **Model switching as context refresh.** When hitting a blind spot late in a session, copy the core prompt to a different model. Forces you to distill what context is truly essential.

### Key Quote

> "Context engineering is a first-class engineering discipline. Treat what goes into context with the same care you treat what goes into production."

### Sources

- [Context Rot — Chroma Research](https://research.trychroma.com/context-rot)
- [Maximum Effective Context Window study](https://www.oajaiml.com/uploads/archivepdf/643561268.pdf)
- [AI Coding: Managing Context — Pete Hodgson](https://blog.thepete.net/blog/2025/10/29/ai-coding-managing-context/)
- [Managing Claude Code Context — MCPcat](https://mcpcat.io/guides/managing-claude-code-context/)
- [Claude Code Compaction — Steve Kinney](https://stevekinney.com/courses/ai-development/claude-code-compaction)
- [AI Coding Anti-Patterns — DEV Community](https://dev.to/lingodotdev/ai-coding-anti-patterns-6-things-to-avoid-for-better-ai-coding-f3e)
- [My LLM Coding Workflow 2026 — Addy Osmani](https://addyosmani.com/blog/ai-coding-workflow/)
