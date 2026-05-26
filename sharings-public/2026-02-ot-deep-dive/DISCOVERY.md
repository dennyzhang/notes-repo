# Discovery: Online Training Knowledge Sharing

## Raw Request

Provide a team knowledge sharing session for the PE team on online training workflows. Based on one month of ramp-up on OT, share what has been learned through a deep-dive session.

A Workplace post was created to collect questions from the team: https://fb.workplace.com/groups/1298528517372911/posts/2019640618595027

## Questions Collected (from Workplace poll, 2026-02-22)

Ranked by votes:

| # | Question | Votes |
|---|----------|-------|
| 1 | Suppose we have 1-a-b-c-2-d-e-3 snapshot versions (1,2,3 = full; a,b,c,d,e = delta). How to resume OT from 1 — with what timestamp data? | 4 |
| 2 | How would we tell a delta snapshot is healthy? | 3 |
| 3 | How does Scribe work into OT? | 3 |
| 4 | Does OT always mean streaming updates? | 2 |
| 5 | Is UMM the source of truth for delta snapshot versions? | 2 |
| 6 | How is update actually applied (balancing inference vs training)? | 1 |
| 7 | What are the differences in reliability for streaming vs small batch? | 1 |
| 8 | Item delta update flow | 1 |

## Scope

- **Audience**: MRS Training Infra PE team
- **Format**: Deep-dive session (presentation + discussion)
- **Content source**: One month of hands-on OT ramp-up experience, including work on IG ATS latency decomposition, snapshot test flakiness, training hang detection, and OT debug agent

## Potential Topics (from ramp-up experience)

1. **OT Architecture Overview** — how online training pipelines are structured (trainer, data pipeline, model publish, delta publish)
2. **OT Lifecycle** — from model config to serving (training loop → snapshot → UMM → inference)
3. **Key Systems** — MAST/MRS, DPP, UMM, Manifold, TGIF, ZCH, delta publish (sparse vs dense)
4. **Debugging OT Failures** — common failure patterns, tools (Scuba, OT dashboard, SEV triage)
5. **ATS (Age-To-Serve)** — what it measures, how to decompose it, team responsibilities
6. **Snapshot & Delta Publish** — full snapshot vs sparse delta vs dense delta, how publish works end-to-end
7. **Training Hangs** — detection mechanisms, gaps, common causes
8. **GPU Test Infrastructure** — E2E snapshot tests, how to validate OT changes locally

## Open Questions

1. What format works best — single long session or multi-part series?
2. What depth level — overview for everyone, or deep technical for OT-adjacent engineers?
3. Should we produce a written artifact (wiki, doc) alongside the session?
4. Timeline — when to schedule the session?
