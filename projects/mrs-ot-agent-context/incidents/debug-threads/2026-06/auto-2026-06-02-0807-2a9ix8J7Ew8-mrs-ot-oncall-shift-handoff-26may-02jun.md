---
human_involved: false
thread_id: 2a9ix8J7Ew8
thread_name: spaces/AAQAVOjYc80/threads/2a9ix8J7Ew8
msg_count: 4
date_range: 2026-06-02 08:07–08:09 PDT
summarized: 2026-06-03 10:43 PDT
last_msg_time: 2026-06-02T15:09:36Z
---

# Thread Summary: MRS OT Oncall Shift Handoff — 26 May to 02 Jun

_Source: spaces/AAQAVOjYc80 thread `2a9ix8J7Ew8` · 4 messages · 2026-06-02 08:07–08:09 PDT_
_Summarized: 2026-06-03 10:43 PT · last-msg-time: 2026-06-02T15:09:36Z_

## What was discussed

The bot posted a 4-part MRS OT incoming oncall briefing for dennyzhang's shift (26 May – 02 Jun), cross-checking Paul Lu's outgoing mrs.ot post with live SEV/alert/user-report data. Covers 37 SEVs in the window, 3 IC-handled by lupaul, 6 actionable alerts, 4 user reports, and a P0 bot-reliability finding (triage_events table missing all shift → bot dark).

## Key decisions made

- Operator TODOs surfaced: SLICK SLI green/yellow/red check for Discovery Online and IG Online models (URLs in thread).
- SEV-Review enrollment missing: no SEV tagged #mvai-online-training-review in last 14 days; Paul suggests S666451 (AOTI root cause) as the teaching SEV.
- Bot dark: triage_events table not found in myclaw.db — auto-triage, validator, auto-tag all non-functional the entire shift. Flagged as P0.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — briefing output only, no notes files edited) | — |

## Cluster / pattern references

(omitted — no verified cluster IDs for this content)

## Followup items (not yet done)

1. dennyzhang: Check SLICK SLI for Discovery Online + IG Online models (links in thread).
2. dennyzhang: Follow up on 4 open user reports in mrs.ot Workplace group (gflag how-to, MC12 example age, IG Reels crash loop, ACL for ephemeral fbpkg).
3. dennyzhang: Add #mvai-online-training-review tag to teaching SEV (S666451 per Paul).
4. Investigate triage_events table missing — root cause in ot-alert-monitor / ot-sev-monitor / ot-post-monitor cron health.

## Cross-refs

- SEVs discussed: S670393 (L2 XDB), S669019, S668980, S665478, S665454, S669785, S670229, S670040, S669045, S668472, S668542, S670320, S668991, S669133, S670347, S669904, S670233, S668689
- Open diffs: D106873157, D106873156, D106873154, D106873155 (DeltaPublisher memory)
- Closed diffs: D107167718, D106474860, D106912787, D106718379, D106588525, D106566401, D106554476
- Related threads: (none noted)
