# Thread Summary: Alert Shift Digest — CL-013 + CL-018 Matches + Dead-Detector Signal

_Source: spaces/AAQAVOjYc80 thread `EwpUHt5yl3k` · 6 messages · 2026-05-23T22:16–22:17Z_
_Summarized: 2026-05-23 23:47 PT · last-msg-time: 2026-05-23T22:17:00Z_

## What was discussed

Denny ran an alert shift digest covering 5 alerts across igr_retrieval and mrs_online_training. Two formal pattern matches were confirmed: CL-013 on A1527522728917073 (model 886797001 MC8 MTML, dpp_worker scribe_example_age spiked 26min) and CL-018 on A1341912531124425 (model 2145491885 ig_reels_starsearch, dead observer 1427819186056622 — 3rd fire in May). The bot flagged a meta-signal: 3 of 5 alerts (60%) were stale/dead-detector noise from igr_retrieval holdout models that mrs_ot only follows.

## Key decisions made

- **[22:16:46Z] CL-013 + CL-018 confirmed** — bot's pattern assignments aligned with operator review; no reclassification needed.
- **[22:17:00Z] Dead detector GC is igr_retrieval's call** — command identified (`meta monitoring.observer disable --observer-id=1427819186056622`) but not run; ownership lives with igr_retrieval alert rotation, not mrs_ot. Suggest one-shot to igr_retrieval oncall.
- **[22:17:00Z] Correlate cfr_main_mtml with S666788** — noisy model 878858380 (6× FULL_SNAPSHOT in 7d) is same publish-stability family as S666788 (CL-012 sub-class 4). If both trace to same publisher subprocess hang, D104947534 partial fix (sub-class 2 only) leaves a real gap.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../resolved-alerts/2026-05/high-2026-05-23-A2218864415613563.md` | created by shift digest cron |
| `high-2026-05-23-A1670185680650606.md` | pending @dennyzhang confirmation |

## Cluster / pattern references

- [CL-013] — training example-age spike; confirmed on A1527522728917073 (886797001)
- [CL-018] — dead/invalid alert detector; confirmed on A1341912531124425 (observer 1427819186056622, 3rd May fire)
- [CL-012] — FULL_SNAPSHOT publish-stability sub-class; suspected on 878858380 (not confirmed)

## Followup items (not yet done)

1. Draft one-shot to igr_retrieval oncall: 3× May fires on observer 1427819186056622 + disable command. (Owner: dennyzhang, Status: proposed)
2. Correlate 878858380 FULL_SNAPSHOT pattern with S666788 / D104947534 before next oncall sync. (Owner: dennyzhang, Status: open)

## Cross-refs

- SEVs discussed: S666788 (cfr_main_mtml FULL_SNAPSHOT, in-progress)
- Posts: (none)
- Related threads: (none directly; m2145491885 triage in prior sessions)
