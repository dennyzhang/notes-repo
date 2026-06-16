# Infra Reliability Practices (from Reliability Engineering group)

Learnings distilled from the `reliabilityeng` Workplace group (read 2026-06-07),
framed as **practices for our lane**: MRS training-infra reliability + the agents
we run (diff-signal cron, OT-bot, auto-review-bot, MyClaw). Each item = the
**signal** RE published + the **practice** we adopt.

> Macro context (the "why now"): AI productivity is driving a SEV surge —
> **SEV0-2 volume +40% YoY, time fighting SEVs +70% YoY (1.7×), SEV ops cost
> 1.3%→2.1% of eng headcount**. Change-failure-rate (SEVs/1k diffs) is at its
> best-ever, but raw change volume (+71% throughput; internal feature diffs
> +160% YoY) swamps it. External business impact is still minimal *only because*
> the surge is internal-heavy + external change-safety is mature. The whole point:
> **harden change-safety for agent-authored changes before this reaches revenue.**
> (Joe Gasperetti "Reliability Warning Signs", 2026-03-26.)
>
> The 3 **2026 Infra Reliability Goals** set the frame: (1) Wicked-Fast Capacity
> Delivery, (2) **Agent-Safe Infra** — "agents operate more reliably than human
> experts", (3) **Twice as Safe, Twice as Fast** — deploy 2× safer AND 2× faster
> (safety must not cost speed). Our agents are squarely inside goal #2.

---

## 1. Agent guardrails: hard-block catastrophic actions (Agent-Safe Infra)
**Signal:** RE+Security shipped Thrift guardrails to 100% of Tier-0 (now Tier-1)
services to block agents from four catastrophic API classes: **mass data
deletion, privilege escalation, destructive fleet-wide ops ("wildfires"),
high-risk control-plane ops.** 60% of Tier-0 services had ≥1 high-risk method.
Real agent SEVs: agent **deleted prod Hive tables** (S627178); AI diffs
**bypassed test failures** → broken Android builds (S634116); **MyClaw posted on
behalf of a user without consent** (S635071).

**Practice (our agents):** the destructive-action blocklist is a first-class
safety contract, not a guideline. Our standing hard-NOs already encode it — keep
them absolute: never land/auto-publish, never `conf ship` w/o Denny, never
`git push`, never `rm -rf`/`chmod +x`, never post to Phabricator/GChat in the
user's voice, read-only on others' docs. Any *new* agent capability gets the
"what's the blast radius if this misfires?" filter first. The MyClaw-without-
consent SEV is our lane — outbound actions need explicit user intent.

## 2. Agent observability: traceable actions, or guardrails are unverifiable
**Signal:** "We deploy guardrails but lack end-to-end visibility to know whether
they work." Push for ContextProp + Artillery distributed tracing on Tier-0/1
services so any agent action → service impact is reconstructable. Without it you
can't assess guardrail efficacy, find coverage gaps, or reconstruct an
agent-triggered incident. (Kunal Mahajan, 2026-04-13.)

**Practice (our crons):** every autonomous action emits a structured, greppable
audit record (we have `~/logs/diff-signal-monitor.log` `audit_log` lines:
`diff= | class= | action= | outcome=`). Treat that as the trace: every
classify/fix/escalate/skip is logged with the *why*, so any bad auto-fix is
reconstructable. New agent behaviors must be observable on day 1, not retrofitted.

## 3. SLI health checks as PRE-PROD change gates (highest-ROI practice)
**Signal:** tuned SLI health checks caught **4 SEVs within <20 days** of
onboarding — each fired on a Conveyor push/canary and blocked/reverted a bad
change *before prod*: a per-request DB `COUNT()` that timed out (SEV2), a
JustKnobs change that raised latency (SEV1/2), a config change that errored RaaS
calls (SEV2). (Joe Romano, 2026-06-05.)

**Practice (our OT detectors):** our publishing-stability / FULL_SNAPSHOT
detectors **are** SLIs. Two rules this validates:
- **Tune to REAL cadence, not by-design defaults** — D107405641 retuned the
  retrieval FULL_SNAPSHOT detector to the real ~77m cadence to stop by-design
  false WARNING/MAJOR pages while keeping real-gap coverage. A noisy detector
  gets ignored → misses the real SEV.
- **Gate vs. alert is a deliberate choice** — gate (block the change) where a
  regression is catchable pre-prod and the SLI is trustworthy; alert-only where
  it isn't. Onboarding an SLI as a *tuned health check* is what turns
  observability into prevention.

## 4. Change safety = canary + phased rollout + health checks; ramp soft→hard
**Signal:** WDB program took change-safety coverage **4%→99%** by adding the
three primitives to 250+ fleet-wide binaries: **canaries, gradual push phases,
update health checks (UHCs)**. Enforcement ramped **soft (warn) → hard
(push-block)** with a leadership risk-review in between. Done at scale by a
purpose-built AI agent, **every diff human-reviewed**. (Nippun Goel, 2026-05-05.)
Canaries demonstrably work: one canary "prevented thousands of services from
crashing" — **≥4 SEV0s and 226 true-positive blocked changes** in 2025.
(Joe Gasperetti, 2025-10-10.)

**Practice (our config/fleet changes):** anything our agents push fleet-wide or
to prod config needs canary + phased rollout + a health check — never a blind
fleet-wide flip. When we add an enforcement gate (like the diff-cheatsheet gate
hook), ramp it: warn/observe first, then hard-block, so we learn false-positives
before they block real work.

## 5. Concentrate review effort on HIGH-RISK diffs
**Signal:** active review time/diff is down **42%**; critical diffs now get
**0.9s/line (was 2.2s)** and **64% have ≤1 comment**. Volume surged 60-70% YoY,
mostly low-risk, but high/critical-risk changes grew too — so each high-risk
change gets *less* scrutiny while more land, and reliability regressed. The ask:
**concentrate review time on high-risk diffs.** (Ben McCary, 2026-06-05.)

**Practice (auto-review-bot):** weight review effort by risk, don't spread it
flat. Deep, adversarial review on high/critical-risk diffs (logic, blast radius,
rollback); light-touch on mechanical/low-risk. **Done** (`ed7f697`): the bot now
derives a risk tier and tags each draft `[RISK:HIGH/MED/LOW]` so high-risk
surfaces first. **The authoritative signal is DRS (Diff Risk Score)** — Meta's
canonical AI-quality guardrail metric (with SEVs/1000 diffs); use DRS when
ai-review-insights is reachable, the size+hot-path proxy is the fallback.

## 6. Measure OUTCOMES, not practices
**Signal:** sort metrics into **practices** (did we do the thing) vs **outcomes**
(did reliability improve). A practice metric is only valuable insofar as it drives
an outcome — don't blindly optimize practices. "SEV count is an indicator; we do
not set goals on SEV count." (Joe Gasperetti, 2026-01-28.)

**Practice (our scorecards):** `cron_fix_scorecard.py` should trend the *outcome*
(reds actually fixed end-to-end / regressions prevented), not just activity
(diffs touched). When reporting confidence, lead with the outcome number, flag
misses, and never optimize a vanity practice-metric.

## 7. The responsible-AI-at-scale template (for any agent we build)
**Signal:** the WDB + guardrails programs share a template: **purpose-built
agent → human-in-the-loop review (or draft-only) → soft-then-hard enforcement →
dashboard tracking the outcome.** (Posts 2, 17.)

**Practice (our agents):** autonomous generation + a human/verify gate
(draft-submit only, verify-green-or-revert, never land) + measured rollout +
a tracked outcome. That's the bar for graduating any new autonomous behavior.

## 8. Flaky / non-deterministic tests poison the change-safety signal
**Signal:** Ads Manager's JestE2E rework cut empty-cache test-failure runs
**15-25% → ~4%** and push-blocking test skips **20-35% → ~3%** — a big reliability
win just from making the test signal deterministic. (Rohan Kamath, 2025-10-08.)
A flaky gate is worse than no gate: it trains everyone to ignore/skip it (the
"AI diffs bypassed test failures" SEV, S634116, is the end state).

**Practice (our lane):** a test that fails the same way across many *unrelated*
diffs (our `ig_reels_tab_*_toy_train_test` broken-on-trunk case) is a
change-safety hole — it makes red meaningless. Detect it (the cron's
`trunk_health` does), and drive it to a fix/quarantine rather than letting every
diff route around it. Don't normalize "ignore the red."

## 9. Review AI-involved SEVs as their own class (MSR AI-Takeovers)
**Signal:** MSR now runs periodic "AI-Takeovers" — SEV reviews focused on
AI-triggered incidents, examining AI-human interaction (who reviewed/tested the
AI change?) and AI-system guardrail gaps (what automation let it through?). AI is
treated as *both* human-like and system-like in the review. (David Pariag,
2025-11-10 / 2026-04.)

**Practice (our OT-bot triage):** when an incident's triggering change was
agent-authored, explicitly ask the AI-takeover questions — was there human review,
did a guardrail gap let it through, is the fix a guardrail (removes the class) or
a patch (fixes the instance)? Feeds the IC7 "category vs instance" filter.

---

## Foundational practices (durable fundamentals, from 2024-25 RE posts)

- **Drive down % Non-Actioned Alerts.** RPMM tracks **% of non-actioned MAJOR
  and CRITICAL alerts** as an observability-quality metric. A by-design false
  page is a non-actioned alert. **Directly our OT-detector problem** — D107405641
  retuned the FULL_SNAPSHOT detector precisely to kill by-design false
  WARNING/MAJOR pages. Treat every recurring non-actioned page as a tuning bug.
  (RPMM refresh, 2025-02-13.)
- **Every SEV maps to an SLI (SEV↔SLI linkage).** Infra tracks the % of SEVs
  linked to an SLI (31%→46% in 2024-Q3). If an incident has no owning SLI/detector,
  that's a measurement gap to close. Our OT detectors *are* those SLIs — keep
  coverage honest. (Infra Reliability Reports, 2024.)
- **Optimize TDM (Time from Detection→Mitigation), not just prevention.** RE's
  SEV-analysis sprints hunt levers to shrink detection→mitigation time. For the
  OT-bot: fast, correct triage + a ready mitigation/runbook beats only-prevent.
  (SEV Analysis Sprint, 2025-07-21.)
- **Service Criticality → tier-appropriate requirements.** Decide each service's
  criticality; each level has a defined requirement set. Know which tier our
  MRS/OT training + serving paths sit in and meet that tier's bar. (Joe Romano,
  2025-02-18.)
- **DRS + SEVs/1000-diffs are the canonical AI-quality guardrail metrics** —
  the authoritative risk signal (see #5). Track our agents' output against them.
  (AI Guardrail Tracking Metrics, 2025-09-12.)
- **Change-safety is THE lever** — unsafe code/config changes are the *majority*
  of SEVs; only ~40% of engineers felt confident in their change-safety process
  (Change Safety 101 exists to close that). Reinforces practices #1/#4. (2024-11.)
- **Code deployment is the #1 SEV trigger** — 36% of SEV0-2s (911 of 2503 in
  2023), now *above* config changes. Diff/change safety is the single
  highest-leverage reliability investment — exactly where our agents operate.
  ("Worst SEVs of 2023".)
- **Auto-canary opt-out is an explicit high-risk marker.** The Config Safety
  Burndown migrated 1,900 call sites off the unsafe-opt-out API; the ~200
  remaining `AutoCanaryRequirements` opt-outs are tracked as high-risk. This is
  one of the diff eligibility tokens (see `diff/common.md`) — a diff that opts
  out of canary/safety is high-risk by definition. (2024-01.)
- **Oncall health is a reliability dimension** — 85% of Infra devs report oncall
  burden (alert volume, unclear guidelines). Canonical resource: the *Improve
  Oncall Health* wiki. Drives the same goal as "% non-actioned alerts": fewer,
  actionable pages. (2023-12.)
- **Overload protection / graceful degradation** — overload was a top SEV class;
  services should shed load gracefully under pressure (e.g. CPUConcurrencyController
  token-bucket, not probabilistic shedding). For our serving/training paths: a
  pathological model/input must not take the whole run down — bound it, degrade,
  don't crash. (Overload Infra Goal, 2022.)
- **Test your recovery / rollback paths before you need them** — DR exercises in
  a Recovery Environment validate runbooks against life-like scenarios (and catch
  bugs in the runbook itself). For our agents: verify-or-revert isn't enough —
  periodically confirm the revert actually works. (Recovery exercises, 2022.)
- **SEV-process health: complete follow-ups, detect fast, review every SEV.** The
  three durable SEV metrics: Critical SEV Task Completion Rate, Median Time-to-
  Detection, % SEVs Reviewed (RE's founding-era focus, 2019, was literally
  "track + complete SEV follow-ups"). Our distillation/learning loop *is* "%
  reviewed + follow-ups" — keep it honest. (2022-04 / 2019.)
- **Service dependency management** — a large dependency matrix erodes time-to-
  detect/mitigate; visibility into deps (SALT) is a reliability investment. MRS/OT
  training has many upstream deps — know them. (2022-07.)

---

### Reference frameworks (for self-assessment)
- **RPMM** (Reliability Program Maturity Model) — self-assess posture across
  Dependency Protection, Service Capacity, Testing & Release / Change Safety in
  Production Matrix Guidance Explorer. (Mert Yazicioglu, 2025-12-12.)
- **SEV Ops Cost metric** — standardized reactive-ops-cost-of-SEVs (% eng
  headcount), deep-dive by manager/pillar/individual SEV. The canonical *outcome*
  measure + cost framing for reliability work (useful for PSC/impact framing).
  (Kelsey Jiang / Aneta Baloyan, 2025-11 / 2025-12.)

---

_Source: `reliabilityeng` Workplace group. Refresh when RE posts a new
warning-signs / change-safety update. Sibling: `cheatsheets/diff/`,
`cheatsheets/oncall/`._

_Last updated: 2026-06-07. Maintainer: dennyzhang._
