# MISSING — Workplace posts not archived

_Created 2026-05-16 17:12 PT to document the gap between mrs.ot Workplace feed and the archive directory._

## Context

The `ot-daily-learning-mitigated-posts` cron archives posts that the bot detects as RESOLVED (via #resolved comment, peer-agent #resolved + author reaction, native resolve marker, accepted-answer comment, heavy-discussion heuristic, or 7-day aging heuristic). Posts that are unresolved, recently-posted, or never resolved by these signals are NOT archived.

Additionally, posts created before the `ot-daily-learning-mitigated-posts` cron started firing (~2026-05-15) were never seen by the cron at all.

This file lists mrs.ot posts created in May 2026 that don't have an archive file. Many of these are legitimately not-yet-resolved or never-resolved — this isn't necessarily "missing" in a bug sense.

## Numbers (as of 2026-05-16 17:12 PT)

- **mrs.ot posts in May 2026 (from `meta workplace.group activity-feed`):** 18
- **Currently archived (this directory):** 5
- **NOT in archive:** 13

(Note: query limit is 200; if the May volume exceeds the feed window, this undercounts.)

## What's NOT archived

| Post ID | Author | Created | Why might NOT be archived |
|---|---|---|---|
| 1314828667278543 | Ziyue Sun | 2026-05-01 15:48 | no resolution signal detected |
| 1314983173929759 | Velvin Fu | 2026-05-01 20:22 | no resolution signal detected |
| 1318460240248719 | Paul Lu | 2026-05-05 17:45 | no resolution signal detected |
| 1319390770155666 | Kedong He | 2026-05-07 00:49 | no resolution signal detected |
| 1215710353808301 | Jakub Bester | 2026-05-07 17:30 | no resolution signal detected |
| 1320976936663716 | Denny Zhang | 2026-05-09 02:29 | no resolution signal detected |
| 1321547686606641 | Denny Zhang | 2026-05-09 18:54 | no resolution signal detected |
| 1218910203488316 | Jianhui Sun | 2026-05-11 23:17 | still open / unresolved |
| 1323978743030202 | Denny Zhang | 2026-05-12 19:06 | still open / unresolved |
| 1324845696276840 | Siyuan Zhu | 2026-05-13 20:16 | still open / unresolved |
| 1324864999608243 | Rudra Barua | 2026-05-13 20:56 | still open / unresolved |
| 1326387856122624 | Max Kaplan | 2026-05-15 16:58 | still open / unresolved |
| 1326836659411077 | Renqin Cai | 2026-05-16 07:08 | still open / unresolved |


## Why this isn't all a "missing" gap

Unlike SEVs, posts don't have a binary "mitigated" state. The cron uses 8 different resolution signals (per `ot-daily-learning-mitigated-posts.md`):
1. Post author posts "resolved" comment
2. Peer agent posts #resolved + author reacts
3. Native Workplace resolve marker
4. Linked SEV closes
5. Comment marked `is_accepted_answer=true`
6. Plain-English resolution phrasing in comment
7. Heavy discussion heuristic (≥5 comments, ≥2 distinct authors)
8. Age heuristic (≥7 days old)

Posts that don't trigger ANY of these signals stay unarchived — that's by design. The 13 posts in this list likely include:
- Recent posts (<7d) without explicit resolution signals — still potentially active
- Questions / discussions that never converged on a resolution
- Posts the cron processed and explicitly chose NOT to archive (degraded signal scores)

To distinguish "actually unresolved" vs "should have been archived but wasn't," cross-check each post's comments via `meta workplace.comment list --post-id=<id>`.

## When to backfill

If a future analysis needs archives of posts the cron missed (e.g., the bot was down when the post resolved), then run a focused backfill. Until then, this file is the gap acknowledgment.

## See also

- `mrs-ot-agent-context/README.md` for the directory taxonomy
- `mrs-ot-agent-src/team_bot/cron-jobs/ot-daily-learning-mitigated-posts.md` for the archive-writing cron + 8 resolution signals
- `mrs-ot-agent-context/incidents/debug-threads/<YYYY-MM>/` for the ot-thread-summarizer output (separate corpus)
