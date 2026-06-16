# 2026-05-29 — OT experts Workplace posts catch-up (week ending 2026-05-29)

_Auto-distilled by `context-ingestor-posts` cron. Source: 5 posts from 2/7 experts in past 7 days (4 dennyzhang, 1 dkotfis). llu6 in back-off. lupaul/yabinzh/prgzz/peiyangy: 0 relevant posts this week → backed off 28d._

---

## Highlights (P0/P1 items for OT bot integration)

- **P0 — Bot triage dark all week:** `triage_events=0` for the full mrs_online_training shift (5/19–5/26). ot-alert-monitor, ot-sev-monitor, ot-post-monitor health suspect. Handoff item from Denny to Paul Lu. → _Should trigger ot-alert-monitor self-check in heartbeat._
- **P1 — Training zombie detection gap:** P44/P45-class hangs invisible to SJD (process alive, Python frozen). Hit S665478 (14h gap on Threads U2M) + S665454. Denny proposed mvai_metrics staleness SJD rule. → _Update failure-patterns.md: zombie SJD gap pattern._
- **P1 — DPP 20-day restart causes ~280 non-actionable alerts/half:** All OT models affected. DPP team (`dpp_distributed_data_reading`) looped in for graceful session rotation. If adopted, eliminates the bulk of OT example-age noise. → _Do NOT page oncall on DPP restart pattern (self-recovers, check log string "This restart is necessary")._
- **P1 — Reels ESR Sparse Latency further regression to 0.0%:** S651765, MB6.5 not yet launched. Pushpak resolving QPS cap + streaming setting issues. May need to bump 15→18 H100 training hosts on prod job. → _Monitor S651765 resolution._
- **P1 — Feed LSR Sparse Latency at 20.8%:** S659917, QE ongoing with ~2 weeks data. Launch decision expected this week; next step: incorporate into MB8 LC.

---

## Per-expert digest

### dennyzhang (Denny Zhang) — 4 posts (1 filtered: personal)

- **[Oncall Summary mrs_online_training: 20 May–26 May](https://fb.workplace.com/groups/mrs.ot/permalink/1335147105246699/)** (2026-05-26):
  Full shift writeup. 23 SEVs touched (7 high-touch). Heavy week dominated by training job zombie pattern (S665478+S665454) and DPP restart investigation.
  - Key pain points: zombie hang (SJD blind), DPP restart noise (~280 alerts/half), CFR conveyor fragility (3 failures in one shift), bot triage dark.
  - Impact: 2 UBN alerts permanently eliminated (D106194663, D105890355); 12 new sub-mechanisms added to failure-patterns.md; DPP graceful rotation proposed to team.
  - Handoff to lupaul (incoming oncall): S667687+S667668 (Gloo/DistStore publish hang, andrewxmao bisecting); S665478 fix stack blocked on light_cli rebuild; bot triage dark P0; S665214 L3 9d open (no mitigation).
  - Linked: S667567 S665454 S666451 S666546 S665902 S667668 S665478 S667687 S667572 S667332 S665214 S666880 D106022977 D106022978 D106197380 D106194663 D106193584 D106195444 T272684080 T272679108

- **[FBR IFU I2I model 2132070936 missing FULL_SNAPSHOT 8+ hours](https://fb.workplace.com/groups/mrs.ot/permalink/1332867342141342/)** (2026-05-23):
  P44 hang on reranker 2125081901 (SIGSEGV rank7 → elastic-agent D-state → no checkpoint progress since 04:27 PDT). Blocked downstream 2132070936 FULL_SNAPSHOT 8h. Manual kill + TMS restart resolved.
  - Bot relevance: yes — confirms P44/elastic-agent disambiguation gotcha; updates zombie detection guidance. SEV S667567, paste P2349062759.
  - Linked: S667567 T272684080

- **[~280 non-actionable example-age dips — planned DPP restarts](https://fb.workplace.com/groups/mrs.ot/permalink/1332798372148239/)** (2026-05-23):
  Every ~20 days DPP auto-restarts each OT job's data session → training pauses, example age spikes, UBN/SEV fires. Self-recovers. Log signature: `"This restart is necessary to prevent the session from running in bad state."` Investigation: P2349020385, SEV S667544.
  - Bot relevance: yes — high-value false-alarm suppression candidate. Pattern should go in failure-patterns.md.
  - Linked: S667544 P2349020385

- **[Threads U2M retrieval trainer stuck 14h — nobody noticed until manual kill](https://fb.workplace.com/groups/mrs.ot/permalink/1332046782223398/)** (2026-05-22):
  Model 2124122280, S665454. MAST=RUNNING, Python frozen, no alert fired for 14h. Denny raising question: should mvai_metrics staleness check be added to SJD/TMS?
  - Bot relevance: yes — zombie detection pattern. Key triage signal: last mvai_metrics sample time vs wall-clock gap.
  - Linked: S665454 P2347911341

### dkotfis (Dave Kotfis) — 1 post

- **[OT Reliability – Weekly Status 5/26](https://fb.workplace.com/groups/1676744619923718/permalink/2051317135799796/)** (2026-05-26):
  Weekly IG OT SLO status post in IG Relevance Reliability Working Group (14 reactions, 4 comments).
  - **Recovered this week:** Feed U2I Retrieval Sparse Latency (S664657, A100→H100 host change fixed daily example-age peaks); Reels StarSearch T2I Sparse Streaming Success (streaming client buffer 10→40GB, D105840367).
  - **Still open risks:**
    - S659917 Feed LSR Sparse Latency at 20.8% — QE ongoing, MB8 LC next step.
    - S651765 Reels ESR Sparse Latency at 0.0% (further regression from MB6.5 not launched). May need 15→18 H100 hosts on prod job if further delays.
    - S656663 Reels CS Omni Retrieval Sparse Latency at 75%.
  - **Pending launches (SLO-blocking):** Feed T2I Item Streaming; Mixed IFR U2I Decoupled Full Snapshot; Reels SS Omni Weight Manager on MB5; Reels VM ESR Sparse Streaming.
  - Bot relevance: yes — Reels ESR regression + Feed LSR risk directly affect ot-daily-learning context. Reels ESR host-increase decision may surface as OT job config change.
  - Linked: S664657 S656663 S659917 S651765 D105840367

### lupaul (Paul Lu) — 0 posts (API returned 0 · back-off 28d until ~2026-06-26)

_Note: lupaul is incoming oncall as of 5/26. Absence likely due to shift transition, not inactivity._

### llu6 (Li Lu) — skipped (in back-off until ~2026-06-15)

### yabinzh (Yabin Zhang) — 0 posts (API returned 0 · back-off 28d until ~2026-06-26)

### prgzz (Pushpak Raj Gautam) — 0 OT-relevant posts (1 non-work post filtered · back-off 28d until ~2026-06-26)

_Filtered: user account support question in non-OT group ("User Account Access – Questions & Feedback"). Not OT-relevant._

### peiyangy (Peiyang Yu) — 0 posts (API returned 0 · back-off 28d until ~2026-06-26)

---

## Cross-references

- S665478 (Reels LSR MB9 hang, L3): fix stack D106022977–D106022978 from lupaul blocked on light_cli rebuild — still open per 5/26 handoff. Active blocker per team_context.
- S667668 / S667687 (CFR DistStore + IFR Gloo publish, L4): andrewxmao bisecting as of handoff — these are the IFR-ESR MC4 cascade blockers in current team CLAUDE.md.
- S620631 (I2I MC3 108d): not mentioned in any post this week — no new context.
- Bot triage dark (triage_events=0): dennyzhang explicitly called this out as handoff item #3. Cross-confirms that monitor cron health issue is known to the team.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Bot triage dark — ot-alert/sev/post-monitor health check | Add heartbeat self-check step | 30 min |
| P1 | DPP 20-day restart: false-alarm suppression rule | Add to failure-patterns.md + triage prompt | 1h |
| P1 | Zombie detection: mvai_metrics staleness gap pattern | Update failure-patterns.md P44 section | 30 min |
| P1 | Reels ESR 0.0% SLO risk — host increase may surface | Monitor S651765, update IG OT SLO context | 15 min |
| P2 | Feed LSR MB8 LC decision pending | Watch S659917, update dkotfis context next week | 15 min |
| P2 | CFR conveyor fragility (3 failure modes in one shift) | Propose conveyor health dashboard note in context | 20 min |

---

## Coverage notes

- 2/7 experts posted relevant content. 4 backed off until ~2026-06-26 (lupaul, yabinzh, prgzz, peiyangy). llu6 backed off until ~2026-06-15.
- lupaul back-off flag noted but expected — just took over oncall. Consider suspending back-off logic for incoming oncall week.
- prgzz only post was a personal support question — OT debug guides/SEV tracker not posted this week. May have shifted to gchat-only.
- Consider adding: andrewxmao (active on CFR DistStore + IFR Gloo SEVs), xingjiama (S665478 Reels LSR MB9), yzqian (CFR conveyor) to watch list.
