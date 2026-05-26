# Thread Summary: Cherry-pick D106026708 + Disk/EdenFS Recovery

_Source: spaces/AAQAVOjYc80 thread `fRqqEPlfcsQ` · 11 messages · 2026-05-22_
_Summarized: 2026-05-22 21:47 PDT · last-msg-time: 2026-05-22T00:40:06Z_

## What was discussed

Denny asked the bot to cherry-pick D106026708 into the OT notes repo. The bot discovered that EdenFS had crashed (both `~/notes` and `~/fbsource` not mounted) due to a disk-full condition (45 MB free on `/dev/vda4`). After Denny authorized cleanup ("go. and don't ask me again / for things you can handle"), the bot cleared `/tmp/.tmp*` orphans (100% → 87% disk used, 148 GB freed), restarted Eden, and applied the cherry-pick (commit `59bf49301f5a`).

## Key decisions made

- **2026-05-22T00:25:11Z** Denny: "go. and don't ask me again / for things you can handle" — bot is authorized to chain cleanup + eden restart + cherry-pick without asking for each step individually.
- D106026708 applied verbatim: adds `known_patterns.md` P51 (DPP per-worker scribe read lag diurnal) and new `references/escalation.md` (154 lines, symptom→team routing table).
- `sl push` to user/dennyzhang failed due to pre-existing `.bak` extension files in unpushed stack (not caused by cherry-pick); deferred to Denny for manual cleanup.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../mrs-ot-agent-src/known_patterns.md` | P51 row added (DPP per-worker scribe read lag diurnal) |
| `~/notes/.../mrs-ot-agent-src/references/escalation.md` | New file, 154 lines — symptom→team routing, S665454 lessons |

## Cluster / pattern references

- P51: DPP per-worker scribe read lag (diurnal) — newly added to known_patterns.md via this cherry-pick. Distinguishes from P04 (scribe write QPS spike) and P16 (generic DPP starvation). Source: S665454.

## Followup items (not yet done)

1. Denny to clean `.bak` extension files from unpushed stack (`ot-cron-health-state.json.bak`, `ot-human-attention-brief-state.json.bak`) to unblock `sl push`.

## Cross-refs

- SEVs discussed: S665454 (source for P51, referenced in escalation.md)
- Diffs: D106026708 (cherry-picked source)
- Related threads: none
