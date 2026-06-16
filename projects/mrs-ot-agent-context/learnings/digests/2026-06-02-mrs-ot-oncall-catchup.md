# 2026-06-02 — MRS Online Training Oncall catch-up (gchat `spaces/AAQATpEgSyk`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 16 new human messages spanning 2026-06-01T11:48 → 2026-06-01T15:30 PT in **MRS Online Training Oncall** (18 members; primary contributors: Denny Zhang × 7, Paul Lu × 5, Li Lu × 2, Anthony Foiani × 1)._

_Window: 7d default (delta since last_msg_create_time 2026-05-26T13:56 PT). Skip-until: not set (active polling)._

## P0 — bot-integration-blocking items

**Paul Lu going on recharge 2026-07-02 — oncall will be at 2 members**

Paul Lu (lupaul) confirmed recharge start July 2, 2026 (2026-06-01T11:53). OT oncall is already at 3 members (down from 5); Paul's absence drops it to 2. Li Lu asked Michael Chen to contact Arbaz's manager about joining OT oncall ASAP (2026-06-01T12:09). Escalation is in progress.

Bot implication: from 2026-07-02, triage load falls entirely on Denny + Li Lu. Bot efficiency matters more, not less. Do not auto-assign anyone else (CLAUDE.md rule: `--owner=dennyzhang` only). If a triage produces a task, owner = Denny; add Arbaz as subscriber if/when he joins the rotation.

**D107167718 — known-issues.md added to MVAI OT agent**

Paul Lu (2026-06-01T15:30): "D107167718 to add known-issues reference to track problems and solutions we've done from previous sevs. There's more to add - just adding the 2 most prominent examples for now." Li Lu accepted.

Bot implication: `known-issues.md` now exists in the MVAI OT agent codebase. The bot should incorporate this file into triage context — it is the team's canonical "we've seen this before" reference. Check for this file in fbsource and load it during triage.

## P1 — significant nuance / sub-mechanisms

**Zombie job sub-class: d-state subprocess blocking elastic agent clean shutdown**

S665478 root cause (Paul Lu, 2026-05-26, prior context confirmed in this window): publishing subprocess enters **d-state** (uninterruptible sleep) → blocks elastic agent's main thread from clean shutdown → Tupperware reports job as healthy → SJD has no effect (cannot kill).

This is mechanically distinct from:
- NCCL timeout zombie (ranks stuck, heartbeat dead, SJD kills eventually)
- SIGABRT cleanup zombie (process received signal, cleanup hung)

For this d-state variant: SJD no-op is expected, not a failure of SJD. Correct escalation is pytorch_distributed oncall (they own elastic agent). Denny was already escalating to MAST + TW for S665454 (Threads Retrieval, same suspected root cause).

**Sibling agent (Paul Lu's) handling easy OT issues**

Denny (2026-06-01T11:55): "easy issues are managed by Paul's agent." A separate agent owned by Paul Lu is triaging easy OT issues. Coordination implication: the bot should not re-triage issues already picked up by Paul's agent. If a SEV or alert is already showing active triage context from Paul's agent, mark as "in-triage by peer agent" and stand down unless specifically asked.

## P2 — references / good-to-know

- S665478 (reels lsr mb9 OT hanging) + S665454 (Threads Retrieval U2M stuck) — same suspected root cause (d-state subprocess), both now resolved per prior runs.
- Anthony Foiani suggestion: junior SWE from `mrs_model_metadata` team had good luck on easy SEVs. Precedent if staffing question reopens.
- Paul going on recharge = likely full month (Li Lu asked, Paul did not explicitly confirm duration in this window).

## Cross-references

None this week.

## Open coordination threads

- **Arbaz oncall recruitment** — Li Lu → Michael Chen ask (2026-06-01T12:09). No response captured. Re-check next week.
- **Oncall coverage July 2** — escalated to Michael Chen and Shumin Wu by Denny (2026-05-26). Resolution needed before Paul's recharge.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Load `known-issues.md` from MVAI OT agent during triage | Add to `SKILL.md` triage init: read `known-issues.md` alongside `known_patterns.md` | 20 min |
| P0 | Paul recharge July 2 → staffing context for task routing | Add to `USER.md` or cron context: Paul unavailable from 2026-07-02; Li Lu + Denny only | 10 min |
| P1 | d-state subprocess zombie — distinct from NCCL/SIGABRT variants | Add to `known_patterns.md` as P-class: "zombie: d-state blocking elastic agent; SJD no-op expected; escalate to pytorch_distributed" | 30 min |
| P1 | Sibling agent (Paul's) on easy OT issues — dedup rule | Add to `CLAUDE.md` or `SKILL.md`: if peer agent already triaging, stand down unless @mentioned | 15 min |
