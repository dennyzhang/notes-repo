# Cheatsheet Improvement Flywheel

How the cheatsheet tree improves itself without rotting. Three operator goals,
one loop:

1. **Stop regression in new additions** — nothing lands that breaks structure or
   duplicates/contradicts an existing rule.
2. **Find and absorb good relevant skills** — harvest the skill catalog + recent
   learnings into coverage, *without* bloating.
3. **Ask confirmation for major changes** — auto-land the safe, route the risky.

## Target state — the two-loop flywheel

Two loops, one linchpin (the eval).

**Loop A — keep existing healthy (maintain).** A cheatsheet earns its place by *doing its
job*: making an agent do the task correctly. Health is checked at two depths:
- *Proxy hygiene (built):* structure (`lint --gate`/sweep), grounding (`--audit-grounding`),
  dedup/contradiction (`cheatsheet-dedup-sweep.sh`). Necessary, not sufficient.
- *Real signal (NOT built — the gap):* task-outcome eval — agent-with-sheet vs without on a
  held-out task set. This is the only thing that proves "doing its job reliably."
- *Trim policy:* **demote, don't delete, by default.** Low *usage* alone must NOT delete — a
  rule that fires rarely but prevents a SEV is high-value. Delete ONLY when the eval shows
  zero task-success contribution AND the rule is stale/superseded. Usage-only trimming
  silently loses rare-but-critical rules.

**Loop B — add new (grow).** Mine operator practice in a domain → propose → gate → probation
→ prod:
1. *Mine:* find recurring practice in sessions/diffs/learnings for a domain.
2. *≥3 bar:* one observed instance = evidence (log it); only a pattern seen **≥3 times**
   becomes a candidate *rule*. Prevents over-generalizing a single practice into a false rule.
3. *Accept-gate (built):* `cheatsheet-accept.sh` — deterministic (structure+grounding) then
   adversarial LLM (dedup/contradiction). Default-reject.
4. *Probation (provisional tier):* lands `provisional`, loaded in shadow, **its effect
   measured** — probation without measurement is just a delay. Needs telemetry + eval.
5. *Promote to prod:* auto-promote additive sheets that pass eval+probation; human-gate only
   deletes, rewrites, and hot-path/core changes (the ask-tier).

**Why the eval is the linchpin (anti-Goodhart):** if promotion is gated on proxies (lint,
dedup) and not outcomes, the flywheel will happily grow a tidy, grounded, non-duplicate
corpus that doesn't actually help. Gate on outcomes or it optimizes the proxy.

**Bootstrap the eval cheaply:** the eval task set doesn't need hand-authoring — each dated
incident in the learnings-log / SEV history IS a test case ("given this situation, does the
agent handle it correctly?"). Generalize the OT replay-eval harness (`building-agent-evals.md`)
over that history. That turns the existing forensic provenance into the eval corpus.

**The golden set is organic — your corrections ARE the answer key.** Don't curate it as a
project. Every correction is BOTH a rule and a test case: the "After" (what you told the
agent to do) becomes the cheatsheet rule; the full `(situation, Before=wrong, After=right)`
triple becomes a golden test case. `cron-autolearn-corrections.sh` already extracts Before/
After corrections into cheatsheets — tee the SAME extraction into a `golden/` store and the
answer key accretes for free, every time you correct the agent. Sources, by signal strength:
direct corrections (wrong→right, strongest) > recorded outcomes (diff landed=right /
reverted=wrong, SEV resolution) > gate verdicts (pass/block). Two catches: (1) **cold start**
— one-time backfill from existing history so the eval isn't empty on day one; (2) **label
noise** (landed-then-reverted, a wrong correction) — sampled validation, not an upfront audit;
tolerable because the eval is pairwise + aggregate. **Hold-out discipline:** a correction's
own instance can't be both the rule and its eval case — eval each rule on OTHER situations,
which is also the generalization test. Net: the system that learns a rule also learns how to
test it, from the same moment — and your role stays "be the source of what's right,"
expressed through normal work, not a labeling chore.

**Storage discipline (do NOT store everything raw).** The golden store holds *extracted
cases* — `(situation, wrong, right)` triples + a provenance pointer (session id + timestamp)
back to the source — NOT raw transcripts. The harness already retains session jsonl as the
raw audit source; the collector extracts from it, it does not re-store the firehose. Three
reasons: signal-to-noise (most interaction isn't a label), cost/rot (transcripts are huge and
stale fast), and — critical for this operator — **sensitive-data + lane isolation**: the
notes/`golden/` store is GH-mirrored, so the collector MUST lane-filter to work-only and strip
sensitive content (people/career/life) before anything lands. Replay runs on the structured
cases, never on the chat log.

**Where we are:** proxy hygiene + accept-gate are built and running. The eval loop +
telemetry + provisional tier are the remaining build, and they bind together — probation,
trim, and promotion all consume the eval/telemetry signal.

## Operator review — respect limited bandwidth

The weekly review stays, but the operator's attention is the scarce resource, so the queue is
**triaged FOR him**, never a flat dump. Rules:
- **Rank by leverage** = breadth of effect × irreversibility/risk × how-much-it's-blocking. A
  policy/threshold call that resolves a whole CLASS outranks a single instance; a golden-label
  validation that gates N promotions outranks validating one; a hot-path/core change outranks a
  peripheral one.
- **Cap the queue** — surface only the top few above a leverage bar. Auto-handle or batch-defer
  the rest (logged, not shown).
- **Decision-card context** — each item is decidable in seconds without investigation:
  situation (what+where, `file:line`/link) · 2–3 options with the recommendation + why · cost of
  getting it wrong / what it unblocks · the safe default if no response.
- **Default-safe on silence** — every ask has a safe default that fires if he doesn't get to it
  (demote-not-delete, keep-both, hold-in-provisional). Silence never blocks the flywheel and
  never does anything irreversible.

See `memory/feedback_leveraged_asks_clear_context.md` — this applies to every surface, not just
cheatsheets.

## The loop (6 stations)

```
  (1) GATE-ON-WRITE ──► (2) TIER CLASSIFIER ──► (3) HARVEST SCAN ──► (4) DRAFT
   commit-time, reactive   auto vs ask          weekly Workflow      land or route
        ▲                                                              │
        │   (1b) STRUCTURAL SWEEP — daily, proactive, whole-tree       │
        │        auto-fix safe debt + draft the rest                   │
        └──────────────── (5) SELF-TIGHTEN ◄──────────────────────────┘
              a regression that slips → a new lint rule / bar criterion
```

**Reactive vs proactive (the gap that motivated 1b):** the gate (1) only sees
files in the *current commit*, so pre-existing debt in files nobody is editing —
broken refs, stale provenance, orphans, oversize — is invisible to it. Station
1b is the proactive counterpart that sweeps the *whole tree* on a schedule.
Without it, that debt only gets fixed when a human notices and hand-runs the
audit (which is how the legacy `cheatsheet-*.md` ref rot was found 2026-06-10).

### 1. Gate-on-write (Goal 1, structural) — deterministic, no LLM

`pretxncommit` hook `scripts/hooks/cheatsheet-lint-hook.sh` → `lint-cheatsheets.sh
--gate`. Blocks a commit that introduces a **fixable** regression on the files it
touches:
- a cheatsheet with no `Last updated:` footer, or
- a newly-broken relative markdown link.

Size-cap debt is **WARN-only** (the weekly full audit owns it) so editing an
already-over-cap file never bricks the 4-hourly auto-push. Bypass:
`[skip-cheatsheet-lint]` in the commit message. This is the real enforcement —
prose mandates get skipped under task focus; the hook does not.

### 1b. Structural sweep (Goal 1, proactive) — daily cron, no LLM

`scripts/cron/cheatsheet-sweep.sh` (daily) runs `lint-cheatsheets.sh --fix` over
the whole tree, then drafts whatever it can't safely auto-fix.
- **Auto-fixed** (reversible, unambiguous): legacy `cheatsheet-X.md` refs whose
  un-prefixed basename resolves to exactly ONE `*/X.md`. The 4-hourly auto-push
  commits these; they pass the gate.
- **Drafted for review** (`~/logs/cheatsheet-harvest/sweep-<date>.md`): dead refs
  (no target), oversize files, orphans — the ask-tier items.

The audit checks: size cap, provenance, broken markdown links, broken **backtick
local refs** (folder-qualified or legacy-`cheatsheet-` only, so external
source citations like `SKILL.md` don't false-positive), and orphans.

### 2. Tier classifier (Goal 3) — what auto-lands vs what asks

| Tier | Examples | Action |
|------|----------|--------|
| **Auto-land** | provenance stamp, broken-link fix, formatting/typo, INDEX row for a new file, a single additive rule that passes the ≥3-evidence bar AND the dedup reviewer | just do it (reversible, low blast radius) |
| **Ask first** | delete / merge / rename a file; **split a file** (anchor blast radius — inbound `#anchor` links break); rewrite a rule that another file or a **hook** depends on; remove a rule; change a routing table that crons read; touch a hooked modality's rules | draft + route to operator |

Mirrors the repo's existing *Act-Don't-Ask* + Autonomous-Action-Allowlist; this
is that policy bound to the cheatsheet surface.

### 3. Harvest scan (Goal 2) — weekly Workflow, anti-bloat by construction

Runs as a saved Workflow (`scripts/cron/cheatsheet-harvest.workflow.js`), invoked
weekly. Shape — fan-out → dedup → adversarial-reject → draft:

- **Scan (parallel):** partition `available skills + recent AUTO-LEARNINGS` into
  buckets; one agent per bucket finds content relevant to an existing cheatsheet
  lane and returns `{skill/learning → covers gap in <file> | overlaps <file>}`.
- **Dedup (barrier):** merge candidates; drop anything already covered.
- **Adversarial reject (parallel):** one skeptic per surviving candidate must
  argue *"reject — bloat / already covered / fails the ≥3 bar"*, citing the
  specific existing rule it checked. Default to reject when uncertain.
- **Synthesize:** emit ≤1 candidate change/run as a draft to
  `~/logs/cheatsheet-harvest/<date>.md`. Never lands.

**Two hard anti-bloat rules** (the whole value of this tree is density):
- **Link-over-copy.** A cheatsheet *points at* the canonical skill and distills
  only the non-obvious operator-specific delta. Copying a skill's body in is the
  anti-pattern — it goes stale the moment the skill updates. (`issue-report.md`
  "cherry-picked from imoc skill" is the model.)
- **Net-neutral-or-shrinking bias.** The scan may propose **deletions and
  merges**, not only additions. A run that only ever adds is over-fitting.

### 4. Draft / land

Content changes are always a draft for operator review (cap 1/run). Structural
fixes from station 1's class auto-land.

### 5. Self-tighten (the flywheel)

Any regression that slips the gate becomes a **new deterministic rule** in
`lint-cheatsheets.sh` (preferred) or a new bar criterion here. Same promotion
discipline as `ai-failure-modes.md` (≥3 dated confirmations → a rule). The loop
hardens itself; it does not rely on remembering.

## The content diff-reviewer (Goal 1, content) — used by station 3 and manual

Not deterministic, so it's an LLM pass, not a hook. Fire it on any
`cheatsheets/**/*.md` diff. A 3-lens panel (cheap, high-signal):

> Review this cheatsheet diff against the existing tree at
> `~/notes/users/dennyzhang/cheatsheets/`. Three lenses, return per-lens verdict:
> 1. **Dedup** — does this duplicate a rule that already exists elsewhere? Cite
>    the `file:line` you compared against. If yes → reject, link instead.
> 2. **Contradiction** — does it contradict an existing rule? Cite `file:line`.
> 3. **Evidence bar** — is a *new rule* cited to ≥3 dated incidents? If not →
>    it's a candidate for the ledger, not a rule.
> Default to flagging when uncertain. Output: `file:line - issue - why`.

A verdict without a cited `file:line` does not count (no rubber-stamping).

## The Cheatsheet Contract (every edit must satisfy — human OR machine)

The rules below are the acceptance criteria for any change. The **Enforced by** column
is the path to full automation: a rule a machine can't check is a rule a machine can't
be trusted to follow. `det` = deterministic lint, `llm` = adversarial LLM verifier,
`human` = taste (the part to shrink), `—` = not yet enforced (the build backlog).

| # | Rule | Enforced by |
|---|------|-------------|
| **Structure** | | |
| S1 | One folder per domain, non-overlapping; no cross-cutting "tier" folders. File lives with the domain that consumes it. | human (folder add is rare) |
| S2 | ≤800 lines/file; overflow splits to a same-domain deep file. | det (`lint` SIZE) |
| S3 | Folder with ≥4 files has an `INDEX.md`; central index counts match reality. | det (`--fix-index`); INDEX-presence = — |
| S4 | Provenance footer on every content file. | det (`--gate` PROVENANCE) |
| S5 | No broken links/refs; every new file has a routing row (no orphans). | det (`--gate` LINKS/REFS, sweep ORPHANS) |
| S6 | Naming: lowercase-kebab (except `INDEX.md` / `CHEATSHEET-INDEX.md`). | — |
| **Content & evidence** | | |
| C1 | Rules are EARNED: a new core-cheatsheet rule needs ≥3 dated occurrences; <3 stays as evidence in the domain `*-learnings-log`. | det proxy (`--gate` requires a learnings entry); the ≥3 count itself = llm/human |
| C2 | Every rule cites verifiable provenance (D-number / SEV / task / URL / date / `file:line`). No rule without a resolvable source. | **det** (`--gate` grounding, built 2026-06-14) — token present + well-formed; the deeper "does the source say what's claimed" resolve is the pipeline's `llm` step |
| C3 | Dedup before adding: if a rule exists, add evidence under it — don't add a bullet. | **llm** (`cheatsheet-content-verify.sh`, blocking, built 2026-06-14) |
| C4 | No contradiction with an existing rule. | **llm** (`cheatsheet-content-verify.sh`, blocking, built 2026-06-14) |
| C5 | Forensic, not vibes: specific numbers, commands, `file:line`. | human |
| **Anti-bloat** | | |
| B1 | Link-over-copy: point at the canonical skill, distill only the operator delta. | llm/human |
| B2 | Net-neutral-or-shrinking bias: propose deletions/merges, not only additions. | human (harvest reject station) |
| B3 | Core (hot-path) files stay lean; provenance/logs/specialized topics → on-demand siblings. | det (SIZE) + human |
| **Lifecycle** | | |
| L1 | Auto-land safe (structural, provenance, single ≥3-evidence additive rule passing dedup); ask/route risky (delete/merge/rename/split/rule-rewrite/routing change). | tier classifier (station 2) |
| L2 | close-thread: log evidence by default, promote at ≥3, commit+push to notes. | det proxy + doctrine (`auto-save-learnings.md`) |

**The automation thesis:** the rightmost column is the roadmap. Today the last line of
defense is operator taste. Every `human`/`—` cell is either (a) convert to a `det` lint
rule, (b) convert to a default-reject `llm` verifier, or (c) keep human ONLY for the
irreducibly-taste calls — and gate those behind the "ask" tier so the pipeline can't land
them unreviewed.

## Auto-create pipeline readiness (when machines author, not Denny)

The current tree is human-authored from experience; quality ultimately rests on Denny's
taste at write time. An auto-explore/auto-create pipeline removes the human author, so the
taste backstop must move to **machine-checkable gates + earn-trust quarantine + a
task-outcome signal**. Four pillars, all extensions of what exists:

1. **Contract-as-spec.** The generator reads this Contract as its system prompt and
   produces to it. Generating to the gate is cheaper than fixing after.
2. **Adversarial acceptance gate (default-reject), before anything lands:**
   - *Structure*: `lint --gate` — already deterministic. ✓
   - *Grounding* (C2): **deterministic half BUILT 2026-06-14** — `lint --gate` checks every
     new rule bullet (any cheatsheet) for a citation token (D#/S#/T#/P#/date/URL/`file:line`).
     **Trust gradient (fixed 2026-06-14):** the auto-create pipeline opts into strict via
     `CS_STRICT=1` (set by `cheatsheet-accept.sh`) → hard BLOCK; interactive/human edits get a
     WARN, since craft/style rules legitimately have no incident source. The remaining half is
     the pipeline's `llm` resolve step: confirm the cited source exists AND says what's claimed.
     This is the #1 gate — a pipeline's dominant failure mode is plausible-but-false rules.
   - *Dedup/contradiction* (C3/C4): **BUILT 2026-06-14** — `cheatsheet-content-verify.sh`
     runs the 3-lens panel via `claude -p` as a **blocking, default-reject** gate; a verdict
     without a cited `file:line` is not trusted. Verified: a duplicate of an existing rule is
     rejected with the existing `file:line` cited; a novel grounded rule passes.
   - Mirror the diff auto-review-bot trust gradient: machine-authored content gets MORE
     adversarial scrutiny than human-authored, not less.
   - **One call:** `cheatsheet-accept.sh <files>` runs stage 1 (`lint --gate`, deterministic)
     then stage 2 (`cheatsheet-content-verify.sh`, LLM). Default-fail; lands only if both pass.
     This is the gate the auto-create pipeline invokes per candidate.
3. **Quarantine + earn-promotion.** Auto-created cheatsheets land in a provisional state
   (`provisional: true` frontmatter or a staging area), NEVER directly into hot-path core
   files. Promotion to core requires: passes the adversarial gate + an eval signal (below)
   + (for ask-tier shapes) human ok.
4. **The only non-proxy signal — task-outcome eval.** A cheatsheet's real quality = does an
   agent using it do the task better? Reuse the replay-eval harness (`building-agent-evals.md`):
   run held-out tasks with vs without the candidate; accept only if measured success delta
   > 0 with no regression. This also self-heals: a cheatsheet that stops helping is
   auto-demoted. Everything else (lint, panels) is a proxy; this measures the thing itself.

**Build order (highest leverage first):**
1. ~~Grounding verifier (C2)~~ — **DONE 2026-06-14** (`lint --gate` deterministic half).
2. ~~Dedup/contradiction as a blocking `llm` gate (C3/C4)~~ — **DONE 2026-06-14**
   (`cheatsheet-content-verify.sh`; `cheatsheet-accept.sh` chains det + llm into one call).
3. Provisional tier + promotion rule — auto-content lands `provisional`, can't be routed
   from a core INDEX until promoted (a new deterministic `lint` check).
4. Eval-gated promotion (biggest lift, biggest payoff) — reuse the replay-eval harness.

**The single acceptance gate the pipeline calls:** `cheatsheet-accept.sh <files>` —
stage 1 `lint --gate` (deterministic: structure + provenance + links + evidence-log +
grounding-token) then stage 2 `cheatsheet-content-verify.sh` (LLM: dedup + contradiction +
grounding-resolve). One call, default-fail; lands only if both pass. Built + verified
2026-06-14.

**What remains to fully close the loop:** (3) a provisional tier — auto-content lands
`provisional` and a deterministic `lint` check forbids routing it from a core INDEX until
promoted; (4) eval-gated promotion — the only non-proxy signal, needs a held-out task set
(reuse the replay-eval harness). Both bind to the auto-create pipeline's interface, so they
land with it; the acceptance gate above is the part that exists now and works standalone.

## Known gaps (attack surface, audited 2026-06-14)

Honest accounting — what the gate does NOT yet stop, so nobody trusts it past its reach:

| Gap | Risk | Status / fix |
|-----|------|--------------|
| **Citation truth not resolved** | A well-formed but FAKE `D109999999` or a plausible date passes the deterministic grounding token-check; the LLM stage flags D-numbers as "unverifiable" too (no `meta` call). Grounding = format, not truth. | Open. Fix: `content-verify.sh` resolves D#/S#/T# via `meta phabricator.diff metadata` / `meta sevmanager` and rejects non-resolving cites. Network/auth-dependent. |
| **Only `- **bold**` bullets are grounding-checked** | A rule added as a table row, numbered item, or prose bypasses grounding. | Open. Fix: extend the new-line extraction to table rows that assert rules. Noisy — needs care. |
| **LLM stage not in the commit hook** | The commit hook runs stage 1 only (deterministic) — too slow to run `claude -p` per commit. Everyday commit-path content edits get NO dedup/contradiction check; only the pipeline + on-demand `accept.sh` do. | By design (latency). The auto-create pipeline MUST call `accept.sh`; the harvest cron runs stage 2 on a schedule for human edits. |
| **LLM verdict is non-deterministic** | Same candidate can flake accept/reject across runs; a paraphrased duplicate may slip. Default-reject covers errors, not confident-wrong-accepts. | Mitigate: N-vote panel (majority-reject) for high-stakes promotions; the eval gate is the real backstop. |
| **Bypass tokens** (`[skip-cheatsheet-lint]`, `CHEATSHEET_RULE_OK=1`) | An auto-author could set them to skip the gate. | The pipeline is FORBIDDEN from setting either; enforce in the pipeline runner, and (TODO) reject commits where an `$AGENT`-authored change carries the bypass. |
| **`accept.sh` not yet wired to a write path** | It exists and works standalone, but nothing calls it until the pipeline lands. | Expected — it's the interface the pipeline plugs into. |

## Tooling

| Thing | Path |
|-------|------|
| **Acceptance gate — the pipeline's one call** | `scripts/lint/cheatsheet-accept.sh <files>` (det gate → LLM verify, default-fail) |
| Adversarial content verify (LLM, default-reject) | `scripts/lint/cheatsheet-content-verify.sh` (dedup / contradiction / grounding) |
| Existing-corpus content passes | `lint --audit-grounding` (uncited-rule backlog) · `cheatsheet-dedup-sweep.sh` (clustered dup/contradiction over the tree, drafts findings) |
| Structural audit / gate / autofix | `scripts/lint/lint-cheatsheets.sh` (`--gate`, `--stamp`, `--fix`, `--fix-index`) |
| Commit hook (reactive) | `scripts/hooks/cheatsheet-lint-hook.sh` (wired in `~/.config/sapling/sapling.conf`) |
| Structural sweep (proactive) | `scripts/cron/cheatsheet-sweep.sh` (daily) |
| Harvest cron runner | `scripts/cron/cheatsheet-harvest.sh` (weekly) — authors the Workflow at runtime |

## `run_llm` dispatch — output contract (cron LLM channels)

Building a cron channel that uses `run_llm` (`scripts/lib/llm-dispatch.sh`) to make an LLM
produce structured output? Three non-obvious behaviors, each of which silently broke a
diff-autolearn channel before it was understood (2026-06-17):

- **The output file is the captured FINAL TEXT MESSAGE, not a file the model writes.** Make
  the model PRINT the result block as its final response and parse that. Do NOT tell it to
  "write to $OUT" — its file write lands elsewhere AND its final message becomes a prose
  summary, so your parser sees zero rows.
- **`--allowedTools Read` only — never give `Write`.** An LLM cron session's `Write` reaches
  the REAL repo working copy (the `Failed to mount phabricator CAT` warnings are unrelated to
  filesystem writes). With `Write`, a capable model edits the live cheatsheet directly,
  bypassing your dedup/insert helper. Read-only forces it through your controlled write path.
- **`--model` is stripped** by `strip_model_flag`; the model is chosen by job name via
  `resolve_backend`. Passing `--model haiku` is a no-op — set the job→model mapping instead.

_Last updated: 2026-06-17. Maintainer: dennyzhang._
