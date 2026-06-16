# Thread Summary: mvai-training-online-2124122280 daily example-age spike investigation

_Source: spaces/AAQAVOjYc80 thread `I0Ka3kiWGJ4` · 35 messages · 2026-05-21_
_Summarized: 2026-05-21 23:47 PT · last-msg-time: 2026-05-21T23:33:00Z_

## What was discussed

Deep-dive debug of ig_textpost_feed_u2m_retrieval (Threads U2M retrieval) QE trainer 2124122280: daily 30–80 min scribe_read_proxy `client_lag_in_seconds` spikes during 06:00–12:00 PDT, three consecutive days. Investigation covered: Scuba evidence gathering, silvertorch architecture (trainer 2124122280 + STUS 2124122271), synchronized lag across 11 consumers (smoking-gun for shared upstream), QE vs prod example_age comparison showing QE 38% worse, paste creation for ZippyDB team, then operator challenged the ZDB root-cause claim as overclaiming without direct corroboration. Thread ended with recommendation to check Scribe producer-side metrics before sending paste.

## Key decisions made

- `2026-05-21T21:28` — Operator clarified architecture: 2124122280 is a silvertorch trainer (not standalone CHECKPOINT-only). Bot corrected its FULL_SNAPSHOT analysis to reflect trainer→STUS lineage; STUS 2124122271 publishes at ~35-min interval.
- `2026-05-21T22:19` — Bot admitted hand-rolled Scuba URLs were invalid. Operator: "write down the learnings of fixing bad url." Rule captured: use CLI URL emission tools, never hand-roll Scuba URLs.
- `2026-05-21T22:47` — Operator decision: loop in ZippyDB; create paste. Paste P2346803083 created.
- `2026-05-21T22:53` — Operator challenged paste TL;DR for overclaiming ZDB as root cause without direct ZDB-side metric evidence. Bot agreed; recommended rewriting as hypothesis + ask rather than conclusion.
- `2026-05-21T23:23` — Operator: if ZDB issue, "shouldn't we find anything wrong in scribe page?" — valid pre-requisite check before sharing paste. Bot agreed; recommended checking producer-side latency in Scribe category view first.

## Files / artifacts touched

| path | what changed |
|---|---|
| `https://www.internalfb.com/intern/paste/P2346803083/` | Created — ZippyDB loop-in report (needs TL;DR rewrite before sending) |

## Cluster / pattern references

- [CL-003] — ZippyDB/Scribe upstream cascade; synchronized lag across 11 consumers consistent with CL-003 sub-mechanism #3 (peak-traffic capacity shortfall)
- [CL-013] — daily 06–12 PDT peak-traffic shape referenced as CL-013 sub-mechanism

## Followup items (not yet done)

1. Check Scribe producer-side latency for `ig_muddler_generic_training_data_text_post_app_roo` during a known spike window. If clean → withdraw ZDB framing. Owner: Denny.
2. Rewrite paste P2346803083 TL;DR from conclusion to hypothesis+ask before sending to ZippyDB oncall. Owner: Denny/bot.
3. Add model 2124122280 to `noisy-models.md` — 3-day repeating pattern qualifies. Owner: bot.
4. Run DPP starvation query side-by-side QE vs prod to isolate shared-upstream vs QE-specific amplification. Owner: bot.

## Cross-refs

- SEVs discussed: S654082 (ZippyDB AI training tier), S665114 (WS ZippyDB flash bandwidth), S662572 (per-shard read bandwidth), S665454 (Threads U2M tracking), S666880 (mvai_metrics example_age — different model)
- Related threads: `zNu-DFBjb4g` (same day — CL-003 / ZippyDB theme)
