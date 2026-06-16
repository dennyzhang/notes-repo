# 2026-06-13 — OT experts Workplace posts catch-up (week ending 2026-06-13)

_Auto-distilled by `ot-ingest-posts` cron. Source: 6 posts from 3/7 experts in past 14 days (delta since last run 2026-06-11)._

---

## Highlights (P0/P1 items for OT bot integration)

**P0 — failure-patterns.md update needed:**

1. **Python 3.12 OOM = known failure class for in-trainer publishing jobs** (lupaul, S669019, Jun 11)
   - Root cause: light_cli built after Apr 24 uses Python 3.12 (upgraded from 3.10). Python 3.12 introduces a memory leak in the DeltaPublisher path → RSS climbs → OOM after 40+ hrs.
   - Scope: any OT job with `in_trainer_publishing=True` + `light_cli` version built after 2026-04-24.
   - Mitigation: rebuild light_cli with Python 3.10. Doc: https://docs.google.com/document/d/1Nf13iSjWG3TZnGKJz4Ec9vcJxjwSGsH7IgoN2wx6vJk/edit?tab=t.0
   - **Bot triage rule to add:** when OT job OOMs after 40+ hrs + in-trainer publishing → check light_cli build date vs Apr 24. If post-Apr-24, Python 3.12 OOM is likely root cause. → S669019 pattern.

2. **Dynamic Resizing causes ~6min training interruptions (expected, not a failure)** (prgzz, Jun 10)
   - TMS switches trainer count presets ~2×/day (scale-up before peak, scale-down after). Each switch = MAST in-place restart → ~6 min downtime → QPS drops to 0 then recovers.
   - **Bot triage rule to add:** QPS drop → recovery in ~6 min, no error logs, no NCCL failure → check if model is enrolled in Dynamic Resizing (TMS preset switcher). Not a bug; expected behavior.
   - Affects: models onboarded to Dynamic Resizing (currently IG, Ads QRT models in rollout; Q3 expansion planned).

**P1 — context updates:**

3. **DeltaPublisher memory optimization diffs in flight** (lupaul, oncall summary May 26–Jun 2): D106873157 (`malloc_trim` after `gc.collect()`), D106873156 (explicit `del` of `_last_embedding_cpu_copy`), D106873154 (free unquantized rows after quantization), D106873155 (release tensor data per-FQN after write). All unpublished as of Jun 2; track landing for S669019 resolution path.

4. **IG/Threads OT vs offline GPU quota split Phase 2: Reels + Feed covered** (prgzz, Jun 8): Separate `T20_GRAND_TETON_ONLINE` / `T20_GTV1_5_B200_..._ONLINE` tenants for OT. MAST auto-routes by job type. Impact: quota pressure on OT tenants is now explicit; capacity disputes go to linked spreadsheet per surface. Bot context: when diagnosing MAST capacity failures for IG Reels/Feed OT, check against the new OT-specific quotas (several capped below p90 need).

5. **Async OT embedding dump halves bulk eval compute** (llu6, Jun 3): UDD Interest Generator now dumps user embeddings asynchronously during OT forward pass → reduced standalone bulk eval jobs from 6→3 (only low-activity users). Pattern: OT can serve as a freshness pipeline for downstream Laser indices. Relevant context for any future model asking "can OT replace bulk eval runs."

---

## Per-expert digest

### lupaul (Paul Lu) — 2 new posts

- **[S669019: MVAI Python Upgrade causing OT jobs to OOM](https://fb.workplace.com/groups/mrs.ot/permalink/1348865413874868/)** (2026-06-11):
  - Conditions: light_cli built post-Apr-24 + in-trainer publishing + RSS climbing
  - Mitigation: rebuild with Python 3.10
  - Linked: S669019, light_cli versions, Google doc (mitigation guide)
  - Bot relevance: **yes — failure-patterns.md** (Python 3.12 OOM class)

- **[MRS OT Oncall Summary: May 26–Jun 2](https://fb.workplace.com/groups/mrs.ot/permalink/1340724948022248/)** (2026-06-02):
  - Open at handover: S665478 (Reels LSR hang, D98638473 applied, monitor), S665454 (Threads U2M sporadic stuck), S668980 (IGR ESR delta publish QPS anomaly, flow control enabled), S669019 (OOMs in progress)
  - New this shift: S670393 (L2 — `dai_model_platform_prod` XDB max_user_connections exceeded, fleet-wide), S670233 (IFR Prospector 886351377 full publish expiry from MLHub expiry date misconfiguration)
  - Proactive: DeltaPublisher memory diffs (4 unpublished), max_app_retries early return (D106718379)
  - Bot relevance: context on handover state; S670393 MLHub expiry misconfiguration = new known root cause pattern

### llu6 (Li Lu) — 1 new post

- **[Intent to Launch: UDD Interest Generator Deep Profile — RankDM Embedding Infra Upgrade](https://fb.workplace.com/groups/847200946018977/permalink/2305029780236079/)** (2026-06-03):
  - OT relevance: async user embedding dump from OT forward pass replaces 3 of 6 bulk eval jobs; freshness improved; 50% bulk eval compute reduction
  - Positive metrics: FB Pigeon Sessions +0.06%, FB Video UDD WT +0.11%, diversity metrics positive
  - Linked: experiment `deep_profile_learning_fresh_ot_embeddings_v2`; capacity review P2362628703
  - Bot relevance: **pattern reference** (OT async embedding dump as live inference pipeline)

### prgzz (Pushpak Raj Gautam) — 3 new posts

- **[Press Release: Online Training with Dynamic Resizing](https://fb.workplace.com/groups/710550224249570/permalink/1373980641239855/)** (2026-06-10):
  - 10–45% GPU savings; ~6 min downtime per switch, ~2 switches/day; NE/QPS/freshness neutral
  - Benchmarks: Reels LSR (2133008573) 9.4%, Feed ESR (2126294150) 13.7%, mtml_ctr 45.6%
  - Production-ready Q2; Q3 = earn-trust phase across 4+ model archetypes; Q4 = general scale-out
  - Onboard: reach Training Service Team or IG PoC (prgzz / dkotfis) or Ads PoC (Ke Xu / Luming Nie)
  - Bot relevance: **yes — triage rule** (6-min QPS drop during Dynamic Resize switch ≠ failure)

- **[IG Training Health Oncall Summary: Jun 1–8](https://fb.workplace.com/groups/3367638473354337/permalink/26984078227950363/)** (2026-06-08):
  - Active OT work: IG/Threads quota split Phase 1 done, Phase 2 this week (Reels+Feed)
  - GB200 delivery: 461 T20_CIC_GB200 hosts donated to Reels ESR
  - ZippyDB sequence storage alerts noisy/not actionable (follow-up with ZippyDB oncall, Parichay Kapoor)
  - Pending TUO diffs: D105319531, D105319509
  - T273810444: OT/QE job preemption prevention — explanation added in task comments
  - Bot relevance: ZippyDB sequence storage alerts → de-prioritize, known noise

- **[Phase 2 of OT/Offline GPU Split: Reels and Feed](https://fb.workplace.com/groups/training.ig/permalink/1896127304414495/)** (2026-06-08):
  - Several OT tenants capped below p90 need (e.g. `reels_core_modeling_lsr_online_dedicated` T20_CIC at 0 vs 567 needed; `feed_online_qe_lsr` at 2160 vs 2421)
  - Disputes via linked spreadsheets per surface
  - Bot relevance: capacity context for IG Reels/Feed OT quota disputes

---

## Cross-references

- **S669019** confirmed in: lupaul (root cause = Python 3.12), dkotfis weekly 6/8 (ongoing + Python 3.10 revert arms), dennyzhang shift summary (handover item). Consistent root cause.
- **D98638473** (zombie fix light_cli): referenced in lupaul May–Jun summary (S665478, S665454) and dennyzhang zombie posts. Not yet rolled to all jobs — recurring zombie pattern continues.
- **DeltaPublisher memory** (lupaul D106873154–157 proactive diffs): likely part of S669019 resolution path; track landing.
- **S668980** (IGR ESR delta publish slowness): appears in lupaul and dkotfis weekly 6/8. Flow control mitigation increases sparse interval 6→10 min, which regresses freshness → must be resolved before Reels ESR MB7 launch. **Blocking launch risk.**

---

## Integration priority table

| Priority | Item | Action | Time est |
|---|---|---|---|
| P0 | Python 3.12 OOM triage rule | Add to failure-patterns.md: `light_cli_post_apr24 + in_trainer_publishing → OOM_after_40h → S669019_class` | 30 min |
| P0 | Dynamic Resize ~6min drop triage rule | Add to failure-patterns.md: `qps_drop_6min_recovery + no_error → dynamic_resize_switch` | 15 min |
| P1 | S668980 launch blocker note | Add to known-issues: sparse interval increase 6→10 blocks Reels ESR MB7 freshness SLO — owner dkotfis/lupaul | 10 min |
| P1 | DeltaPublisher memory diffs | Track D106873154–157 landing; feeds Python 3.12 resolution path | monitor |
| P2 | Async OT embedding dump pattern | Add to OT capabilities note: OT forward pass can replace bulk eval for high-activity users | 20 min |

---

## Coverage notes

- **dennyzhang**: no new posts since last run (Jun 9 shift summary = already in context); current
- **dkotfis**: no new posts since last run (Jun 11 IG oncall summary = already in context); current
- **yabinzh**: in back-off until 2026-06-27 (no posts in prior window)
- **peiyangy**: in back-off until 2026-06-27 (no posts in prior window)
- **lupaul, llu6, prgzz**: back-off flags cleared (new posts found — prior back-off was stale)
