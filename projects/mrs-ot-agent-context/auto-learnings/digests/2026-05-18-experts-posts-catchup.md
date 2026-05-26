# 2026-05-18 — OT experts Workplace posts catch-up (week ending 2026-05-18)

_Auto-distilled by `context-ingestor-posts` cron. Source: 13 posts from 6/7 experts in past 14 days (first-run: true). Group-filtered to OT-relevant groups. dennyzhang included as operator self-check._

---

## Highlights (P0/P1 items for OT bot integration)

### P0 — Immediate context the bot needs now

**1. GPU quota split Online/Offline goes live TODAY (2026-05-18)**
> prgzz Workplace post: MAST is explicitly splitting GPU quotas into Online Training (Scribe-based) and Offline Training (non-Scribe-based). **Phase 1 lands today (May 18)** for Threads, Explore, Stories, Search, Infra. Phase 2 (Reels, Feed) follows May 28.
> - Impact on OT bot: when diagnosing pending/preempted OT jobs going forward, the quota tenant path (e.g., `threads_online_training` vs `threads_offline`) is now authoritative. A job landing in the wrong quota bucket = preemption root cause.
> - Bot integration: update failure-patterns.md to note "OT job preempted despite quota" may now be a tenant-path mismatch (online job accidentally in offline bucket or vice versa) — new category as of 2026-05-18.

**2. S659917 (Feed LSR) — ongoing risk, sparse latency at 30.6%**
> dkotfis 5/18 weekly status: Feed LSR sparse latency at 30.6%, failing SLO. Root cause: MB7 removed 5-min Scribe lookback + insufficient training QPS. QE in flight to compare 3 options (revert, QPS cap+upsample, 10→14 B200 hosts). MB8 will further regress QPS. **No mitigation yet.**
> - Bot integration: S659917 is a known open SEV with active QE. When routing OT issues for Feed LSR, this is the primary open SEV to reference.

### P1 — Important context, integrate into working knowledge

**3. T2 per-snapshot latency metrics now live (Yabin + Li Lu)**
> ATS decomposition T2 (training-stage latency) is now live for MVAI OT models. New scuba metrics: `T2`, `training_duration`, `publish_delay`, `batch_count`, `data_age_at_publish`. Dashboard: https://fburl.com/unidash/i1oe6go7
> - Bot integration: when investigating "example age high" or "snapshot stale" incidents, T2 dashboard is now the primary source for isolating training-stage vs publish-stage vs serving-stage latency. Add to investigation playbook.

**4. Feed LSR MB8 has 3+ hour warmup problem (prgzz)**
> After job restart, Feed LSR MB8 OT jobs take 3+ hours to reach optimal QPS (expected: ~30 min). Pattern confirmed on models 2124809034 and 2125053194. DPP starvation during warmup window is suspected cause.
> - Bot integration: Feed LSR "QPS low" or "example age high" alerts immediately after a job restart should be treated as MONITOR not PAGE for up to 3 hours. Update alert routing for Feed LSR.

**5. IG OT E2E latency alerts: 36% are chronically noisy (peiyangy)**
> Audit of 28 E2E latency alerts (2026-04-23 → 2026-05-13): 10 alerts fire >5x/day, 9 of 10 are holdout models. Holdouts fire 3.6× more than baselines. Threshold doubling in progress for 9 holdout alerts. Affected model types: ig_feedrec_esr_ttsn, ig_reels_tab_ss/cs_omni_retrieval, ig_reels_tab_esr_ttsn, ig_organic_feed_mtml, ig_feed_recs_ifr_t2i_retrieval, ig_reels_starsearch_t2i_retrieval.
> - Bot integration: **do not escalate** E2E latency alerts on holdout models until threshold tuning lands. Classify as THRESHOLD_MISFIT, not PAGE.

### P2 — Background, no immediate cron change needed

- **Reels CS Omni Retrieval S656663** (79.2% sparse latency): MB6 QE expected to mitigate; decision on capacity acceleration week of 5/25. (dkotfis)
- **Mixed IFR U2I S664657** (84.7% sparse latency): mitigated via capacity increase 4xA100→4xH100, expected closed 5/19. (dkotfis)
- **Pending launches (dkotfis)**: Feed T2I Item Latency, Mixed IFR U2I Item Decoupled FS/Item Streaming (Shuguang Ye), Reels SS Omni Weight Manager (Jack Zhao on MB5), Reels VM ESR parse streaming (Kang Du).
- **Reels LSR recurring checkpoint from flow job** (prgzz): f1080500198 (bulk eval flow) is submitting checkpoints to prod model 2133008573. Asking for enforcement fix from Paul Lu / Peiyang Yu / Dave Kotfis.
- **SilverTorch OT full snapshot absent** (dennyzhang triage): model 2133142909 — st_update_service.py:1227 skipping full snapshot publish, oncall help requested.
- **mvai scuba vs Mast ODS metrics discrepancy** (dennyzhang): facebook_reels_vdd_hstu_v0 example age shows 3000 min in mvai scuba vs sub-2.5 min in Mast ODS. Resolution in progress.
- **OT tuning: threads_feed_mtml 33% trainer reduction** (prgzz): 3→2 trainers, $1.3M/year ICE savings, 10.62% QPS gain. Root cause of 3-trainer need was MVAI lazy imports causing OOM — fixed. Roll-out next MB cycle.

---

## Per-expert digest

### dennyzhang (Denny Zhang) — 3 posts

- **[Oncall Summary mrs_online_training: 05 May - 12 May](https://fb.workplace.com/groups/mrs.ot/permalink/1323978743030202/)** (2026-05-12): Shift difficulty 5/5. Bot post score 57% (8/14 posts). 10 open SEVs at handoff: S658165, S652695, S658492, S657606, S660706, S661157, S661169, S661843, S661851, S661936, S659917. 14 OT-bot diffs landed. Alert coverage: Critical 100%, Major 0%.
  - Linked: S657690, S658165, S660546, S652695, S658149, S657977, S658476, S658312, S658426, S658035, S659917
  - Bot relevance: Yes — shift handoff record; confirms 10 open SEVs + 11 diffs in review

- **[Training example age inconsistency: facebook_reels_vdd_hstu_v0](https://fb.workplace.com/groups/mrs.ot/permalink/1321547686606641/)** (2026-05-09): mvai scuba reports 3000 min example age; Mast ODS shows sub-2.5 min. Which metric to trust is unresolved.
  - Bot relevance: Yes — when bot sees high example age from mvai scuba for this model, cross-check Mast ODS before escalating

- **[OT triage: SilverTorch model 2133142909 full snapshots ~9h stale](https://fb.workplace.com/groups/mrs.ot/permalink/1320976936663716/)** (2026-05-08): st_update_service.py:1227 rank-0 skipping full snapshot publish. Sparse + item-emb deltas healthy. Triage paste: P2315669002.
  - Bot relevance: Yes — SilverTorch full-snapshot-skip pattern documented here; add to failure-patterns.md as "full snapshot absent + deltas healthy → check st_update_service rank-0 skip"

---

### lupaul (Paul Lu) — 1 post

- **[Oncall Summary mrs_online_training: 28 Apr - 05 May](https://fb.workplace.com/groups/mrs.ot/permalink/1318460240248719/)** (2026-05-05): Shift difficulty 5/5. Bot Post Score 3/7. Key ongoing: S659167 (Threads FSR <50%), S659243 (TIXU calibration instability), S652695 (Threads Feed LSR unstable — PT2 recompilation, NCCL timeout, dynamic tensors). S655630 (RankFM holdout migration). S658165 (IG OT import error / TORCHELASTIC port binding).
  - Linked: S659167, S659243, S652695, S655630, S658149, S657977, S658034, S658035, S657920, S657690, S655459, S658492, S657606, S658165. Diffs: D103277699, D103808619, D103418772
  - Key skill improvement: D103075514/13/39 stack — added infrastructure failure search (HTTP 429/504, ApiKey Quota, DeltaPublishRuntimeException), Phase 3I infrastructure failure path, Manifold/Everstore failure types to timeout guide.
  - Bot relevance: Yes — oncall improvement diffs D103075514/13/39 document the Manifold/Everstore/NCCL timeout investigation gap now fixed. Cross-reference when bot routes NCCL timeout incidents.

---

### llu6 (Li Lu) — 0 posts

No posts in 14-day window. Back-off applied: skip until 2026-06-15 (28 days). Note: llu6 was co-author on the T2 latency measurement (D94125283) referenced in yabinzh's post — context captured there.

---

### yabinzh (Yabin Zheng) — 1 post

- **[Per-Snapshot T2 Training Latency Measurement live — validated on Threads TIXU](https://fb.workplace.com/groups/526792945038994/permalink/1615462866171991/)** (2026-05-05, MVAI FYI): ATS decomposition T2 metric now live. Key metrics: `T2` (publish_ts - min_trained_ts), `training_duration`, `publish_delay`, `data_age_at_publish`, `batch_count`. Dashboard: https://fburl.com/unidash/i1oe6go7. Design doc: Google Doc linked in post. Steady-state: T2 ≈ 3.3 min, training_duration ≈ 2.9-3.0 min, publish_delay ≈ 0.3 min.
  - Linked: D94125283 (Li Lu — core impl), D98750952 (Yabin — watermark decoupling), D101074908 (Yabin — schema centralization)
  - Bot relevance: Yes — this is a primary new diagnostic surface for latency incidents. Enable on UMIA surfaces via config (`enable_watermark_tracking=True`). Add to ot-alert-monitor investigation flow for example-age escalations.

---

### dkotfis (Dave Kotfis) — 1 post

- **[OT Reliability - Weekly Status 5/18](https://fb.workplace.com/groups/1676744619923718/permalink/2044577953140381/)** (2026-05-18, IG Relevance Reliability Working Group): Weekly OT SLO tracking (target: 95% hours/week at <10 min latency, >99% SSR). SLO dashboard: https://ig-data-apps.internalmeta.com/ig/relevance-foundations/online-training-slo.
  - **Progress** (improving/mitigated):
    - S656663 (Reels CS Omni, sparse 79.2%): MB6 QE LC active, decision on capacity acceleration week of 5/25
    - S664657 (Mixed IFR U2I, sparse 84.7%): 4xA100→4xH100, expected close 5/19
    - S662001 (Feed T2I sparse spike): dashboard bug fixed by Josef Cohen (bad_sparse fallback avg→p50), significant improvements backfilled to 4/22 across Feed T2i/ESR/SMSL/Reels LSR
  - **Pending launches**: Feed T2I Item Latency, Mixed IFR U2I Item Decoupled FS/Item Streaming, Reels SS Omni Weight Manager (MB5 doc linked), Reels VM ESR parse streaming
  - **Risks** (active open SEVs): S659917 (Feed LSR 30.6%, QE in flight — options: revert scribe lookback/QPS cap+upsample/10→14 B200), Reels ESR 14.6% (expected SLO w/ MB6.5 Time-Based-Sampling), Reels StarSearch T2I 59.0% SSR (Full Snapshot Transition losses — Weight Manager or inference headroom fix needed)
  - Linked: S656663, S664657, S662001, S659917, S651765, S621928
  - Bot relevance: **High** — this is the weekly ground truth for IG OT SLO state. S659917 Feed LSR is the most at-risk model with no mitigation path confirmed. Bot should treat Feed LSR OT alerts with higher urgency until S659917 closes.

---

### prgzz (Pushpak Raj Gautam) — 6 posts (2 dropped: SEV review agenda, IG Creators SEV review)

- **[GPU quota split: Online vs Offline Training](https://fb.workplace.com/groups/training.ig/permalink/1874785149882044/)** (2026-05-13, IG Training FYI): MAST splitting quota into Scribe-based (online) and Hive-based (offline). Prevents unwanted preemptions from mixing. **Phase 1: May 18** (Threads, Explore, Stories, Search, Infra). **Phase 2: May 28** (Reels, Feed, conditioned on tenant restructuring completion). Quota table in spreadsheet linked.
  - Bot relevance: **High — structural change starting today**. OT job preemption root cause analysis must now check if tenant path is `*_online_training` not `*_offline`.

- **[OT Tuning: threads_feed_mtml — 33% trainer reduction, $1.3M/yr savings](https://fb.workplace.com/groups/976895296883781/permalink/1668823204357650/)** (2026-05-11, Threads Growth & Relevance): 3→2 trainers (T20_GRAND_TETON). QPS +10.62%, GPU memory -7.20%. No NE/RMSE regressions. Root cause of prior 3-trainer need: MVAI lazy imports causing OOM (fixed). 17 jobs at any time → ~$1.3M ICE savings. Launch: next MB cycle (offline combo done, online next).
  - Linked: /launch-ot-tuning skill, D103162679 (lazy imports silvertorch subprocesses)
  - Bot relevance: Yes — lazy imports OOM root cause may apply to other models hitting OOM; reference this post when investigating multi-trainer OOM escalations.

- **[Feed LSR MB8 warmup problem — 3+ hours to optimal QPS](https://fb.workplace.com/groups/1250930069637151/permalink/2165480318182117/)** (2026-05-11, IG Training Discussions): Job restart on Feed LSR MB8 (models 2124809034, 2125053194) takes 3+ hours vs expected 30 min. DPP starvation suspected. Torch compile eliminated as cause (recompiles only in first 15 min). QE: ig_one_feed_mb8_combo_qe_r1.
  - Bot relevance: **Yes — update alert routing**. Feed LSR QPS-low/example-age-high alerts within first 3 hours of job restart → MONITOR, not PAGE.

- **[Recurring job submitting checkpoints to Reels LSR prod model 2133008573](https://fb.workplace.com/groups/1250930069637151/permalink/2167471227983026/)** (2026-05-13, IG Training Discussions): Flow job f1080500198 (bulk eval) submitting checkpoints to prod OT model 2133008573. Should only come from OT job. Asking for enforcement fix.
  - Bot relevance: Yes — if bot sees unexpected checkpoint activity on Reels LSR, this is known; enforcement fix in progress.

- **[Oncall Summary IG Training Prod: 28 Apr - 05 May](https://fb.workplace.com/groups/3367638473354337/permalink/26556463204045203/)** (2026-05-05, IG Relevance Oncall): Active SEVs: S653773 (MMC LSR pReport not trained for 1 month — AI privacy infra model type issue), S658165 (stuck jobs Feed ESR — dkotfis has root cause), S656946 (ig_textpost_feed_xapp_u2m_retrieval example age spiking daily). Resolved: S658034, S657977, S658035. Note: MFMP deprecated, O3 migration ongoing (Pei Zhang/Brian Banbrook).
  - Linked: S653773, S658165, S656946, S658149, S657977, S658034, S655900
  - Bot relevance: Yes — S653773 (MMC LSR) is a long-running (1-month) training failure due to AI privacy infra model type mismatch. If bot routes MMC LSR training issues, this is the active blocker.

- **[Some inductor output files missing on MAST job](https://fb.workplace.com/groups/1075192433118967/permalink/1945628512742017/)** (2026-05-06, PyTorch Compile Q&A): Inductor output files not on TLParse for a stuck job. Question about .py file location for debugging. Dropped from P0/P1 — debug question, no resolution yet. Low bot relevance.

---

### peiyangy (Peiyang Yu) — 1 post (2 dropped: no-body post, Logger Users group)

- **[IG OT E2E Latency Alerts — Noise Audit & Proposed Threshold Tuning](https://fb.workplace.com/groups/1676744619923718/permalink/2041346063463570/)** (2026-05-14, IG Relevance Reliability Working Group): 28 alerts audited over 2026-04-23→2026-05-13. 12 healthy (43%), 10 unhealthy (36%, fire >5/day), 6 not active (21%). Holdouts 3.6× noisier than baselines. **Next step**: double threshold for 9 holdout alerts. 1 unhealthy baseline: ig_organic_feed_mtml sparse_delta (6.2/day).
  - Linked: 10 OneDetection observer IDs (see post for full list). Configerator: model_ids.cinc, helpers.cinc.
  - Bot relevance: **High** — bot should NOT escalate E2E latency alerts on holdout models for ig_feedrec_esr_ttsn, ig_reels_tab_ss/cs_omni_retrieval, ig_reels_tab_esr_ttsn, ig_organic_feed_mtml, ig_feed_recs_ifr_t2i_retrieval, ig_reels_starsearch_t2i_retrieval until threshold tuning lands. Classify as THRESHOLD_MISFIT.

---

## Cross-references

- S658165 appears in lupaul (IG OT port binding bug), prgzz (stuck jobs, dkotfis has root cause), dennyzhang (in open SEV list at handoff). Still active as of 5/12 handoff.
- S659917 (Feed LSR sparse latency) appears in dennyzhang handoff (open) and dkotfis weekly status (30.6%, highest risk). Consistent: no mitigation path confirmed yet.
- dkotfis 5/18 status mentions S662001 dashboard bug fix by Josef Cohen — S662001 resolution via backfill is complete (P2 context, no action).
- prgzz GPU quota split post (5/13 authored, 5/18 phase 1 launches) cross-checks with lupaul oncall (S658149 MAST preemption bug) — the preemption problems lupaul faced in 4/28-5/5 are part of what motivated the explicit quota split.
- llu6 D94125283 (T2 latency core impl) cited in yabinzh's post — llu6 co-authored the T2 measurement work despite having no Workplace posts this week.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | GPU quota split Online/Offline live 5/18 — update OT job preemption diagnosis | failure-patterns.md: add tenant-path mismatch category | 30 min |
| P0 | S659917 Feed LSR (30.6%) — active open SEV, no mitigation | ot-alert-monitor: pre-load S659917 as known-open for Feed LSR routing | 15 min |
| P1 | T2 latency dashboard live — add to investigation playbook | ot-alert-monitor: add T2 dashboard to example-age investigation steps | 20 min |
| P1 | Feed LSR MB8 3+ hr warmup — extend MONITOR window for post-restart | ot-alert-monitor: Feed LSR QPS/example-age MONITOR 3h after restart | 15 min |
| P1 | Holdout E2E latency alerts: 9 models chronically noisy | ot-alert-monitor: THRESHOLD_MISFIT for holdout E2E alerts on listed models | 15 min |
| P2 | SilverTorch full-snapshot-skip pattern (st_update_service:1227) | failure-patterns.md: add as known pattern | 10 min |
| P2 | Reels LSR recurring checkpoint from eval flow — known, fix in progress | No action (monitoring in progress by prgzz/dkotfis) | — |

---

## Coverage notes

- **llu6**: 0 posts in 14-day window → back-off 28 days (re-check 2026-06-15). Contributed via D94125283 (T2 measurement) captured through yabinzh's post.
- **dennyzhang**: included as operator self-check. Posts are OT oncall summaries and triage — useful as ground-truth on what operator faced as oncall.
- **lupaul**: only 1 post (prior shift oncall summary). Paul is off oncall and likely posting in other groups (MVAI Users) that may not be visible. Consider adding MVAI Users group feed to next review.
- **yabinzh**: 1 post in MVAI FYI — highly signal-dense. Consider also watching `MVAI Platform` and `MVAI×IG` groups.
- **New experts to consider**: Josef Cohen (dashboard bug fix for S662001, threshold updates for E2E alerts — mentioned by both dkotfis and peiyangy). Yang Lu (Reels CS Omni mitigation owner per dkotfis). Jack Zhao (Reels SS Omni Weight Manager).
