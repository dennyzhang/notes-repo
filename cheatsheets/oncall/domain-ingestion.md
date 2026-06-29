# Domain Ingestion — How New Reliability Learnings Become Canonical Rules

The practice of converting **observed incidents → reusable canonical rules** so
the same SEV class never costs full-investigation time twice. This cheatsheet
captures the rules themselves; the cron that mines them is
`scripts/cron-ai-infra-reliability-miner.sh`, which writes to
`learnings/ai-infra-reliability/PATH-TO-EXPERT.md`.

**Load this cheatsheet** when: writing a SEV postmortem, reviewing a SEV
follow-up diff, designing a new change-safety gate, evaluating whether a
proposed agent guardrail covers a *category* of failure or a single instance,
or upleveling a one-off finding into a canonical rule.

---

## Promotion gate (so rules don't bloat)

A finding is **PROVISIONAL** until it appears in N ≥ 3 independent runs of the
miner (different SEVs, different diffs, different authors). Only after the 3rd
reinforcement does it get promoted to STABLE and into the top-15 canon in
`PATH-TO-EXPERT.md §2`. Every rule below has cleared the gate or is being
worked toward it — drift in either direction is logged in `§5 Monthly Deltas`.

When you adopt a rule from here in a diff/post/SEV write-up, **cite the rule
number + the original SEV(s)** so reinforcement is auditable.

---

## Rule 1 — Atomicity at push time, not at land time

**A single logical config change split across two independently-scheduled
conveyors is NOT atomic at push time.** The halves go live out of order. The
dependent reads its default (often 0) and zeroes the downstream computation.
Each half passes its own canary because the canary only exercises that one
conveyor.

**Category fix:** a deterministic land-blocking review-agent check on any diff
that mixes two-conveyor families, forcing one-diff-per-conveyor + land the
dependency first.

**Evidence:**
- [S649738](https://www.internalfb.com/sevmanager/view/649738) — IG Reels
  ranking zeroed, ~5% WoW time-spent regression for ~90 min
  ([D100842308](https://www.internalfb.com/diff/D100842308) mixed RaaS config
  + IG ranking-graph config; RaaS pushed first, referenced a `global_all`
  value the graph config hadn't defined yet → defaulted to 0).
- [S350271](https://www.internalfb.com/sevmanager/view/350271) — same class,
  prior occurrence.
- [Config Push Safety WP post](https://fb.workplace.com/groups/279624285784940/permalink/2471071386640208/).

**Operationalized by:** MRS Argus code-review agent now posts a land-blocking
finding on any diff mixing the two families.

**When to invoke:** reviewing any diff that touches >1 config family in the
same change, or designing a new config surface where dependent values come
from sibling pipelines.

---

## Rule 2 — Forward-fix binaries must be built from the tenant's pinned revision, not trunk head

**[PROJECT CANDIDATE — broad customer pain, high impact. Tracked in
`projects/PIPELINE.md` as #1.]**

When a SEV requires emergency forward-fix, building the patched binary from
**trunk head** silently pulls in every unrelated change between the tenant's
last green pin and now — including changes that may themselves be in-flight
or broken. The fix lands but introduces collateral. The right action is to
cherry-pick the fix onto the tenant's pinned revision and build from there.

**Category fix:** an emergency-build workflow that defaults to the tenant's
last-known-good pin and refuses trunk-head builds without explicit override.

**Status:** Provisional — first observed in the cycle ending 2026-06-22.
Promotion gate not yet met.

---

## Adding a new rule

1. Mine the SEV / postmortem / launch evidence (the miner does this nightly;
   manual additions go through the same gate — never bypass).
2. Frame the rule as **mechanism + category fix**, not as a one-off
   remediation. The mechanism is what makes the rule reusable.
3. Cite ≥ 2 evidence IDs (SEV S-numbers, WP post permalinks, diff D-numbers).
4. Mark `[PROVISIONAL — 1/3]` until 3 independent reinforcements land.
5. When promoting to canonical: add to `PATH-TO-EXPERT.md §2` and back-link
   to this cheatsheet's rule number.

**Mining cron:** `scripts/cron-ai-infra-reliability-miner.sh` — runs Mon/Thu
09:17 PT, fans out across SEV Review + Workplace reliability groups + repo
notes delta, dedups against `seen.jsonl`, writes a new run-block to
`PATH-TO-EXPERT.md §5`.

Last updated: 2026-06-22
