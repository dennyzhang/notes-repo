# 2026-05-29 — MRS Online Training Oncall catch-up (gchat `spaces/AAQATpEgSyk`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 6 human messages spanning 2026-05-26T10:56 → 2026-05-26T13:56 in **MRS Online Training Oncall** (18 members; primary contributors: Denny Zhang ×4, Paul Lu ×2)._

_Window: 7d delta from 2026-05-23T10:49 (last_msg_create_time). Low-volume week; all messages substantive._

---

## P0 — bot-integration-blocking items

**D-state subprocess = confirmed root cause for S665478 + S665454 (zombie jobs)**:
- pytorch_distributed oncall confirmed: during S665478 (Reels LSR MB9 OT jobs hanging), publishing subprocesses entered **d-state** (uninterruptible sleep), blocking the main thread from cleanly shutting down.
- Symptom signature: job stuck → TW thinks healthy → SJD has no effect → kill does not work.
- Paul flagged potential shared root cause with S665454 (Threads Retrieval U2M OT Jobs stuck). Denny confirmed: "looping MAST and TW team to debug S665454."
- Bot should update the "zombie training job" pattern to include `d-state subprocess in publish path` as a distinct sub-class. This is distinct from P44 GIL hang (pure Python freeze) and elastic-agent hang (TorchElastic/supervisor freeze).
- New triage step: check if publisher subprocesses are in d-state (not just trainer process) before classifying zombie.

**OT oncall resource gap — escalated to management (Michael Chen, Shumin Wu)**:
- Denny made a formal callout: 3-person oncall (down from 5), 15+ SEVs/week, KTLO mode.
- Paul seconded: "3 person oncall is not sustainable. We are in KTLO mode."
- This is context for why systematic improvements are deferred and oncall load is high. Bot should factor this into prioritization recommendations (don't propose large improvement projects as "quick wins").
- WP search link for oncall summary history: https://fb.workplace.com/groups/1084744250286987/search/?q=oncall%20summary&epa=SEARCH_BOX

---

## P1 — significant nuance / sub-mechanisms

**Zombie job taxonomy — 5 sub-causes identified**:
- Denny noted: "Training jobs become zombie — this is a top error pattern. We observed 5 different clauses in this."
- Known confirmed sub-causes so far (from this + prior context):
  1. P44 GIL hang (Python frozen)
  2. Elastic-agent/TorchElastic/supervisor hang
  3. D-state subprocess in publish path (NEW — confirmed this week)
  4. MAST bad-host retry loop (no eviction → job stuck in retry)
  5. (5th unspecified in this chat — likely NCCL-timeout or host-level failure)
- Triage must distinguish sub-cause BEFORE prescribing recovery. All look similar externally (MAST RUNNING + 0 metrics + SJD no effect).

**Dual sparse_delta publish paths — open design question**:
- Denny asked: "How these two publish paths work with each other? If no reconciliation, how the quality assurance of two sparse_delta work?"
- Question was raised but POC has not yet been looped in (as of last message). Reconciliation semantics are unresolved.
- Bot should NOT assume a single canonical sparse_delta path when both paths may be active.

---

## P2 — references / good-to-know

- Oncall shift summary WP group search: https://fb.workplace.com/groups/1084744250286987/search/?q=oncall%20summary&epa=SEARCH_BOX
- S665478 (Reels LSR MB9 OT hanging, Day 11+): d-state publisher subprocess confirmed as root cause direction.
- S665454 (Threads Retrieval U2M stuck): same root cause direction, MAST+TW loop ongoing.

---

## Cross-references

None from this space this week.

---

## Open coordination threads

- **S665454 + S665478 shared root cause investigation**: MAST + TW loop in progress. Denny owning triage. No resolution as of 2026-05-26.
- **Dual sparse_delta path design question**: Denny asked for POC loop-in. Status: POC not yet looped in as of last message. This conversation did not conclude.
- **Oncall headcount escalation**: Denny escalated to Michael Chen + Shumin Wu. No response visible in this space.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | D-state publisher subprocess = new zombie sub-cause | `failure-patterns.md` zombie taxonomy + triage step | 20 min |
| P0 | Zombie taxonomy expanded to 5 sub-causes — document all | `failure-patterns.md` zombie section rewrite | 30 min |
| P1 | Dual sparse_delta paths → do not assume single canonical path | Add caveat to sparse-delta triage | 10 min |
| P2 | Oncall KTLO context — suppress "quick win" improvement suggestions | Add to bot's prioritization guidance | 5 min |
