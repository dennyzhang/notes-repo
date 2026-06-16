# 2026-06-13 — MVAI OT Dev catch-up (gchat `spaces/AAQAXSNWvcM`)

_Auto-distilled by `ot-ingest-gchat` cron. Source: 35 human messages spanning 2026-06-08T12:14 → 2026-06-12T16:13 in **MVAI OT Dev** (8 members; primary contributors: Denny Zhang ×19, Paul Lu ×5, Li Lu ×5)._

_Window: 7d. first-run: false._

## P0 — bot-integration-blocking items

- **App-layer vs base-layer patch classification** — Paul Lu documented the rule 2026-06-09. The bot needs this to correctly classify fix-target when a mitigation diff is needed:
  - Check overlay paths at https://fburl.com/thrift_fiddle/ca6m6uo2
  - Change under an app-layer overlay dir → patch app-layer
  - Change outside overlay dirs (e.g., `mvai_infra`) → patch base-layer
  - Change spans both → patch both
  - D108045383 landed implementing this as a bot capability.

- **OT master agent design doc** shared with team: https://fburl.com/collab-files/kzjw2g3p (2026-06-12). Li Lu and Paul Lu are reviewing. This is the canonical design reference for the OT agent going forward.

## P1 — significant nuance / sub-mechanisms

- **D108074069 landed** (2026-06-10): [mvai-ot agent] Add deep-dive investigation format for log-heavy analysis. Accepted by Denny. Affects output format for log-heavy/deep-dive triage — bot should now emit structured investigation sections not prose dumps.

- **TTFB (Time-to-First-Batch) monitoring** — new concept introduced this week. If QPS doesn't go non-zero within ~1h of job start, it's a slow-start failure class. Events logging now tracks job-start→train-start delay. Task T275298327 filed for Arbaz Khan (new team member) to build slow-start monitoring. Alert threshold: if TTFB for all prod models in a PG > 1h, fire warning alert to OT oncall. Bot: this is a new failure class to recognize — "slow start" is distinct from "job crash" and "stale model".

- **New team member: Arbaz Khan** ramping up on OT SEV handling. Min Ni (on his team) is adding OT support coverage. Michael Chen coordinating. For ownership/routing questions, do not assume Arbaz has full OT context yet.

- **IFR (Inference Freshness Rate?)** — Workplace post https://fb.workplace.com/groups/4239452842845159/permalink/24133890539641428/ — team tracking 100% goal, "last piece." Denny asking for blockers + offering to contribute.

## P2 — references / good-to-know

- App-layer overlay paths canonical reference: https://fburl.com/thrift_fiddle/ca6m6uo2
- OT master agent design doc: https://fburl.com/collab-files/kzjw2g3p (shared 2026-06-12)
- T275298327 — slow-start monitoring ramp-up task for Arbaz Khan

## Cross-references

- None this week from this space.

## Open coordination threads

- **py3.12 OOM (S669019)** — Paul Lu driving revert option; Paul still investigating root cause as of 2026-06-11. No fix diff mentioned in this space this week.
- **TTFB alert** — threshold and PG aggregation agreed in principle; implementation non-trivial per Paul. No diff filed yet.
- **IFR tracking** — Denny asking for blockers, no response captured in this window.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | App/base-layer classification rule (Paul Lu canonical doc) | SKILL.md: add patch-target decision tree section | 30m |
| P0 | Link to OT master agent design doc in context | mrs-ot-context/: add design-doc reference entry | 10m |
| P1 | TTFB slow-start as new failure class | known-patterns.md: add slow-start entry with T275298327 ref | 30m |
| P1 | Deep-dive format from D108074069 | verify bot output matches new format after D108074069 | 20m |
