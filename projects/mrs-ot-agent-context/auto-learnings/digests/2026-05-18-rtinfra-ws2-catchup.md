# 2026-05-18 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: ~80 human messages spanning 2026-05-04 → 2026-05-18 in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributors: Dave Kotfis, Josef Cohen, Pushpak Raj Gautam, Paul Lu, Peiyang Yu)._

_Window: 14d (first-run). first-run: true. Overwrites manual seed from same date — historical items (Breathalyzer, refresh-launch detection, MR staleness, SJD NCCL deep-dive) captured in prior manual file, recoverable from notes git history._

---

## P0 — bot-integration-blocking items

### P0-1: IG OT SLO dashboard — canonical source of truth
**URL:** `https://ig-data-apps.internalmeta.com/ig/relevance-foundations/online-training-slo`

Two top-level tabs: **Latency** (model-age per model) + **Streaming Success** (per-tier success rate). Deep-dive tab shows exact `model_id` per measurement stage (sparse vs item streaming vs full-snapshot; root vs ST model).

**SLO bars confirmed this week:**
- Streaming success: **99% target, met 95% of the time** (green = at or above 99%)
- Latency: **10-min bar, 95% of the time** — color scale corrected 2026-05-18: floor now 95% for green (was incorrectly 90%). This correction was a Josef Cohen + Dave Kotfis discussion in D105576627.

**Bot integration:** ot-alert-monitor and ot-sev-monitor verify-step should link to this dashboard subpage when alert is a latency/ATS signal.

### P0-2: bad_sparse → full_snapshot fallback decomposition (Dave Kotfis + Josef Cohen, 2026-05-15)

**New CL-013 sub-mechanism the bot does not currently distinguish:**

The IG OT latency metric has two contributing terms:
- `p50_sparse_min` = pure sparse-streaming age (healthy → streaming path fine)
- `bad_sparse %` = fraction of samples where sparse is null or <0 → forces fallback to full_snapshot_age

**2026-05-14 23:00 incident (S664657):** bad_sparse jumped from 5% → 70% on Feed ESR. Sparse path itself was healthy (p50_sparse_min flat at ~5.8). Full_snapshot age climbed linearly from 122 → 635 min because 70% of samples fell back to full_snapshot. Once bad_sparse crosses 50%, the p50_pipeline_logic_min tracks p50_full_min instead of sparse. Recovery at 2026-05-15 09:00 when bad_sparse dropped.

Dave: _"I don't think we've seen this before where the streaming path itself is completely healthy but full snapshot transition issues so dramatically increased latency."_

**Bot evidence step update needed for CL-013:** when triaging ATS latency alerts, query BOTH `p50_sparse_min` AND `bad_sparse %` from sigrid_predictor before attributing to sparse path health. If sparse is fine but bad_sparse is high → root cause is full_snapshot transition, not the sparse pipeline.

Josef is adding two debug lines to the deep-dive dashboard: dotted line for raw publishing + bar chart for null count.

### P0-3: OT launch diagnostic skill moved to claude-templates, lookback expanded (D105205152)

Josef Cohen's `ot-launch-diagnostic` diff landed. Key changes:
- **Lookback window expanded**: from 1h → 3 days for streaming success, 12h for latency
- Now based on rate (pass rate over window) not snapshot
- Moved to `claude-templates` for broader availability
- D105576627 follow-up adds: context toggle, granularity control, SLICK linkout

**Why this matters for bot:** the 1h lookback was insufficient for catching daily-traffic-pattern regressions (Pushpak flagged: "people can run this tool during a low traffic period and metrics will look good. But during peak, they might have a higher delay").

---

## P1 — significant nuance / sub-mechanisms

### P1-1: D95883643 — QPS-based data-dropping diff (not yet enabled)
Pushpak flagged this diff: plays with dropping training data based on model QPS. Not enabled anywhere but worth knowing. If enabled, could cause **weird data starvation or NE (non-existent embedding) patterns** that look like infra failures but are intentional. Bot should watch for this if NE patterns appear without an obvious infra cause.

### P1-2: S662001 — pAvg fallback calculation bug (fixed 2026-05-11)
Dashboard was using `pAvg` (average) for full_snapshot_age in the fallback calculation when sparse/item age was null. Should use `p50`. Josef landed the fix and backfilled Q2 data. Dave: _"S662001 - it came from using pAvg for full_snapshot age when using the fallback calculation on null sparse/item age."_ 

Implication: historical dashboard data before backfill was artificially elevated. SLO pass rates updated after backfill.

### P1-3: Scribe delay model_id disambiguation (Feed ESR, May 13-14)
For Feed ESR models with memory layer: there are **two** scribe delays — one for training (root model id) and one for item streaming (ST model id). Dashboard's deep dive shows only ST model id. Pushpak raised: Feed ESR deep dive shows 2131444573 (ST model, correct) but not 2131700765 (root model). Dave: intentional — always show ST model ids — but Pushpak notes this misses the training-side scribe delay.

**Bot routing note:** when triaging Feed ESR scribe delay, check BOTH the ST model id (used in dashboard) and the root model id (training path). Scribe delay P90 is over the past hour from when the skill runs — Pushpak raised concern that low-traffic periods may mask peak-hour regressions.

### P1-4: Reels LSR sparse streaming launch delayed pending MB6.5
Paul Lu confirmed (2026-05-18): Reels LSR (not ESR) has NOT yet launched sparse streaming; currently delayed pending MB6.5 launch. MB6.5 had issues; they launched prod-refresh instead. Actual launch expected ~2026-05-14 (per Dave's note that "the actual launch is supposed to go out tomorrow"). Bot should treat Reels LSR as NOT YET on sparse streaming when triaging sparse-related alerts.

### P1-5: e2e latency alert audit — holdout threshold tuning
Peiyang Yu (2026-05-14): "I just did an audit for OT e2e latency alerts health, and identified a few alerts need to be adjusted to make alerts less noisy (mostly holdouts)." Workplace post: `https://fb.workplace.com/groups/1676744619923718/permalink/2041346063463570/`

**Bot implication:** when triaging holdout model alerts, apply higher skepticism — these thresholds may still be in-flight of being adjusted. Check if the alerting model is a holdout before asserting high-confidence verdict.

---

## P2 — references / good-to-know

### ot-health-diagnosis bundled skill
Peiyang Yu (2026-05-14): teams running individual health checks should instead run `ot-health-diagnosis` which bundles `ot-reliability-health-check + ot-launch-diagnostic`. Workplace: `https://fb.workplace.com/groups/1676744619923718/posts/2010635673201276/`

### IGML Training Stack Reliability Debugging Guide
Pushpak offered (2026-05-07): `https://www.internalfb.com/wiki/IGML/IGML_Eng_Guide/Training_Stack_Reliability/Debugging_Guides_0/Latest` as agent absorption material. IG-side debug patterns; could fill gaps in CL coverage for IG models.

### IGML MRS-routing runbook
Pushpak shared (2026-05-07): `https://www.internalfb.com/wiki/IGML/IGML_Eng_Guide/OnCall/IG_Training_Job_Oncalls/IGML_Model_Authoring_Oncall_Runbook/#mvai-platform-issues` — how IG side routes to MRS for MVAI platform issues.

### Feed U2I QPS regression (2026-05-15)
Dave flagged: Feed U2I's launch regressed QPS 2026-05-14 (Workplace: `https://fb.workplace.com/groups/353618119088178/permalink/1641763260273651/`). Correlated with the Feed ESR latency spike. Both timelines align around 5/14-5/15.

---

## Cross-references

- **S664657** — Feed ESR / Reels LSR bad_sparse spike 2026-05-14 23:00 → full_snapshot age 635 min. Cause: full snapshot transition failures. At least A100 hardware on this model → mitigation via trainer increase. Dave opened the SEV after investigating data from sigrid.
- **S662001** — dashboard pAvg fallback calculation bug. Josef confirmed "logs show 11th still ran with AVG." Backfill complete through 2026-04-22.
- **S655459** — Reels T2I sparse streaming regression. Dave: investigated as part of S655459, coincided with recent launch; full snapshot transition losses. Follow-up: file SEV to onboard weight manager. Mentioned again 2026-05-11.
- **OT SEV identification** — `mvai-online-training` tag is canonical gate. `sev_identification.py` in fbsource. D103763284 added idioms: "OT Job" / "Prod OT" / "[OT]" title patterns.

---

## Open coordination threads

1. **Sibling agent dedup** — Masaki Kagesawa's MyClaw checks for OT SEVs every 2h, pings Masaki + Peiyang Yu. Operator offered to let Masaki observe ot-bot (2026-05-06 thread). No conclusion. Three agents (ot-bot + MoDA + Masaki's MyClaw) triaging same SEVs = coordination risk.
2. **SJD owner routing** — Atul Jangra confirmed as SJD owner by Pushpak (2026-05-14: "@Denny Zhang - Atul Jangra for SJD. Either they can directly help or point you to the right person."). Bot's failure-patterns.md CL-012 should cite atuljangra for SJD rule asks.
3. **S655459 weight manager follow-up** — Dave committed to filing a SEV follow-up to onboard weight manager. Status unclear.

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | SLO dashboard URL in verify-step | ot-alert-monitor + ot-sev-monitor verify-step | 30 min |
| P0 | bad_sparse vs pure sparse decomposition | ot-alert-monitor CL-013 evidence step (query both terms) | 45 min |
| P0 | OT launch diagnostic lookback change | ot-launch-related prompts: note 3d/12h lookback window | 15 min |
| P1 | SLO color threshold: green=95% for both latency+streaming | failure-patterns.md CL-013 + monitoring guidance | 15 min |
| P1 | Feed ESR scribe delay: check both ST and root model ids | ot-alert-monitor scribe delay evidence step | 20 min |
| P1 | Reels LSR not yet on sparse streaming | known-patterns.md note; skip sparse triage for Reels LSR | 10 min |
| P1 | Holdout alert noise — higher skepticism | ot-alert-monitor holdout filter | 20 min |
| P2 | Atul Jangra = SJD owner | failure-patterns.md CL-012 detail | 5 min |
| P2 | D95883643 QPS-dropping diff not yet enabled | watchlist note in known-patterns.md | 10 min |
| P2 | ot-health-diagnosis bundled skill reference | ot-launch-related prompts | 10 min |
