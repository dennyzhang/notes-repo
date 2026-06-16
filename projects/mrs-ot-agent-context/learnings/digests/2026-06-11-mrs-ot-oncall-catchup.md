# 2026-06-11 — MRS Online Training Oncall catch-up (gchat `spaces/AAQATpEgSyk`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 38 human messages spanning 2026-06-01T15:30:49-07:00 → 2026-06-10T16:43:02-07:00 in **MRS Online Training Oncall** (18 members; primary contributors: Li Lu (16), Denny Zhang (13), Anthony Foiani (5))._

_Window: 7d delta (window extends to 06-01 since last_msg was 06-01; first catchup for this space with real signal). Skip-until: not set (active polling)._

## P0 — bot-integration-blocking items

**D108195174: DPP-starvation confirm/refute + preemption discriminators — RADAR verified.**
OT agent failed to detect DPP starvation in 6/10 SEV1. D108195174 closes this detection gap. Scribe drain is explicitly the DPP team's root cause to own; bot correctly stops at confirming DPP starvation is present and discriminates preemption vs starvation. Bot should integrate this once landed.

**Routing table for dependent SLA — new canonical reference.**
URL: https://fburl.com/collab-files/90kcp6mg (allows commenting like wiki). Denny shared 6/10 for review by Paul Lu and Li Lu. Defines which team owns which OT failure component interactions. Bot should use this as the authoritative routing table when handing off to dependent component teams (DPP, scribe, etc.).

**Alert misconfiguration pattern: root model ID vs ST model ID in detector.**
ig_reels_tab_vm_esr alert fired against root model id 2141728947; should be ST model id 2141728943. Li flagged to model owner; Anthony Foiani confirmed fix. This is a recurring pattern: model launches promote a new root model but alert detectors are configured against the old root rather than the ST entity. Launch runbook must include: "update alert detector to ST model id." Bot should detect when a monitored model id is a root id with a known ST counterpart and suggest the alert config fix.

## P1 — significant nuance / sub-mechanisms

**Scribe drain → DPP starvation causation chain: bot defers correctly.**
Root cause chain confirmed: scribe_token_generation_success_row_cnt drop → DPP starvation → OT data starvation. Li suggested adding scribe drain explicitly to D108195174; Denny explicitly declined — bot's job is to confirm DPP starvation and hand off to DPP team for what caused the drain. Bot scope boundary = DPP starvation surface, not upstream scribe infra.

**H2 theme: "OT failures need to recover faster."**
Multiple recovery latency failure modes named: fail slow, kill slow, start slow. Denny's H2 project proposal: measure recovery latency with breakdown, identify bottleneck, tune. This is the organizing theme for H2 reliability work. Bot should route recovery-latency issues to this theme when writing triage summaries.

**S669019 oncall handoff: Li Lu is primary OT oncall; Paul Lu driving revert.**
Li Lu's oncall rotation started ~6/9. S669019 (py3.12 OOM in in-trainer publisher) is the most urgent ongoing ask. py3.10 revert option being pursued by Paul. Denny briefed Li on assuming the SEV as highest-priority oncall item.

**DPP metrics identification: what else to check beyond starvation.**
Open design question: OT agent currently confirms DPP starvation via examples-read proxy. Need additional DPP metrics to confidently confirm OT → DPP failures vs other origins. scribe_token_generation_success_row_cnt named as ingress signal. Discussion not concluded — no canonical DPP metric list for OT agent yet.

**OT bot still off critical path; team deep-dive session planned.**
Denny's stated position 6/10: OT bot is still in infancy, not comfortable putting it on critical path. Next team meeting will have an OT bot deep-dive session. Li suggested OT bot could help fix invalid detectors (https://fburl.com/monitoring/x33ohqs7); Denny will discuss scope at the meeting.

## P2 — references / good-to-know

- https://fburl.com/monitoring/x33ohqs7 — invalid detector monitor Li referenced for OT bot auto-fix potential
- D107167718 (known-issues.md reference in MVAI agent) — already processed from 6/01 boundary
- D108195174 RADAR verified — check if full land is pending or already completed
- "OT failures need to recover faster" = H2 organizing theme for Li Lu's roadmap contribution

## Cross-references

- D108195174: consistent across MVAI OT Dev and MRS OT Oncall spaces — DPP starvation gap is the same event, no contradiction.
- S669019: consistent across all 3 active spaces. py3.10 revert is the active mitigation; py3.12 fix still needed.

## Open coordination threads

- **Routing table review** (https://fburl.com/collab-files/90kcp6mg): Li said "will review this evening" (6/10). Status unknown — follow up if routing table is not yet signed off.
- **DPP metrics list**: what metrics beyond examples-read proxy to use for OT→DPP confirmation? No conclusion in window. Needs follow-up discussion or a separate design doc.
- **OT bot deep-dive session**: date not set. Denny said "next team meeting." Track.
- **S669019 py3.12 fix**: py3.10 revert is safe but py3.12 root fix (binding reference counting) still open. No assignee named for py3.12 fix path in window.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | D108195174 DPP-starvation confirm/refute integration | sev-monitor + alert-monitor: add DPP starvation probe once diff lands | 1h post-land |
| P0 | Routing table as canonical dependent-component handoff reference | Known-patterns / triage-depth: add routing table URL | 15m |
| P0 | Root-vs-ST model ID alert misconfiguration pattern | alert-monitor: check alert model id vs ST model id registry | 2h |
| P1 | Scribe drain scope boundary: bot stops at DPP starvation | triage-depth.md: document explicit scope stop at DPP surface | 20m |
| P1 | H2 "recover faster" theme: route recovery-latency findings to this | triage-summary: tag recovery-latency findings with H2-recover-faster | 30m |
| P1 | Additional DPP metrics for OT→DPP attribution | Pending design discussion; add scribe_token_generation_success_row_cnt as P0 probe | 2h after discussion |
