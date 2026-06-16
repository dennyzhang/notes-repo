# 2026-06-13 — RT Infra WS2: OT Reliability & Understanding catch-up (gchat `spaces/AAQAR1xHaQU`)

_Auto-distilled by `ot-ingest-gchat` cron. Source: 41 human messages spanning 2026-06-08T06:31 → 2026-06-12T08:38 in **RT Infra WS2: OT Reliability & Understanding** (30 members; primary contributors: Dave Kotfis ×20, Josef Cohen ×9, Denny Zhang ×5)._

_Window: 7d. first-run: false._

## P0 — bot-integration-blocking items

- **SEV S675130 (SEV0) / S675238** on 2026-06-12 08:07 PT: all offline, recurring, and online training jobs disabled across MAST, Flow, and OT. OT bot should treat any job-restart failure on/after 08:07 PT on 06-12 as infrastructure-disabled-not-model-failure until S675130 resolves. Root cause unknown from chat; S675130 is the parent.

- **S669019 (Python 3.12 OOM)** — confirmed root: py3.12 breaks reference counting in C++/Python bindings during in-trainer publish. Py3.10 revert is in place and validated (multiple arms, no memory leak). Py3.12 fix not yet landed. POC to escalate: Aniket Panse (Cinder team). Bot: when classifying S669019-class OOM (OOM during publish, not training), sub-class as `publish-python-leak` not `training-OOM`.

## P1 — significant nuance / sub-mechanisms

- **H100 vs A100 latency effect is delayed.** mvai-training-online-2124304578 switched from A100→H100 pinned on 2026-05-29 (D107567877). Scribe delay did NOT drop immediately — improvement came days later. When diagnosing latency improvement trends, do not assume instant hardware effect; check pin date vs. metric improvement curve separately.

- **Sparse streaming + weight manager** launched on Reels ESR VM on 2026-06-09. Model registry update (D108089755: baseline model id → 2141728943 for `ig_reels_tab_vm_esr`) was delayed 1 day by merge conflict; resolved 2026-06-11. SLICK / dashboards may have a dashed link on sparse streaming success until registry is live. Not a training failure — a registry lag.

- **CS Omni launch** went out 2026-06-10 night. Expected: example ages for Reels ESR to decrease in subsequent runs.

- **Freshness SLO pre-launch check** — team has a Claude skill for this as part of launch review. Process is not reliably being followed. Li Lu flagged in 2026-06-11 brainstorm: need visibility enforcement. Bot: when a model shows freshness regression shortly after a launch window, check whether the pre-launch SLO check was actually run before calling it an OT failure.

## P2 — references / good-to-know

- p50/p90 example age scuba: https://fburl.com/canvas/kyx5l0ir (item model age p50 trend, Reels)
- mlhub UI: check execution details on a specific job version to see hardware (A100/H100) schedule history
- H2 brainstorm session happened 2026-06-11 morning (Dave driving, Paul missed due to doctor appointment; reviewing notes)

## Cross-references

- None this week from this space.

## Open coordination threads

- **py3.12 OOM fix** is unresolved. Escalation path via Aniket Panse (Cinder) established but no fix diff mentioned. Follow-up: was a fix diff filed? D108089755 is model registry only — not the py3.12 fix.
- **Model registry D108089755** — was this landed and shipped? As of 2026-06-11T06:45, Kang was rebasing due to merge conflict.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | Classify S675130-window failures as infra-disabled, not model-failure | ot-sev-monitor: add infra-shutdown window detection | 1h |
| P0 | Sub-class OOM during publish as `publish-python-leak` (S669019 class) | known-patterns.md: new sub-class entry | 30m |
| P1 | Delayed H100 effect: don't assume instant hardware latency improvement | triage-discipline.md: hardware-effect caveat | 20m |
| P1 | Pre-launch freshness SLO check is part of launch review — add to launch triage checklist | SKILL.md launch-triage checklist | 30m |
