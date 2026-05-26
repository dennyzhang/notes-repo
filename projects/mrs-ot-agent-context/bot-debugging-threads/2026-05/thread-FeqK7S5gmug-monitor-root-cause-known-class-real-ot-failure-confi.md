# Thread Summary: S665464 Triage Review — Cron vs Manual Accuracy Comparison

_Source: spaces/AAQAVOjYc80 thread `FeqK7S5gmug` · 9 messages · 2026-05-19T00:53–02:47Z_
_Summarized: 2026-05-19 21:41 PT · last-msg-time: 2026-05-19T02:47:56Z_

## What was discussed

Denny posted the ot-sev-monitor cron's structured triage for S665464 (ig_stories_tray_esr StuckJobException). MyClaw reviewed the cron output vs its own prior manual reply, finding the cron was more accurate: it cited D105401690 (DPP GLOO dedicated process group fix, landed 12:08 PT, 5 clean post-fix jobs) while the manual reply had propagated Opsmate's wrong diff D103046213 (SilverTorch bulk_eval barrier — unrelated path). Denny then asked for clarification on "bot vs I" terminology, and challenged whether the root-cause chain was independently derived or just summarized from the SEV gchat.

## Key decisions made

- [02:44:51Z] Terminology clarified: "bot" = ot-sev-monitor cron output; "I" = MyClaw manual chat reply. Conflation was confusing and should be avoided going forward.
- [02:45:47Z] Root-cause chain `DPP PG deadlock → rank stall → SJD lease expiry → StuckJobException` was NOT from SEV gchat (bot flagged gchat unverified). Chain was composed from: P24 pattern catalog (StuckJobException → SJD lease expiry) + D105401690 diff description (NCCL/GLOO PG deadlock) + logical inference (the connecting "rank stall" glue). The gchat was inaccessible.
- [02:44:51Z] Prompt improvement queued: "Opsmate's root-cause diff is a hypothesis — always cross-check against `meta sevmanager.sev metadata --sev=... | jq .mentioned_diffs` + `meta phabricator.diff describe`."

## Files / artifacts touched

| path | what changed |
|---|---|
| ot-sev-monitor.md (prompt) | Prompt edit queued to require cross-checking Opsmate diff vs SEV.mentioned_diffs |

## Cluster / pattern references

- [CL-014] — S665464 matches CL-014 (Training timeout / NCCL / watchdog). D105401690 GLOO dedicated PG fix directly addresses the CL-014 mechanism.

## Followup items (not yet done)

_(none explicitly committed in thread)_

## Cross-refs

- SEVs discussed: S665464, S661645, S665454
- Related threads: `ExNKfa2pU4w` (gdoc 5/18 session running in parallel during this thread)
