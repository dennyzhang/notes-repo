# 2026-06-14 — OT experts Workplace posts catch-up (week ending 2026-06-14)

_Auto-distilled by `ot-ingest-posts` cron. Source: 1 post from 1/7 active experts in past 7 days._
_Roster this run: 8 people (7 active, 1 back-off). 2 newly added to state: shugye (first-run), ziqiliu (first-run, no posts → back-off 28d). llu6: no posts → back-off 28d._

## Highlights (P0/P1 items for OT bot integration)

- **ST Prime milestone**: shugye's launch post confirms the first-ever model launched on SilverTorch Prime (ST Prime) — the Threads U2M retrieval model via STAR. OT context: ST is the publish/serving layer beneath MRS OT jobs. Any ST Prime migration would affect `FULL_SNAPSHOT` and delta publish paths. Worth tracking if MRS OT models are scheduled to migrate to ST Prime.

## Per-expert digest

### shugye (Shuguang Ye, trust 3, role: OT eng manager MRS) — 1 post

_First-run (14d window). 3 posts pulled; 1 passed group filter (MRS Change Log); 2 dropped (MRS Social = comms group, CodeHub Browser Feedback = tool feedback, off-topic)._

- **[[Launch] Thread Search — STAR-powered Agentic Semantic Aware U2M Retrieval](https://fb.workplace.com/groups/399626961860250/permalink/1566545631835038/)** (2026-06-11): Threads + MRS collaboration. Agentic semantic aware user-to-media retrieval on top of STAR, using custom Text Embedding + Engagement-based RAG + agentic evaluation. **First model launched on ST Prime.**
  - Linked: (no S/D/T refs in post body)
  - Bot relevance: **yes** — ST Prime is the next-gen SilverTorch serving layer. If MRS OT publish jobs move to ST Prime, publish-path alerts (FULL_SNAPSHOT missing, delta stall) may need updated detector configs. Monitor for follow-up announcements. Cron prompt: no change needed now; note for future `ot-alert-monitor` detector calibration if ST Prime rollout accelerates.

### dennyzhang (Denny Zhang, trust 3, role: OT dev / operator) — 0 new posts

_(1 post in window, epoch matches prior run state — already processed 2026-06-13. Oncall summary for mrs_online_training 02 Jun–09 Jun was the last post.)_

### lupaul (Paul Lu, trust 3, role: OT dev MRS) — 0 new posts

_(1 post in window, epoch matches prior run state — already processed 2026-06-13. S669019 MVAI Python 3.12 OOM post was the last post.)_

### llu6 (Li Lu, trust 3, role: OT dev MRS) — 0 posts

No Workplace posts in past 7 days. Back-off 28d (until ~2026-07-12).

### dkotfis (Dave Kotfis, trust 3, role: IG OT POC) — 0 new posts

_(3 posts in window, all ≤ state epoch — already processed 2026-06-13. Most recent: IG Training Prod oncall summary 02–09 Jun + Feed LSR QPS Cap/Upsample data QE + OT Reliability weekly status 6/8.)_

### prgzz (Pushpak Raj Gautam, trust 3, role: IG OT POC) — 0 new posts

_(3 posts in window, all ≤ state epoch — already processed 2026-06-13. Most recent: Dynamic Resizing press release + IG Training Health oncall summary + Phase 2 Online/Offline GPU split for Reels/Feed.)_

### ziqiliu (Ziqi Liu, trust 3, role: OT dev MRS) — 0 posts

First-run (14d window). No Workplace posts found. Back-off 28d (until ~2026-07-12).

### peiyangy (Peiyang Yu, trust 3, role: IG OT POC) — skipped (back-off)

Back-off active until ~2026-06-27. Will re-check next run after that date.

## Cross-references

None for this week — the one new post (shugye, ST Prime launch) does not reference existing CL-NNN or P-row patterns.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P2 | Track ST Prime rollout; update alert-monitor detector configs if MRS OT publish paths migrate | No change now; revisit when migration announced | TBD |

## Coverage notes

- **Experts with 0 new content this week:** llu6 (no WP posts → 28d back-off), ziqiliu (new, no posts → 28d back-off)
- **Back-off active:** peiyangy (until ~2026-06-27)
- **Newly added to roster + state this run:** shugye, ziqiliu (per key-people.json update 2026-06-13)
- **No longer in roster:** yabinzh (in state as stale entry; skip processing, no action needed)
- **Consider adding**: no new candidates surfaced this run
