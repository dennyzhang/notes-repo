# 2026-06-01 — OT experts Workplace posts catch-up (week ending 2026-06-01)

_Auto-distilled by `context-ingestor-posts` cron. Source: 1 post from 1/2 active experts in past 7 days (5 in back-off)._

## Highlights (P0/P1 items for OT bot integration)

⚠️ **P1 — Quantified OT reliability efficiency cost (dkotfis, 2026-06-01):** Feed OT models are unhealthy 51.3% of H1 time ($48.8M/year ICE waste); Reels 27.4% ($54.1M/year). This number provides escalation justification for long-running SEVs affecting QE models and is H2 priority-setting context. Bot should cite these numbers when triaging multi-day QE-blocking OT SEVs.

## Per-expert digest

### dkotfis (Dave Kotfis) — 1 post

- **[Examining the Operational Efficiency Impact of OT Reliability](https://fb.workplace.com/groups/256795070510485/permalink/965909769599008/)** (2026-06-01 08:11 PT): H1 analysis quantifying GPU waste from OT reliability issues across Reels/Feed/Threads/Search/Shared/Stories.
  - Methodology: "unhealthy" = days with ≥3 OT app/infra failures (not preemptions/manual stops); non-serving time during those days = wasted ICE.
  - Key numbers:

    | Tenant  | Unhealthy % | Ann ICE$   |
    |---------|-------------|------------|
    | Feed    | 51.3%       | $48.8M     |
    | Reels   | 27.4%       | $54.1M     |
    | Threads | 15.3%       | $3.3M      |
    | Search  | 15.6%       | $520K      |

  - RT comparison: <1% unhealthy days across all surfaces → OT's added component complexity (parallel sidecars, streaming stack) is the quantified root cause.
  - Data query: https://fburl.com/daiquery/p15xvq7q
  - Linked SEVs: S616501, S628346, S654768, S654235, S651642, S669019, S665478, S668980
  - Recommendation: standardize OT reliability SLO requirements for QE launch; track via GPU training efficiency dashboard; drive down waste in H2 to enable more QEs/half or capacity reduction.
  - Tagged: Pushpak Raj Gautam (prgzz), Paul Lu (lupaul), Denny Zhang, Peiyang Yu and others.
  - Bot relevance: **YES** — cite these numbers when escalating multi-day QE-blocking OT SEVs; context for H2 reliability prioritization.

### dennyzhang (Denny Zhang) — 0 new posts

Last processed: 2026-05-26 12:16 PT (oncall summary + MV6 celebration). No new posts since last run.

## Cross-references

- S665478, S669019, S668980 (from this post) are active/recent SEVs already tracked by ot-sev-monitor.
- The "3+ failures/day = unhealthy" definition aligns with how the daily-brief already classifies heavy weeks; this post provides dollar-value framing for those classifications.
- Feed QE model unhealthy 51.3% of H1 → context for why S665478 (Reels LSR MB9 zombies, Day 11+) and similar long-runners are high-priority escalations, not routine noise.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P1 | Add OT efficiency cost context ($48-54M/year) to escalation language in ot-sev-monitor and triage docs | Add 1-line context to failure-patterns.md: "Feed OT ~51% unhealthy H1 → $48.8M ICE/year (dkotfis 2026-06-01)" | 15 min |
| P2 | Link daiquery https://fburl.com/daiquery/p15xvq7q to IG OT SLO dashboard notes | notes/projects/ig-ot-slo-dashboard.md update | 10 min |
| P2 | Track H2 OT reliability SLO standardization discussions (dkotfis recommendation) | No cron change; watch for follow-up posts | — |

## Coverage notes

- **Active this week (2/7):** dennyzhang (0 new), dkotfis (1 new)
- **Back-off (5/7):** lupaul until 2026-06-27 · llu6 until 2026-06-15 · yabinzh until 2026-06-27 · prgzz until 2026-06-27 · peiyangy until 2026-06-27
- **Note:** prgzz (Pushpak) was tagged in dkotfis's post — consider resetting prgzz back-off next week to check for follow-up posts on this thread.
