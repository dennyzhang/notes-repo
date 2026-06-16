# 2026-06-11 — OT experts Workplace posts catch-up (week ending 2026-06-11)

_Auto-distilled by `context-ingestor-posts` cron. Source: 4 posts from 2/7 experts in past 7 days._

---

## Highlights (P0/P1 items for OT bot integration)

- **[P0] Python 3.10→3.12 memory leak root cause confirmed (S669019).** dkotfis confirmed this week: Python 3.10→3.12 upgrade in MVAI base layers is the source of OOM regressions in Reels LSR MB9. MRS-side triage should probe base-layer Python version for any OOM SEV — the root cause is shared infra, not IG-specific.
- **[P0] D98638473 (zombie fix) not rolled to all jobs.** dennyzhang's oncall summary explicitly flags this: the fix predating light_cli:5315 is not universal, so zombie recurrence (stuck MAST job, no clean exit after CUDACachingAllocator crash) remains live risk across MRS fleet. Bot should surface D98638473 rollout status when triaging zombie symptoms.
- **[P1] S668980 Reels ESR delta publish slowness is a cross-team blocker.** IG mitigation (sparse interval 6→10 min) will regress freshness SLO before launch. D107207628 (non-blocking delta publish) needs review from MRS side. Both teams have this open.
- **[P1] Feed LSR sparse latency QPS Cap + upsampling approach is in QE (Model_4, S659917).** New technique — MaxQPS cap at 440k + upsample data partition — directly addresses training example age SLO miss. Relevant if MRS models face similar QPS-limited freshness issues.

---

## Per-expert digest

### dennyzhang (Denny Zhang) — 1 new post

- **[Oncall Summary: mrs_online_training 02 Jun - 09 Jun](https://fb.workplace.com/groups/mrs.ot/permalink/1347037760724300/)** (2026-06-09):
  Heavy shift — 4 HIGH-TOUCH SEVs, 6 pages, 66 alerts.
  - **Open at handover:** S670887 (IFR zombie, L3), S668980 (IGR delta publish, L3), S669019 (Reels OOMs, L3), ifu_i2i FULL_SNAPSHOT stall (7+ days, THRESHOLD_MISFIT, owner ankankr)
  - **Closed this shift:** S665454 (U2M zombie, D98638473 fix applied); S671866 S671272 S672220 (resolved mid-shift)
  - **Diffs:** D98638473 (zombie fix, not yet universal), D107207628 (non-blocking delta publish, needs review), D107594279 (WARNING-tier FBR scribe age), D107651869 (removes 2 invalid detectors), D107678546 (delta streaming instrumentation)
  - **Pain points:** Scribe/ZippyDB cascade (CL-003, 7+ weeks, ig_organic_feed + Reels affected); zombie detection gaps (D98638473 not rolled everywhere)
  - Linked: S670887, S668980, S669019, S665454, S671272–S673437 (12 observe-only)
  - Bot relevance: **yes** — zombie runbook (bot should cite D98638473 rollout status), delta publish tracking (D107207628), alert dedup (CL-003 cascade source is S668542)

---

### dkotfis (Dave Kotfis) — 3 new posts

- **[OT Reliability - Weekly Status 6/8](https://fb.workplace.com/groups/1676744619923718/permalink/2063145464616963/)** (2026-06-08, IG Relevance Reliability Working Group, reactions: 9):
  2/3 open H1 risks now closed. Main open risk: Feed LSR sparse latency (S659917, 2 months open, 19.6% success rate).
  - Reels ESR MB6.5 launched 6/5; Reels StarSearch Omni Retrieval improving (70.8%→81.5% item latency).
  - Active SEVs: S669019 (Reels OOM, Python 3.12 root cause confirmed, testing 3.10 revert), S667222 (Feed LSR MB8 low streaming, mostly healthy, 3 arms at 85-95%), S668980 (Reels ESR delta publish slowness, 6→10 min interval mitigation), S662798 (Feed LSR slow QPS ramp, adding profiling instrumentation)
  - Pending launches blocked: Feed T2I Retrieval (item streaming), Mixed IFR U2I Combined (decoupled full snapshot + item streaming, owner: Shuguang Ye)
  - Linked: S659917, S669019, S668980, S667222, S656663, S662798, S665478
  - Bot relevance: **yes** — Python 3.12/OOM probe (add to MRS OOM triage checklist); S668980 cross-team status; pending launches affect model freshness

- **[Feed LSR - QPS Cap and Data Upsampling](https://fb.workplace.com/groups/441319728374485/permalink/1024922460014206/)** (2026-06-10, IG Feed Relevance Experiment Reviews, reactions: 9):
  Technical proposal to fix Feed LSR sparse latency (S659917) via MaxQPS cap + upsample data partition.
  - MaxQPS cap at 440k raw (330k training QPS / 0.837 filter rate). Technique: downsample during peak to bound training example age; upsample off-peak partition to recover data.
  - QE: ig_one_feed_2026_mb7_freshness_v0, arm Model_4 (proposal) vs prod/MB7 control.
  - Deltoid: https://fburl.com/deltoid3/6pl9zr52
  - Results neutral on Tier-0/Tier-1 (all within noise), positive on cold-start originals recs (+0.14±0.15 green).
  - Ongoing MB8 LC QE adds negative downsampling arm.
  - Linked: S659917
  - Bot relevance: **yes (P2)** — MaxQPS cap is a new IG OT technique for freshness control; if MRS models face QPS-limited example age, this is a reference approach

- **[Oncall Summary: IG Training Prod 02 Jun - 09 Jun](https://fb.workplace.com/groups/3367638473354337/permalink/27024632580561594/)** (2026-06-11, IG Relevance Oncall):
  Shift difficulty 3/5. Key items:
  - S669019 (Reels OOM): Python 3.12 confirmed, rollback tested across arms; 3.10 being removed from fbsource so a real 3.12 fix is required.
  - S668980 (Reels ESR delta publish): 6→10 min interval mitigation in place, freshness regression risk before launch; non-blocking path being explored.
  - S662798 (Feed LSR slow ramp): ramp slowness in combo2.5; ablation inconclusive; adding profiling via D102017103 removal test.
  - S670229 (Stories ESR holdout, silvertorch pkg too old): mitigated by updating ST publishing job +60 days.
  - S671908 (Feed LSR SUMv2 long wait, data availability 24h SLO): on high-priority tenant, alert set for 3h scheduling window.
  - Linked: S669019, S668980, S662798, S670229, S671908
  - Bot relevance: **yes** — silvertorch pkg age as an OT freshness trigger (new pattern); data availability 24h SLO as a root cause class

---

## Cross-references

- **CL-003 (Scribe/ZippyDB cascade):** still active per dennyzhang's summary (7+ weeks). S668542 is the root. ig_organic_feed, ig_reels_tab_ss_omni, ig_reels_tab_mtml all affected. dkotfis's posts do not reference CL-003 by name — IG-side framing is per-SEV. No contradiction.
- **D98638473 (zombie fix):** dennyzhang confirms not universal. IG side (dkotfis) mentions S665478 as "mitigated via base layer patch" — consistent. No conflict, but MRS fleet needs full rollout verification.
- **Python 3.12 OOM:** both sides see this. MRS-specific probe: check current base layer Python version for any model hitting OOM (S669019 is cross-team root).

---

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Add Python 3.12 base-layer OOM probe to MRS OOM triage checklist | `ot-sev-monitor`: add probe for py-version mismatch when OOM class | 30 min |
| P0 | Add D98638473 rollout check to zombie triage | `known-patterns.md` zombie entry: "verify light_cli ≥ post-D98638473 before declaring mitigated" | 15 min |
| P1 | Track S668980 delta publish status (cross-team) | `ot-sev-monitor`: S668980 already tagged; ensure D107207628 review status is surfaced | 10 min |
| P2 | Add MaxQPS cap technique reference for freshness control | `mrs-ot-context/` freshness-techniques.md or known-patterns.md note | 20 min |
| P2 | Add silvertorch pkg age as OT freshness failure class | `known-patterns.md` new entry: ST pkg version delta → freshness regression | 15 min |

---

## Coverage notes

- **Posted this week (2/7):** dennyzhang (1 post), dkotfis (3 posts)
- **In back-off (5/7):** lupaul (until 2026-06-27), yabinzh (until 2026-06-27), prgzz (until 2026-06-27), peiyangy (until 2026-06-27), llu6 (until 2026-06-15)
- **Note on llu6:** llu6 is incoming oncall per dennyzhang's handover (Denny → Li Lu, 2026-06-09). Back-off expires 2026-06-15 — llu6 may post shift updates next week, watch for content resumption.
- **Group filter note:** dkotfis posts in "IG Relevance Oncall" and "IG Feed Relevance Experiment Reviews" do not match the strict group-name regex but are clearly OT-relevant IG training content from a watch-listed expert. Included with this note; update group-filter regex if this causes noise.
