# Auto-Learn Worked Example — Pattern P27

How a real triage chain produced a new entry in `known_patterns.md`.
Use this shape when applying the [SKILL.md Auto-Learn](../../../mrs-ot-agent-src/SKILL.md#auto-learn--record-new-patterns-as-you-discover-them)
check at the end of a triage session.

## Source

2026-04-30 Workplace post from Renze ("preserve OT"). Not a SEV — the
auto-learn discipline applies to **any** signal source (SEV, alert,
user post, internal report) where the agent diagnoses a reusable
cause→symptom→fix triple.

## Triage chain

| Step | What | Tool / data |
|------|------|-------------|
| 1 Symptom | `fbpkg info mvai_app_fa_<HASH>` reports not-found, despite a landed Configerator diff | Renze's post + `fbpkg info` |
| 2 Ground-truth queries | Package exists, built 17:48 PT yesterday | `fbpkg info` |
| | Cconf diff committed 01:46 PT yesterday | `meta phabricator.diff metadata` |
| | Post timestamped 17:33 PT (15 min before package was built) | `meta workplace.post content` |
| 3 Reasoning | Configerator publishes the cconf immediately on land, but the fbpkg only exists after a sandcastle build. The build runs on a 00:00 UTC daily trigger and takes ~48 min for a full mvai app-layer. Renze's post landed inside the dead window between commit and first-build. | — |
| 4 Verdict | Self-resolves; no Configo problem | — |
| 5 Auto-learn check | Not in `known_patterns.md` (P03/P17 cover **expired** fbpkg, not **not-yet-built**). Confirmed via three CLI calls. Reusable — the dead window will hit other engineers landing `fbpkg.cconf` for the first time. | — |

## Outcome

Recorded as **P27** in `known_patterns.md`:
- Pattern: Preserved fbpkg cold-start race
- Stage: T2
- Fix: Wait for next 00:00 UTC sandcastle build trigger + ~1h build; no
  action if <24h post-commit. Verify diff committed via
  `meta phabricator.diff metadata --number=D<id>`. Escalate
  Configo/sandcastle oncall if >24h.
- Owner: MVAI / self-resolves
- Source: Renze 2026-04-30 Workplace post
