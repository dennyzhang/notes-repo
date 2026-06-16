# Reducing Excessive AI Confirmations

*Owner: dennyzhang. Status: design + working Layer-2 prototype (`ask-gate.sh`). Sharpened from the Workplace thread (Catalin, Harry, Anthony, Trevor).*

## TL;DR
"Why ask?" comes in **two kinds**, and the fix is **three layers**. The kind that annoys you is prose deferral, and the layer everyone reaches for first (markdown + a hook) is the *weakest* one — you already run markdown + a hook and it's "still annoying." The actual unlock is **Layer 1: make the scary stuff safe-by-construction so "just do it" can't hurt you** — then the agent earns the trust Harry's `I_trust_you` agent was joking about, and Anthony's "what could possibly go wrong" stops being the objection.

## The two kinds of "ask"
1. **Harness permission prompts** (`Allow this Bash? y/n`). Config-controlled: `permissions.allow`, permission modes, a `PreToolUse` auto-approve hook. In MyClaw this is **already off** (daemon runs bypass/accept — a whole session ran ~50 tool calls with zero gates).
2. **Prose deferral** ("Want me to X?"). The model typing a question instead of acting. **This is 100% of your pain**, and it's *caused* by the persona/safety markdown MyClaw injects ("ask before external", "be careful", "you're a guest"). More caution-markdown in → more hedging out. (Trevor's "maybe a MyClaw problem" — yes, exactly this.)

A `PreToolUse` hook can't fix #2: it fires *after* the model already decided to ask, so there's no tool to intercept.

## Why "markdown + hook" isn't enough
That's only the prompt layer, and prompts decay under context pressure. Evidence: SOUL.md already says "act, don't defer" and you still get over-asking. You can't out-prompt a prompt. So the design adds two layers *below* the prompt.

## The three layers

### Layer 1 — Capability guardrails (the real unlock) — *Anthony + Trevor*
Don't gate dangerous actions; **make them safe or impossible**. Anthony: *"even if you ask 'should I delete the DB' and I say yes, still don't delete the DB."* Trevor: *"strip out bash / replace `rm` with a tool that backs up automatically — then no prompt injection can `--no-preserve-root`."*

Replace raw capabilities with safe, reversible-by-construction tools:

| Raw (remove/deny) | Safe replacement (always available) |
|---|---|
| `rm` / `rm -rf` | `trash` → recoverable; or snapshot-then-delete |
| db delete / drop | `db_delete()` → backs up + exposes a new version, then deletes |
| send message/email/post | **draft-first**; publish only on a separate explicit step |
| edit in place | branch / working-copy + diff (never land directly) |
| prod write | dry-run by default; scoped/read-only creds |

Effect: most "scary" actions become **reversible**, so they leave the ask-set entirely — and the genuinely catastrophic few are gated by *capability*, not by a sentence the model might skip. This is what makes "don't ask, just do it" actually safe.

### Layer 2 — Deterministic gate (code, harness-enforced) — `ask-gate.sh` + `gate-rules.json`
For whatever's left, decide **allow | ask in code**, not prose. Spine = Anthony's reversible/irreversible axis:
- reversible + low blast → **act** (never ask "should I create a diff")
- external send / no precedent → **ask** (draft-then-show)
- irreversible → act only if confident; else ask *(irreversibility raises the bar, it isn't itself the trigger — your "+1 to Anthony")*
- catastrophic / prod → **ask**, and Layer 1 should have already made it impossible
- precedent for this class exists → **act** (a `grep`, not a doc the model re-reads)

Your ask-gate, encoded — **don't ask if any:** net-good · options don't matter · precedent exists · (reversible). The model only fills typed fields (`kind, target, external, reversible, blast, confident`); the verdict is arithmetic. Run `./ask-gate.sh --selftest`.

### Layer 3 — Prompt layer, minimized — *Trevor's tip*
Keep only **multi-shot examples** ("just do" vs "ask first" — see `gate-rules.json`), injected by a `UserPromptSubmit` hook — examples beat abstract rules. **And delete the cause**: trim the diffuse caution lines in SOUL/SYSTEM/CLAUDE down to the gate + hard-floor. Removal is structural; adding "please don't ask" is just more markdown.

## How it wires into MyClaw
- **Layer 1**: safe-tool wrappers in `~/work/claude/scripts` + scoped creds / dry-run defaults.
- **Layer 2**: daemon `canUseTool` calls `ask-gate.sh` for tool calls; a **post-turn auto-approver** classifies any prose deferral and, if the gate says `allow`, injects "approved, proceed" so you never see it. *(This is "you typing why ask," mechanized.)*
- **Layer 3**: trim persona markdown + an examples-injecting hook.

## Self-tuning + metrics
Every override you make (`ask-gate.sh --record ...`) appends a precedent → wired into `autolearn-corrections` → the gate tunes itself. Track in the AI Playbook: **auto-approvals ↑**, **human-asks ↓** (toward the catastrophic floor), **false-acts = 0** (nonzero ⇒ too loose, tighten). Replay precedents in `workflow-regression` to catch drift.

## What can't be removed
The judgment on a genuinely novel, high-stakes, irreversible call stays the model — but it's forced to typed output, gated by code, and hard-floored so a wrong call can't become a SEV.

## Auto-discovery (how other hosts get this — no paste step)
The notes repo *is* the distribution channel — every host already reads notes-on-master — so a host
**self-installs**; there's no "paste this prompt" doc (that would just be more markdown to follow).

1. Wire once into your `~/work/claude` cron fleet — a daily notes-pull + discover cron alongside
   `cron-notes-push.sh`:
   `cd ~/notes && sl pull -q && bash ~/notes/users/dennyzhang/projects/ai-autonomy/install.sh --if-changed`
2. `install.sh` is idempotent + self-validating: it compares a content-hash version stamp, runs
   `ask-gate.sh --selftest`, and **only activates if green** — so a bad push self-rejects on the host
   instead of bricking the fleet (auto-apply = high blast radius). It exposes a stable gate path
   (`~/work/claude/state/ask-gate.sh`) the MyClaw daemon/hooks call, then stamps the version.

After the one-time trigger, every change pushed here propagates automatically. Discovery is a version
compare, not a doc to read.

## Files here
- `ask-gate.sh` — Layer-2 gate (runnable; `--selftest` 9/9). No `.py` — notes-repo legal.
- `gate-rules.json` — rule data (catastrophic set, examples); editable as data.
- `install.sh` — idempotent, self-validating auto-installer (run by each host's SessionStart trigger).
- `precedents.jsonl` — learned approvals (created on first `--record`).

## Credits (thread)
Catalin (just-do-it) · Harry (`I_trust_you`) · **Anthony** (reversible-vs-irreversible; guardrails > asking) · **Trevor** (replace dangerous tools w/ safe backed-up ones; multi-shot examples; brainstorm→plan→review cycle).
