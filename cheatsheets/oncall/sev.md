# SEV Firefighting Cheatsheet

Quick reference for the full SEV lifecycle: active response, review preparation, and retrospective impact framing.

## Mode Detection

| Mode | When | Purpose |
|------|------|---------|
| **Active** | Live incident in progress | Triage, communicate, mitigate |
| **Review** | Preparing for SEV review meeting | Generate pointed questions that drive action |
| **Retrospective** | After resolution, for PSC/impact | Quantify your contribution |

---

## Active Mode

### Investigation Paste — 2 Canonical Questions

Every major SEV investigation eventually needs a shareable paste
that answers the same two questions. Use this template directly —
don't reinvent each time. Past worked examples: P2313270537
(S654235), P2313129757 (S654235 brief).

**Q1: Which part of the `<system>` process gets stuck — and why?**

Answer in three layers:

| Layer | What to provide |
|-------|-----------------|
| **Stuck site(s)** | Specific `file:line`, function name, what call. If multiple sites (rank-dependent), list each. |
| **Solid evidence** | Per-rank progress map: which rank logged what at what timestamp. Cite the literal log message verbatim. Include a code window showing the last log + the next missing log (proves the silent gap location). |
| **Root mechanism** | NOT "X calls Y which times out" (that's symptom). Why does Y NOT have a timeout / fail-fast / proper logging? Trace to the design choice that allows the failure mode. Cite codebase rules (`ACR_*.md`) and past SEVs of same class. |

**Q2: Suggested mitigation**

Always provide ALL FOUR tiers — even if one tier is "not applicable":

| Tier | When | Constraints |
|------|------|-------------|
| **Immediate (today, no code)** | Live SEV is bleeding | Must be reversible. Workarounds, traffic shifts, host bumps, blocklists. |
| **Short-term (this week, low-risk diff)** | After bleeding stops | Heartbeat-only / observability-only diffs. No new failure modes. |
| **Medium-term (this month, behavior change)** | After short-term ships | Add fail-fast, timeouts, JK-gated. Requires data from short-term observability. |
| **Long-term (this quarter, structural)** | After medium-term proves out | Sweep sibling sites, eliminate the anti-pattern class, rearchitect if needed. |

For each tier, include:
- Action with file:line refs
- Owner (specific person or oncall name — never "TBD")
- Risk (low / medium / high) with one-line justification
- Expected effect (quantified where possible — "X->Y minutes", "rate-Z events / week")

**Rules:**

- Q1's evidence section MUST include verbatim log/error messages —
  no paraphrasing (per memory `feedback_verbatim_logs_in_drafts`).
- Q1's `file:line` refs MUST be grep-verified before publishing
  (per memory `feedback_verify_line_refs_in_pastes`).
- Q2's "Immediate" tier should fit on 1 row of a table — if it
  needs prose, it's not actually immediate.
- If you can't fill a tier in Q2, write "N/A — <reason>" rather
  than skip it. Empty tier is a smell.

### Mitigation-lever assessment (the Goldilocks gap)

Cherry-picked from imoc `fb-default-sev-report.md` (2026-06-10). Beyond
documenting what was done, assess the full lever landscape — especially
when TTM was driven by mitigation speed, not diagnosis speed:

- **What levers were available?** List every option the team considered,
  not just the one used.
- **Which were rejected, and why?** (too slow, too risky, unknown blast
  radius, "not used in years", team advised against). Rejected levers
  reveal gaps in the toolbox.
- **Was there a Goldilocks gap?** The soft lever (config push, gradual
  rollback) is too slow at SEV pace; the hard lever (force-restart, full
  rollback) is too risky / poorly understood. If **no lever was both fast
  enough AND safe enough**, that's a systemic mitigation gap → file a
  prevention follow-up for the lever that *should* exist.

---

## Review Mode

Generate pointed questions for SEV review meetings. Every question drives toward a concrete action.

### Historical Pattern Mining

Before generating questions, search for similar past SEVs:

```
knowledge_filtered_search(
  doc_types: ["SEV"],
  keywords: "<affected service or failure type>",
  start_creation_time: "<6 months ago>"
)
```

**Without history:** "Should we add monitoring for this failure mode?"
**With history:** "This is the 3rd cache OOM in 4 months. The follow-up from S496098 was 'add memory alerts' — did that ship? If it did, why didn't it fire?"

### Gap Patterns

| Gap | What to Look For | Question Pattern |
|-----|-----------------|-----------------|
| **Detection lag** | Time between failure and alert | "Failure started at X but alert fired at Y. What SLI catches this in <5 min?" |
| **Slow rollback** | Rollback >10 min | "Rollback took X min. What blocked it?" |
| **Repeat failure** | Similar SEV in past 6 months | "This is the Nth [type] SEV. What's the systemic issue?" |
| **Missing SLI** | No SLI fired or fired late | "Our SLI measures X, not Y. Should we add Y?" |
| **Vague root cause** | Abstract description | "Root cause says '[vague].' Which specific code path?" |
| **Unclear blast radius** | Qualitative impact | "How many users exactly? Dashboard available?" |
| **Weak follow-ups** | No owners/dates | "'Improve monitoring' — what metric, what threshold, who, when?" |
| **No error budget** | Budget impact not quantified | "How much error budget did this consume? Still within SLO?" |
| **Manual mitigation** | Human intervention needed | "Can we automate this into a runbook action or self-healing?" |
| **Single point of failure** | One component took down the path | "Why didn't failover work?" |
| **Safety net passed but failure shipped** | Canary/test/alert existed and went green | "The canary passed — what did it measure vs. what broke? A canary that passes is *worse* than none (false confidence)." |
| **Self-masking failure** | Failure corrupts the signal used to detect it | "Did high error volume lag the metric pipeline / crash floods overwhelm log ingestion / alert fatigue suppress the page? The detector was blinded by the thing it was supposed to catch." |

**Safety-net classification (Review Mode, from imoc `fb-default-sev-report.md`):** a layer that *existed but didn't catch this* is **"Partial — existed but failed"**, NOT "No". That's often the more valuable finding — it reveals hidden fragility. For every "Yes/Partial" layer ask: did it actually work? was it self-masking? was it tested under load (steady-state validation can fail when pipelines are under incident pressure)?

### Question Format

```
**Q[N]: [Direct question]**
Context: [1 sentence — why this matters]
Expected answer: [What a good answer looks like]
```

### Always Ask

1. "If this exact failure happens next week, will we detect it faster?"
2. "What's the one change that would have prevented this entirely?"
3. "Which other services have the same pattern and are exposed?"
4. "What's the rollback time right now — is that acceptable?"

---

## Retrospective Mode

For framing SEV contributions in PSC and impact discussions.

### IC Role Classification

| Role | Signals | Frame As |
|------|---------|----------|
| **DRI** | "I was oncall/DRI/led response" | Full MTTD/MTTR story; leadership and decision-making |
| **SME** | "I was called in/diagnosed/identified root cause" | Expertise and MTTD reduction; how your knowledge unblocked the team |
| **Mitigation Implementer** | "I wrote the fix/rolled back/deployed" | Execution speed and MTTR reduction |
| **Follow-Up Owner** | "I built monitoring/wrote runbook" | Preventive impact; future SEVs prevented |
| **Preventive** | "My automation caught it/my monitoring alerted" | Proactive engineering; blast radius reduction |

### Impact Statement Templates

**DRI:**
```
Led response to [SEV-ID] ([severity], [duration], [users affected]),
coordinating [N] engineers across [N] teams. Identified root cause within
[time] and directed mitigation, reducing MTTR by [hours]
(~$[X] avoided revenue loss, [confidence]).
```

**SME:**
```
Diagnosed root cause of [SEV-ID] ([description]) within [time] of being paged,
unblocking mitigation team. Without domain expertise, estimated MTTD would
have been [X] longer (~$[Y] additional impact, [confidence]).
```

**Follow-Up Owner:**
```
Built [prevention mechanism] after [SEV-ID], preventing [N] similar incidents
in [timeframe] ([confidence], based on [evidence]).
Estimated annual savings: $[X] ([confidence]).
```

For impact quantification anti-patterns (credit without contribution, vague impact, missing baseline), see `career/impact-quantifier.md` and `career/anti-patterns.md`.

---

## SEV Triage Discipline (learned 2026-05-20/23)

1. **Verify model_id before locking in.** Opsmate's literal model_id citation is often wrong. Cross-check via `flow_model_type` + `flow_entitlement` + oncall match against the SEV title family before triaging. (Source: S665454 — Opsmate cited m2129246926, actual was m2124122280.)

2. **Search SEV clusters by shared SLI first, title keyword second.** SLI is the cluster backbone (`mrs_ml/v1_instagram / IGR Trunk Stability`). Title keyword search (`umia`, `timeout`) misses siblings with different wording. (Source: S666322/S666413 — title search missed the sibling.)

3. **Operator paste in agent-feed = canonical RCA.** When a SEV's agent-feed contains an operator-written paste URL, that paste overrides Opsmate's automated analysis. Grep agent-feed for paste URLs before locking in root cause. (Source: S665454 — Opsmate said "bloom_index deadlock", operator paste P2341568201 said "CUDA CachingAllocator SIGABRT + D-state hang".)

4. **Parse ALL affected jobs from first SEV chat message.** SEV escalations often list multiple jobs. Parse the full list and triage as a cluster, not just the first one Opsmate cites. `meta sevmanager.chat list --sev=<num> -l 30 --no-truncate` (Source: S665454 — 3 jobs listed, only 1 triaged.)

5. **Read SEV chat via `meta sevmanager.chat list`.** Works when the bot lacks gchat room membership. Returns SEV-specific chat content as text, bypassing the room-membership requirement. (Source: S661645 — gchat URL inaccessible, CLI worked.)

6. **"Zero in last N" is not a valid staleness check.** Compare gap-since-last-event to the model's historical cadence. "0 FULL_SNAPSHOT in last 30 instances" could mean normal (STUS model that publishes FS every 200 instances) or critical (model with 45-min FS cadence that's been silent 19 hours). Always: `gap / normal_cadence` ratio. Ratio > 2x = investigate. (Source: m2130324780 — "0 FS in last 30" classified as THRESHOLD_MISFIT, was actually a 19.5h publish failure.)

7. **Verify baseline before applying holdout-noise heuristic.** Any "holdout is noisy, ignore" classification is only valid when the corresponding baseline is clean. If baseline is ALSO firing, the signal is shared-infra, not holdout-specific noise. Check baseline state first, then decide. (Source: holdout E2E latency alerts — 36% noisy heuristic applied blindly without baseline check.)

8. **Nudge ≠ progress (mechanical-stale vs truly-stale).** A SEV with a recent comment can still be effectively stale. Read the *content* of the last comment: substantive (findings, actions taken, data/links, next steps) → fresh; a nudge or admin noise ("any updates?", "looking", "noted", "will check", a bare attention-ping) → **report as effectively stale** and prioritize it as stale. The body content is the signal, not the timestamp. (This is the content-of-last-comment check; orthogonal to rule #6's cadence-based "0 in last N" check. From imoc `SKILL.md` staleness classification.)

## Merged vs. Triggered SEV intelligence

Cherry-picked from imoc `incident_report_guide.md` §1d-i (2026-06-10).
Two structurally different relationships, two different analyses — only
run when the SEV actually has merged/triggered relations.

**Merged SEVs** (same incident, independently filed by different observers)
amplify **breadth**:
- **Symptom diversity** — each merged SEV captured a different user-visible
  symptom; aggregate them for the *true* blast radius.
- **Detection coverage** — count alert-detected vs. manually-filed. Manual
  filings = alert-coverage gaps. Adopt the earliest-detecting merged SEV's
  alert pattern for the other surfaces.
- **Blast-radius undercount** — if the main SEV claims one surface but
  merged SEVs show three, the main SEV's impact line is incomplete.

**Triggered SEVs** (cascading failures caused by this SEV or its mitigation)
amplify **depth**:
- **Cascade depth** = root + triggered. Depth > 2 → mitigation playbooks
  need review.
- **Cascade duration** = sum of triggered-SEV durations (total damage beyond
  the root).
- **Mitigation safety** — for each triggered SEV, name the mitigation action
  that caused it and the validation that was missing.
- **Root-cause-sufficiency question (the falsifiable one):** *does fixing the
  root cause alone prevent ALL triggered SEVs?* If not, each triggered SEV is
  an **independent fragility** needing its own follow-up. (Maps onto R8
  entity-multiplicity discipline.)

Trap: don't misclassify *triggered* as *merged* — merged = same incident;
triggered = caused by this one or its mitigation. A "merged" SEV that
*started after mitigation began* is actually triggered.

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| "No second alert in the scan → auto-recovered, stop watching." | A quiet scan is not recovery. Confirm with a live 24h CHC / Scuba query (fburl-shortened); close only if the rate is actually healthy. |
| Restart a Hedwig / publisher OOM job to clear it. | Never restart before clearing all 6 channels first — OOM is guaranteed otherwise. Owner: `serving_infra_oncall` (Hedwig/publisher layer); follow its runbook. |

## Reporting to Different Audiences

### SEV chat (debugging audience)
- Reasoning chain: symptom → inference → code confirmation
- Include Scuba links (fburl shortened) for every quantitative claim
- Confirm before asserting — label unverified mechanisms as `[INFERRED]`
- Reference specific code: revision, file, line number

### Workplace post (model owner / XFN audience)
- Title: action-oriented with model name, not bug mechanism
  - Good: "[Action needed] OT job for ig_textpost_feed_u2m_retrieval become zombie - need manual kill and patch the diff"
  - Bad: "[OT triage] S665454 (zombie) — elastic agent hung on error path"
- Tone: professional, not commanding. "Suggested actions" not "What you need to do"
- Content: what's broken → what to do (short-term + long-term) → context link
- No stack traces, no revisions, no Scuba queries — those go in the paste link
- cc the person who needs to act
- Keep it under 15 lines

### Zombie job debugging — lessons from S665454 / S670887

1. **Check reply file vs MAST state first.** Reply file exists + no new attempt = task didn't exit. This one check routes the SEV correctly and would have saved 2 weeks of oncall bouncing in S665454.
   - Script: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/check-zombie-ki001.sh <job> [version]`
   - Fleet scan: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/tools/scan-zombie-fleet.sh`

2. **Reply files persist across attempts.** A recovered job still has old reply files. Always compare reply file timestamp against the current attempt's start time before flagging as zombie. (Source: fleet scan false-positive — flagged 6/7 prod models as zombies, all were old crashes already recovered.)

3. **"Did the elastic agent exit?" — use indirect evidence.** Can't SSH from devserver. Proof chain: no new MAST attempt created despite N retries available → task never exited → elastic agent hung. VipInjector heartbeats prove container alive but not elastic agent specifically.

4. **Diff creation date ≠ land date.** D98638473 created 2026-03-28, landed 2026-05-21. Using creation date led to wrong "fix included" verdict. Always use `meta phabricator.diff describe --number=D<N>` and check the `committed` field.

5. **Verify tool output before extraordinary claims.** If a scan says >50% of fleet is affected, sanity-check a few before reporting.

## See Also

`career/psc.md` (SEV contributions in PSC), `career/slo.md` (error budget), `career/impact-quantifier.md` (quantifying impact), `career/impact-metrics.md`

_Last updated: 2026-06-10. Maintainer: dennyzhang._
