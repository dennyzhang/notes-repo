# Thread Summary: S666880 ig_reels_tab_mtml — throttling root cause vs bot-fabricated GIL hang

_Source: spaces/AAQAVOjYc80 thread `glb71z7nhJ0` · 20 messages · 2026-05-23T14:57–17:57Z_
_Summarized: 2026-05-23 22:50 PT · last-msg-time: 2026-05-23T17:57Z_

## What was discussed

Bot filed a page on ig_reels_tab_mtml (model 2132766001) claiming a P44 GIL hang based on a 7-hour metrics gap. Denny asked to verify via the SEV gchat. Bot confirmed its hypothesis was **actively falsified**: the trainer was producing checkpoints every 1-3 min throughout the alleged "gap" — the timezone error (reading PDT as UTC) fabricated the gap. The actual root cause (per SEV gchat consensus: Nikita Loginov, Andrew Ton, Pushpak, Yiqun, Youmei Zhang) was Scribe-side QPS drop (128k→108k peak) causing the QPS throttler to under-throttle since threshold (145k) exceeded peak. Trainer was healthy the entire time.

## Key decisions made

- [2026-05-23T15:49Z] Hypothesis NOT confirmed — falsified. Bot issued retraction in-thread only (no external message per Denny's instruction at 16:19Z).
- [2026-05-23T16:19Z] *Denny explicit*: "Don't send msg to anyone except me for point 1" — retraction stays private.
- [2026-05-23T16:16Z] Root cause: under-throttling (threshold 145k >> actual peak 108k) triggered by Scribe pre-preproc QPS drop; NOT a GIL hang.
- [2026-05-23T16:17Z] Three bot triage-path fixes agreed: (1) read SEV gchat BEFORE producing RC story, (2) mandatory timezone sanity-check before any "gap" claim, (3) default verdict for open-SEV alerts = OPEN_SEV_FOLLOWUP not fresh-RC.

## Files / artifacts touched

| path | what changed |
|---|---|
| `gotcha_triage-discipline.md` (memory) | Rules 36-38 added: read SEV gchat first, TZ sanity-check, OPEN_SEV_FOLLOWUP default |
| Paste P2348942642 | Bot machine fields (stale/incorrect) |

## Cluster / pattern references

- [CL-013] — training example-age spike; under-throttling is a sub-mechanism of QPS control failure
- [CL-015+CL-016] — training QPS dip + slow ramp-up; Scribe QPS drop triggering throttling mismatch is exactly this cluster

## Followup items (not yet done)

1. Verify fix diffs (Andrew Ton's threshold patch + Scribe-revert) — status unknown as of 2026-05-22 17:05 UTC
2. Draft 3 triage-path fixes into `mrs-ot-agent-context/` or `team_bot/CLAUDE.md` — proposed by bot at 16:17Z, not confirmed done

## Cross-refs

- SEVs discussed: S666880
- Related threads: `DfbZqZjieN8` (same-day example-age event), `MdXfe6kDl5Q` (GIL vs elastic-agent disambiguation)
