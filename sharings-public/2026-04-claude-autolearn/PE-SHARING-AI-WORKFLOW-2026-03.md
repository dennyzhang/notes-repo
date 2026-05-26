# Your Moat Is Leverage, Not Speed

**Presenter**: Denny - MRS ML PE
**Audience**: MVAI Dev Team
**Format**: 30 min (20 min presentation + 10 min open discussion)

**Disclaimer**: This is a fast-iterating space — no one is an expert. These are patterns I've found useful, not prescriptions. Looking forward to your suggestions and open challenges.

**TL;DR**: Speed is table stakes. Leverage compounds. Four investments: shift your mental model, build shared context systems, measure what's working, and develop the non-technical skills AI can't replace.


## The Trap

Every team's first instinct with AI: go faster. And that's the right first step — it'll be the focus for most of us for months. But speed alone is something every team eventually gets. The question worth asking now is what you do after that.

**What leverage means here**: Speed is doing the same work faster. Leverage is changing what work your team can take on. Shared context that onboards AI sessions instantly. One engineer directing multiple AI workstreams. A team that ships what used to be unimaginable.

This session covers four investments that build organizational leverage, with evidence from my own adoption and patterns emerging across Meta.


## Investment 1: Shift Your Mental Model

Tools change almost every day. Mental models compound forever. Three shifts that changed everything for me:

1. **Tell AI what, not how.** Describe the outcome, not the steps.

   *Example*: [D95490907](https://www.internalfb.com/diff/D95490907) — the full prompt was one sentence: "Ctrl+K in cmux browser should delete to end of line, not clear terminal." No file paths, no function names, no "open file X and change line Y." Claude found the keybinding config, identified the conflict between readline kill-line and terminal clear, and produced a working diff. The prompt *was* the diff summary.

   Compare that to the instinct: "Open src/keybindings.ts, find the Ctrl+K handler, change it to call killLine() instead of clearTerminal(), and update the help popover text." That prompt is longer, more work to write, and constrains Claude to your approach — which might not be the best one.

2. **Expand what's possible.** The cost of trying is near zero. The constraint shifts from "can I build this?" to "should I build this?"

   *Example*: I needed to identify Claude Code power users willing to share practices — starting from 250 names. Pre-AI, I'd email 10 people and hope. Instead, I described the goal and pain points. Claude launched 6 parallel subagents searching Workplace posts, diffs, and wikis, scored all 250 names by sharing signal, and returned 13 actionable people with evidence. One session, one prompt describing the goal.

   And when you do ask AI, end your prompts with "wdyt?" That one habit shifts AI from executing your plan to challenging it.

3. **Build your moat through iteration.** Generic AI gives generic results. Tailor yours to your codebase, your conventions, your failure patterns.

   *Example*: In week 1, Claude kept using `git` instead of `sl` (Sapling). I corrected it. An auto-learn hook captured the correction and added "use sl, not git" to my config. In week 2, Claude kept retrying failed GPU tests blindly. I said "investigate root cause first." The hook captured that too. By week 4, I had 22 accumulated rules — each one a past mistake that now never recurs. The engineers who stall are the ones who set up once and never iterate.

**Where this breaks**: These shifts sound obvious on paper. In practice, you'll catch yourself writing step-by-step instructions instead of describing outcomes, or reviewing every intermediate line instead of checking the final output. The gap isn't knowing — it's doing.


## Investment 2: Build Shared Context Systems

Most engineers set up [CLAUDE.md](https://www.internalfb.com/code/notes/users/dennyzhang/CLAUDE.md) for individual use — that's the starting point. The non-obvious move is going beyond the codebase.

**Keep CLAUDE.md lean, use reference files for depth.** A common anti-pattern: you keep adding rules to CLAUDE.md until it's 2000 lines and AI performance regresses — it can't prioritize when everything is "important." My CLAUDE.md is ~100 lines of rules. The depth lives in reference files: [cheatsheets](https://www.internalfb.com/code/notes/users/dennyzhang/cheatsheet/) for diff workflows, error catalogs for known failures, people profiles for collaboration context. CLAUDE.md points to them; AI loads them on demand. Think of CLAUDE.md as a routing table, not a knowledge base.

**Ingest your team's context.** Meeting notes, critical chat threads, project decisions, oncall runbooks — put them in AI-readable files. Most people only feed AI code. Feed it everything.

**Build a persistent thinking partner.** When context accumulates across sessions, AI compounds. Examples that any engineer can replicate:
- [`/my-start`](https://www.internalfb.com/code/notes/users/dennyzhang/.claude/commands/my-start.md) — daily boot: recommends what to work on next, digests meeting notes, checks infrastructure, and pre-fetches GChat messages for instant comms review later.
- [`/my-comms`](https://www.internalfb.com/code/notes/users/dennyzhang/.claude/commands/my-comms.md) — weekly comms review that reads cached GChat conversations, analyzes communication patterns against growth goals, and surfaces concrete tips for improvement.
- [`/my-save`](https://www.internalfb.com/code/notes/users/dennyzhang/.claude/commands/my-save.md) — session checkpoint: persists state, updates project status, runs audits. Tracks effectiveness metrics (automation rate, escalation count) across sessions.
- [`/my-debrief`](https://www.internalfb.com/code/notes/users/dennyzhang/.claude/commands/my-debrief.md) — daily bar-raiser evaluation against target level standards. Honest self-assessment, not affirmation.

**Concrete example**: In one conversation, AI cross-referenced all my open tasks against my growth goals and surfaced high-leverage opportunities I'd missed — with copy-paste-ready prompts tailored to my context. Hours of manual planning in minutes. Without persistent context, it's just a chatbot.

**Google Doc as a human-in-the-loop review surface.** AI generates and maintains a [project status doc](https://docs.google.com/document/d/12UN31uQaC3WpwcE622UzFSd6dCdcBs4hsuCceedWK0Q/edit). You review and leave comments — "mark this done," "reprioritize X," "this is wrong." Next session, AI reads your comments, acts on them, replies with `[Claude]` prefix, and resolves. The doc stays current without you editing it. This is async collaboration: you steer with comments, AI executes with code. Anyone with doc access (your EM, XFN partners) can see status and leave feedback too.

**Tool composition — use each tool for what it's best at.** Manus gathers information from sources Claude can't reach. Claude analyzes, judges, and executes. Each tool does what it's best at. The power user search from Investment 1 is an example — Manus pulled the raw data from a protected source, Claude did the analysis.

**Evidence at scale**: [D94276117](https://www.internalfb.com/diff/D94276117) — I gave AI the target (end-to-end GPU tests, 9 models, 2 servers) and it produced 12 stacked diffs autonomously. This only works because the context system made each session productive from the first prompt.


## Investment 3: Measure Effectiveness and Rethink Review

No team I've talked to tracks their AI effectiveness. Three numbers worth tracking:

1. **Automation rate** — tasks where AI produced a usable result without you stepping in to fix, redirect, or redo. Target: >70%.
2. **Escalation count** — times AI got stuck and needed manual intervention per session.
3. **Revert rate** — outputs you accepted then rolled back. Target: <10%.

*Example — what tracking actually looks like*: My `/my-save` command captures these numbers at the end of every session. Here's what the trend looked like:

| Week | Automation Rate | Escalations/Session | What Changed |
|------|----------------|--------------------:|-------------|
| 1 | ~50% | 4 | Baseline — lots of "use sl not git," "don't retry blindly" |
| 2 | ~60% | 3 | Auto-learn hook captured 8 corrections, they stopped recurring |
| 3 | ~70% | 2 | Cheatsheets added for diff workflow and SEV triage |
| 4 | >80% | 1 | Context system mature — most sessions need zero corrections |

Without tracking, I would have blamed the tool instead of fixing my own context. The fix was always on my side — better rules, better context, better cheatsheets.

**The non-obvious bottleneck**: AI doubles code output. If your review capacity doesn't scale with it, review becomes the bottleneck. Google's 2025 DORA report confirms: AI adoption only correlates with higher throughput for teams that measure and iterate. Teams that adopted without measurement saw no improvement.

**How to rethink review:**
- **Review the prompt, not just the diff.** The prompt shows *why*; the code is just the implementation. Faster and more revealing than reading every line.
- **Triage by blast radius.** A test addition needs less scrutiny than an API change. Match review effort to risk.
- **Let machines verify machines.** Lean harder on CI — type checking, tests, security scans. Free human review for design judgment.


## Investment 4: Invest in Non-Technical Skills

AI is rapidly commoditizing technical execution. The skills that differentiate you — and that AI can't replicate — are non-technical.

1. **Selling and persuasion.** AI can write your proposal. It can't get buy-in. When everyone ships faster, the bottleneck moves from "can you build it?" to "can you convince people it matters?"

2. **Building allies.** AI scales your output. Allies scale your influence. A diff with a champion in another org lands differently than one without. Relationships are the one asset that compounds regardless of what happens to the technology.

3. **Communication and visibility.** AI frees time from routine work. Use it for the conversations that actually move projects and careers. AI will validate almost anything you tell it. Humans push back. That friction is where better decisions come from.

**The data supports this**: The more people collaborate with AI, the more they report feeling isolated (Journal of Applied Psychology, 794 workers). Gallup: employees with mentors are 2x more likely to report growth — yet only 23% have a sponsor. As AI levels the technical playing field, non-technical skills become the compounding advantage.

**Where this breaks**: I've caught myself using AI as a substitute for a hard conversation — writing the perfect message instead of walking over and talking. AI can draft the words, but it can't build the relationship.

**Concrete example — AI-assisted communication upgrade**: I fed AI my GChat 1:1 conversations with five close collaborators, cross-referenced against my growth goals. It surfaced patterns I couldn't see myself: I send 2-4 rapid messages when one would do, I broadcast more than I ask, and I drop follow-up loops on enthusiasm. Before/after:

| Before (my actual message) | After (AI-rewritten) |
|---------------------------|---------------------|
| "Morning [name], Talked with Michael, I'll do a sharing next week. These are best knowledge. Appreciate if you can read and suggest improvements. [link]" | "[Name] — presenting AI workflows next week. 5-min skim of Section 3 would help. What should I cut? [link]" |
| "95% sparse latency is the most critical commitment. We need identify the gaps. Whenever sparse latency has a big gap, the issue should be tracked." | "OmniUV is at 86.5% vs 95% target. What do you think is driving it? Should we track all gaps >5% as mandatory debug items?" |

The pattern: lead with data not declarations, ask questions not give directives, scope the ask for the recipient. AI found these patterns in 5 minutes across 140 messages. I'd never have spotted them myself.


## Close — Where the Leverage Starts

**One caveat first**: AI compresses coding, not thinking. 95% of AI pilots fail to deliver ROI (MIT). Before starting any AI project, ask: *if AI nails this perfectly, does it move a metric I care about?* If not, skip it. The discipline of "not worth building" is more valuable than the speed of building it.

**Three things to take away:**

1. **Iterate on context, not prompts.** Better context gets better answers forever. Better prompts get better answers once.
2. **Track what's working.** Without measurement, you blame the tool instead of fixing your own setup.
3. **Invest in the skills AI can't replace.** Relationships, persuasion, and judgment compound regardless of what happens to the technology.

**Start here:** A shared CLAUDE.md in one repo (half a day). Track automation rate for a month. Book one conversation this week you've been delegating to AI.

**Tools worth your time**: [cmux](https://www.internalfb.com/cmux), [MetaClaw](https://www.internalfb.com/metaclaw), status line, [`weekly-status-report`](https://www.internalfb.com/code/notes/users/dennyzhang/skills/weekly-status-report/SKILL.md), [`pe-impact-clarity`](https://www.internalfb.com/code/notes/users/dennyzhang/skills/pe-impact-clarity/SKILL.md), `tasks`, `google-docs`.

**Questions for discussion:**

1. **Where's the line between delegation and dependency?** If nobody wrote the code, who debugs the SEV? *Tip: periodically do one task fully manually. If it feels foreign, you've crossed the line.*

2. **How do you catch hallucination before it wastes hours?** *Tip: before AI starts a complex task, ask "tell me your understanding." If it can't restate the problem accurately, it will build the wrong thing confidently.*

*Your questions — add during discussion.*

*Internal links: [CLAUDE.md](https://www.internalfb.com/code/notes/users/dennyzhang/CLAUDE.md) · [Cheatsheets](https://www.internalfb.com/code/notes/users/dennyzhang/cheatsheet/) · [Hooks](https://www.internalfb.com/code/notes/users/dennyzhang/config/hooks/) · [Commands](https://www.internalfb.com/code/notes/users/dennyzhang/.claude/commands/)*


## Credits

- **Peer reviewer** for pushing to cut content and add more concrete examples — made the talk land better
- **Colleague** for raising key points that improved the depth of this sharing
- **Colleague** for surfacing critical pain points: context switching, parallelism bottlenecks, hallucination
- **Colleague** for pushing on metric definitions and AI-native framing
- **Colleague** for suggesting highlighting what doesn't change in the AI era
- Many others for the proofreading and feedback
