# 2026-06-08 — OT experts Workplace posts catch-up (week ending 2026-06-08)

_Auto-distilled by `context-ingestor-posts` cron. Source: 5 posts from 2/7 experts in past 7 days. 5 experts in back-off._

## Highlights (P0/P1 items for OT bot integration)

### P0 — CUDACachingAllocator zombie recurrence pattern (2 instances, same root cause)

Two ig_textpost_feed_u2m_retrieval jobs (models 2124793203 on 6/3, 2124428748 on 6/6) hit the same pattern:
worker CUDACachingAllocator INTERNAL ASSERT FAILED → SIGABRT → base-layer bug prevents clean exit → MAST shows RUNNING, training QPS=0, no retry despite 100 retries configured.
Same root cause as S665454 and S670887. Fix: kill job + upgrade base layer past D98638473 (light_cli:5308 and :5315 both predate it).

**Bot action:** Add this to `known-patterns.md` as a distinct class. When ot-fleet-health or ot-sev-monitor sees a zombie MAST job (QPS=0, RUNNING), probe base-layer version against D98638473 cutoff before classifying root cause.

### P1 — Shift-left WARNING tiers live across 5 MRS OT alert families

Denny's 6/2 PE MRS ML FYI post confirms WARNING tiers now deployed (60+ models). Agent wiring already updated in ot-alert-monitor (polls CRITICAL+MAJOR+WARNING). No cron-prompt change needed; affirm in ot-alert-monitor context that WARNING processing is intentional and load-bearing.

Diffs landed: D106755615 (publishing stability), D106903024 (IFR Watchtower), D107277546 (Scribe example age), D107283156 (VideoFM scribe example age), D107283032 (trunk stability).

### P1 — IG: Feed LSR sparse latency SEV (S659917) at 54.2% — H1 freshness SLO at risk

From dkotfis 6/2 weekly: QPS Cap + Upsample Data approach shows positive TS metrics. Risk: MB8 LC launch may preempt QPS Cap fix and regress SLO again before code freeze. Tracking via dkotfis weekly. Not directly MRS-actionable but relevant to cross-org OT freshness SLO context.

---

## Per-expert digest

### dennyzhang (Denny Zhang) — 4 posts

- **[[Action needed] OT job for ig_textpost_feed_u2m_retrieval (Threads) zombie — needs manual kill + base-layer patch](https://fb.workplace.com/groups/mrs.ot/permalink/1344542434307166/)** (2026-06-06, mrs.ot): Model 2124428748, MAST mvai-training-online-2124428748. Rank 6 hit CUDACachingAllocator INTERNAL ASSERT at cpp:3316 → stuck zombie. Tier-3 model. Base layer light_cli:5315 predates fix.
  - Linked: D98638473, S665454, S670887
  - Bot relevance: **yes** — third instance of same pattern; add to known-patterns.md; ot-fleet-health should check base-layer version for zombie classification

- **[[Action needed] OT job for ig_textpost_feed_u2m_retrieval zombie — needs manual kill and patch](https://fb.workplace.com/groups/mrs.ot/permalink/1342215704539839/)** (2026-06-03, mrs.ot): Model 2124793203, MAST mvai-training-online-2124793203. Same CUDACachingAllocator root cause. light_cli:5308 predates fix.
  - Linked: D98638473, S665454, S670887, P2362425568
  - Bot relevance: **yes** — second instance this week; confirms recurrence pattern

- **[Shift-Left Triage: Early-Warning OT Oncall Alerts](https://fb.workplace.com/groups/4239452842845159/permalink/24952837091080098/)** (2026-06-02, PE MRS ML FYI): WARNING tiers added to 5 alert families; agent wired to poll WARNING for autonomous pre-page triage. ~80min–2h head-start. Targets: ≥30% fewer MAJOR pages, ≤5min MTTD.
  - Linked: D106755615, D106903024, D107277546, D107283156, D107283032
  - Bot relevance: **yes** — confirms ot-alert-monitor WARNING polling is live and intentional; measurement plan needs tracking

- **[[OT triage] mvai-training-online-2125752019 (IFR Main MTML) — scribe example age spike + NCCL zombie at 08:10 PT](https://fb.workplace.com/groups/mrs.ot/permalink/1341029697991773/)** (2026-06-02, mrs.ot): Model 2125752019. Two-phase failure: scribe example age spike 05:15–06:34 PT (auto-resolved), then NCCL watchdog stall at 08:10 PT (QPS=0). Likely Hedwig publisher RECV_TIMEOUT at 07:24 PT triggered stall.
  - Linked: none (Everpaste link only)
  - Bot relevance: **yes** — Hedwig RECV_TIMEOUT → NCCL stall chain; enrich Hedwig timeout pattern in known-patterns.md

### dkotfis (Dave Kotfis) — 1 post

- **[OT Reliability - Weekly Status 6/2](https://fb.workplace.com/groups/1676744619923718/permalink/2057653955166114/)** (2026-06-02, IG Relevance Reliability Working Group): Sparse streaming passing SLO on all IG models for first time in same week. Feed LSR S659917 still at 54.2% sparse latency — H1 freshness SLO risk. QPS Cap + Upsample Data is viable but MB8 LC launch may preempt it before code freeze.
  - Active SEVs: S669019 (Reels LSR MB9 OOMs), S667222 (Feed LSR MB8 low streaming success), S665478 (Reels LSR MB9 hanging), S662798 (Feed LSR MB8 slow QPS ramp-up), S668980 (Reels ESR MB7 abnormal training QPS)
  - Bot relevance: **context** — IG OT freshness SLO status for fleet-health context; S669019/S665478 (OOM+hanging) patterns may recur on MRS models

---

## Cross-references

- **D98638473** (base-layer CUDACachingAllocator fix): referenced in both zombie posts; not yet adopted by ig_textpost_feed_u2m_retrieval models. ot-fleet-health should flag models on light_cli versions predating this diff.
- **S665454 + S670887**: prior instances of same zombie pattern; confirms CL-pattern (3+ incidents = codified rule per distillation threshold).
- **Shift-left diffs (D106755615 + 4 siblings)**: confirm WARNING-tier deployment is complete across MRS OT; no open gaps in alert-family coverage.
- **S659917** (Feed LSR sparse latency): active IG SEV, no MRS action needed but monitor for cross-org coordination asks.

---

## Integration priority table

| Priority | Item | Cron prompt / pattern change | Time est |
|---|---|---|---|
| P0 | Add CUDACachingAllocator + base-layer zombie class to known-patterns.md | known-patterns.md new entry; ot-fleet-health probe base-layer version in zombie classification | 30 min |
| P1 | Confirm ot-alert-monitor WARNING polling is documented in SKILL.md | SKILL.md update (1 line) | 5 min |
| P1 | Add Hedwig RECV_TIMEOUT → NCCL stall chain to known-patterns.md | known-patterns.md append to existing Hedwig section | 20 min |
| P2 | Track shift-left measurement metrics (MAJOR page reduction ≥30%, MTTD ≤5min) | Add to ot-perf-regression-watch or weekly brief | 15 min |
| P2 | IG OT: monitor S659917 for code-freeze resolution; surface in dkotfis weekly digest | No prompt change; context-only | — |

---

## Coverage notes

- **lupaul**: back-off until 2026-06-27 (no posts in prior 28-day window)
- **llu6**: back-off until 2026-06-15
- **yabinzh**: back-off until 2026-06-27
- **prgzz**: back-off until 2026-06-27
- **peiyangy**: back-off until 2026-06-27
- **New experts to consider**: Justin Lin (mentioned in S659917 Feed LSR work), Josef Cohen (Reels StarSearch latency investigation per dkotfis post)
