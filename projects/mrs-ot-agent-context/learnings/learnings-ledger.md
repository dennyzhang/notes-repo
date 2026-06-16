
## 2026-06-04 — P61 CANDIDATE: OT zombie job — exit_w_cleanup only on success path

- **Proposed PID:** P61
- **Sample count:** 2 (S628346, S665454) — below ≥3 threshold; promote when 3rd occurrence confirmed
- **Name:** OT zombie job — exit_w_cleanup only on success path
- **Stage:** T2
- **Symptoms:** rank crash (CUDACachingAllocator/SIGABRT) → EA catches ChildFailedError → main() falls through to Python shutdown → NCCL thread join blocks on dead rank → job stuck RUNNING despite retries available; MAST never reads reply file
- **Fix:** D98638473 (try/except → exit_w_cleanup → os._exit on error path in light.py)
- **Falsifier:** `meta ai.mast-job metadata --name=mvai-training-online-<ID> | grep attempt` — if FAILED attempts exist (not just RUNNING), exit_w_cleanup WAS called; rule out this pattern
- **Owner:** mvai/light_cli
- **Sources:** S628346 (L3, Feb-Apr 2026, 4 model IDs), S665454 (L3, May-Jun 2026, Threads Retrieval U2M)

## 2026-06-10 — CANDIDATE: synchronized RUNNING-but-0/low-QPS = shared upstream (scribe/DPP) drain

- **Sample count:** 1 (S674219) — below ≥3 threshold; promote if it recurs
- **Stage:** T1 (was SEV1)
- **Symptoms:** many independent OT jobs across orgs (IG + Threads, LSR/ESR/Retrieval) drop to 0/low QPS within the same minute, all staying **MAST RUNNING** (not DEAD/PENDING — so distinct from P10).
- **CONFIRMED root cause:** **EAG/DR scribe drain** → all jobs reading from EAG scribe got ~0 DPP ingress (DPP saw **~75% drop in scribe token ingress**, `dpp_stats_v2`). Tracked S674227; mitigated by **D94521578** (undrain EAG scribe/ws). DPP starvation was REAL.
- **Discriminators:** (a) a per-job hang cannot synchronize → a SHARED dependency is the cause; (b) check the data-side FIRST — per-mast-job DPP starvation ODS (`fburl.com/canvas/pzoyunzx`) + scribe token ingress (`dpp_stats_v2`); (c) **caution on two early red herrings that cost time here:** host-preemption S674182 (concurrent, NOT the root) and a single healthy output-queue snapshot on job 2144239965 (looked fed during a real fleet starvation). Restart-required recovery was also misread as "wedged not data" — restart re-pointed jobs to recovered scribe, it did not prove a non-data cause.
- **Route:** DPP/scribe oncall, with the per-job ODS + scribe-ingress Scuba as evidence. (`mast_scheduler` only if DPP ingress is healthy.)
- **Sources:** S674219 (RCA: "75% regression in DPP Online Training ingress due to EAG scribe drain"), S674227, D94521578 (2026-06-10)

## 2026-06-10 — CANDIDATE: SJD coverage unevenness + low-positive-QPS blind spot (3-way split)

- **Sample count:** 1 (S674219) — candidate; this is the recurring SJD-blindness theme (see also mast-debugging §SJD), now split into 3 distinct gaps with different owners/fixes:
- **Case A — SJD should fire but didn't ("works for some jobs, not others"):** likely **per-model SJD config override** (models override fleet-default stuck-thresholds / timeouts / auto-restart). Action: diff SJD config of a fired-vs-not-fired job; audit + normalize overrides across OT-critical fleet. Owner: MVAI/SJD.
- **Case B — SJD fires but kill/restart is slow:** long pole is usually the process **not exiting** (P61 clean-exit, base layer ≥ D98638473; P21 EA exit-code bug), not detection. Metric to drive down: **SJD-detect → next-attempt-RUNNING latency**. Owner: MVAI/light_cli.
- **Case C — alive at ~3k QPS (positive but degraded):** NOT an SJD job (making progress ⇒ not "stuck"). Needs a **separate baseline-relative throughput monitor** (QPS << job's own baseline for N min). Owner: MVAI monitoring.
- **Do NOT conflate** — each case routes a different fix to a different owner.
- **Sources:** S674219 thread NgHrfRuoVmw (Max Kaplan / Denny Zhang, 2026-06-10)

## 2026-06-10 — P64 CANDIDATE: UMM SQL transaction failure during OT publish

- **Proposed PID:** P64 (distillation proposed as a LANDED P-row 2026-06-10; routed to ledger instead — 1 distinct incident, below the loop's ≥3 invariant)
- **Sample count:** 1 (S670344 root-cause #4, which IS S673089) — below ≥3 threshold; promote when 2 more independent occurrences confirmed
- **Name:** UMM SQL txn failure during OT publish
- **Stage:** T3
- **Symptoms:** OT job crashes at snapshot tagging — "Cannot commit invalid transaction. Connection to SQL not yet established." in UMM/AMS layer; model registration fails; multiple jobs affected simultaneously
- **Fix:** identify + revert bad AMS/UMM change; retry OT publish; cross-check with ai_metadata oncall (S673089 pattern)
- **Falsifier:** `meta sevmanager.sev list --tags=ai-metadata-incident --created-after="2h ago"` — if no active AMS/UMM incident, look elsewhere for root cause
- **Owner:** ai_metadata oncall
- **Sources:** S670344 (L3, 2026-06-10; root-cause #4 = UMM SQL conn failure Jun 8, reverted via S673089)

## 2026-06-11 — CANDIDATE: enforcement-layering — a code-hook fed by a skippable input is still skippable

- **Sample count:** 1 (Code-Mitigation Auto-Fix Gate, thread dC5krNkcMXE) — candidate; promote to a P-row / agent-design principle at ≥3.
- **Lesson:** when fixing a recurring agent LAG/SKIP (a prose expectation the agent drops under task focus), the fix escalation ladder is **prose → reconcile-assert → code-hook → external re-derivation**. A code-hook (e.g. `record-triage-event.sh` flagging MISSING) is only un-skippable if its INPUT is un-skippable. If the hook depends on a flag the same skipping agent must remember to pass (`--class`), the agent can skip the flag too → the hook silently sees nothing. **The terminal backstop must RE-DERIVE the trigger condition from ground truth independently** (re-read the source item + re-classify), never trust a value the lagging path was supposed to supply.
- **Applies to:** any "the agent was supposed to do X but lagged" fix — auto-fix-task filing, substrate writes, validator spawns, tag application. Don't declare a lag fixed at the code-hook layer if the hook is fed by prose.
- **Sources:** Code-Mitigation Auto-Fix Gate build 2026-06-11 (record-triage-event.sh + 3 monitors); generalizes [[recurrence-root-fix-not-prose]].

## 2026-06-13: q-and-a leak dominant across 3+ days (self-audit)

**Candidate pattern (threshold: ≥3 days, met).**

Observation: `q-and-a` is the largest leak kind on 3 of 5 audited days
(2026-06-09: 17, 2026-06-10: 11, 2026-06-13: 3). Root mechanism: bot is
replying to `!ot-bot` @mentions in the team space `spaces/AAQA2bZMw24`
with design help, debugging answers, and Q&A — work that belongs in the
operator's 1:1. The CLAUDE.md Phase 2 rule ("reply only when @mentioned
with !ot-bot AND payload matches a declared lane") intends to gate this,
but the lane-match is too permissive for general design Q&A.

Root: bot responds to `!ot-bot` in team space even when the content is
operator↔bot dialogue, not a shared OT incident. The mention is in team
space → reply goes to team space.

**Fix direction:** CLAUDE.md already forbids this (reply should be 1:1 or
silent for Q&A). T275142534 hard delivery gate is the structural fix. Until
it lands, every `!ot-bot` reply in team space should be silently proxied to
the operator's 1:1 (`spaces/AAQAVOjYc80`) — not posted in-thread to the
team space.

**Promotion criteria:** if q-and-a appears ≥3 more days, draft a concrete
cron-prompt amendment to redirect `!ot-bot` Q&A replies from team space to
1:1 proxy.

## 2026-06-13 candidate (n=1) — checkpoint-restore fail: check existing checkpoints BEFORE recommending re-create
Trigger: `ModelStoreDBRecordNotFound: Checkpoint <EID>:-1` churn after an MRB/SEV reset (e.g. 2137792444 / W1350388963722513, S675238). Lesson: the reset wipes the **resume POINTER**, not the checkpoint blobs — valid checkpoints often still exist (2137792444 had v1987 today, 678GB, anchor). Triage MUST run `get_last_n_checkpoint_metadata(<EID>)` before prescribing a fix: if valid checkpoints exist → the fix is **repoint the resume target at the latest valid checkpoint**, NOT "re-create the -1 record" and NOT cold-create (cold-create discards trained state + serves a random retrieval model). Systemic (upstream): restore logic should FALL BACK to latest-valid on a missing pointer instead of churning on `-1 not found`; MRB tool should atomically re-init the resume pointer when it clears TMS. Promote to a P-row at ≥3 MRB-reset checkpoint cases. Source: thread Nk_Ui4WFn4U.

**2026-06-15 update:** 1/2 bot msgs leaked (50%). Leak was `plumbing` (bot routing-analysis via Meta Bot sender, `3oWHmy4A_MY.9U1qz1L7hV8`). Counter: 4 of 7 audited days with leaks. T275142534 gate still pending. *Detector gap found:* Jun 14 audit missed this leak because it scanned only Denny-sender (100051448831249) as bot-authored — the Meta Bot sender (886676667858092, used by `--as-meta-bot`) was invisible. Current audit corrects this. Promotion criteria still at "≥3 more days"; today = 1 of 3 needed.
