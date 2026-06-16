# Thread Summary: OT Post Digest — W1330685625692847 (kmeans corpus depletion, P62 proposed)

_Source: spaces/AAQAVOjYc80 thread `GzaCzOeCM7o` · 7 messages · 2026-05-22_
_Summarized: 2026-05-22 21:47 PDT · last-msg-time: 2026-05-22T04:41:46Z_

## What was discussed

Automated Workplace post digest covering 3 posts: W1330685625692847 (ig_textpost_feed_m2m_retrieval model 2130324780 FULL_SNAPSHOT stuck 4h), W1324845696276840 (Reels 0 QPS during S660017/S660220), and W1321547686606641 (inconsistent training example age metrics). Two posts were degraded/heuristic-resolved; one (W1330685625692847) was non-degraded and triggered a new pattern proposal P62. Validator was unavailable in cron context.

## Key decisions made

- **2026-05-22T04:41:12Z** P62 proposed: "Upstream corpus depletion → kmeans assertion → FULL_SNAPSHOT failure." Root cause for W1330685625692847: T2I corpus depleted (1315 embs vs 64077 required) → AssertionError → v41 crash → FS stuck. Self-resolved when corpus recovered.
- W1324845696276840 (degraded, check 8): P50 mechanism confirmed — STUS OT blocked by ZippyDB/Scribe SEVs, in-trainer unaffected.
- W1321547686606641 (degraded, check 8): D105890355 in-flight for recurring UBN fix; archive UPSERT applied to existing file.
- Bot: pattern promotion needs author sign-off per ✅/✏️ contract — will not pre-empt.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../resolved-posts/2026-05/2026-05-21-W1330685625692847.md` | Archive created |
| `~/notes/.../resolved-posts/2026-05/2026-05-21-W1324845696276840.md` | Archive created |
| `~/notes/.../resolved-posts/2026-05/2026-05-17-W1321547686606641.md` | UPSERT: updated with D105890355 |

## Cluster / pattern references

- P62 (proposed) — upstream corpus depletion → kmeans assertion → FULL_SNAPSHOT failure. Not yet promoted to known_patterns.md; pending @Denny Zhang ✅ on W1330685625692847.
- CL-001 — cited as the cluster for W1330685625692847 (FULL_SNAPSHOT stuck), but P62 sub-mechanism not cleanly covered by existing P entries.
- P50 — confirmed by W1324845696276840: STUS publish blocked by upstream SEV; in-trainer bypass active.

## Followup items (not yet done)

1. Denny to ✅ confirm W1330685625692847 so P62 can be promoted to known_patterns.md.

## Cross-refs

- Posts: W1330685625692847, W1324845696276840, W1321547686606641
- SEVs discussed: S660017, S660220
- Diffs: D105890355 (recurring UBN fix, in-flight)
