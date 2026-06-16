# Known Issues — Fingerprints & Lifecycle

Adds two capabilities to the CL-NNN pattern system:
1. **Fingerprint:** deterministic queries that confirm "yes, this is exactly CL-NNN again" vs "looks similar but isn't"
2. **Lifecycle:** state machine from discovery through root-fix, with post-fix recurrence checks

---

## Lifecycle States

```
NEW → CONFIRMED → MITIGATING → FIX_LANDED → MONITORING → ROOT_FIXED → RETIRED
                                                  ↑              |
                                                  └── RECURRING ←┘ (fix didn't work)
```

| State | Meaning | Entry criteria | Exit criteria |
|---|---|---|---|
| NEW | Pattern observed once, not yet validated | First incident matches a novel symptom | Fingerprint defined + 2nd incident matches |
| CONFIRMED | Recurring pattern with deterministic fingerprint | ≥2 incidents confirmed by fingerprint | Fix work begins (diff in progress) |
| MITIGATING | Fix in progress (diff drafted, under review) | Diff created or workaround deployed | Diff lands or workaround confirmed effective |
| FIX_LANDED | Fix deployed but not yet proven | Diff landed + deployed to prod | 4 weeks with zero fingerprint matches |
| MONITORING | Watching for recurrence after fix | Entered FIX_LANDED state | 4 weeks clean → ROOT_FIXED; any match → RECURRING |
| ROOT_FIXED | Fix proven — pattern hasn't recurred in 4+ weeks | 4 consecutive weeks with zero fingerprint matches | Never (terminal) — unless RECURRING |
| RECURRING | Fix landed but pattern still fires | Fingerprint matches after FIX_LANDED | Re-enter MITIGATING with updated root cause |
| RETIRED | Pattern no longer relevant (system deprecated, model decommissioned) | Owner declares irrelevant | Never |

**Key rule:** A pattern can ONLY move to ROOT_FIXED through the MONITORING gate. "We landed a fix" ≠ "the pattern is fixed." The fingerprint must stop matching for 4 weeks.

---

## Fingerprint Schema

Each known issue gets a fingerprint: a sequence of queries with expected results that deterministically confirm "this IS the known issue."

```
- cl_id: CL-NNN
  name: <human name>
  lifecycle_state: <NEW|CONFIRMED|MITIGATING|FIX_LANDED|MONITORING|ROOT_FIXED|RECURRING|RETIRED>
  state_entered: <date>
  
  fingerprint:
    preconditions:
      - <condition that must be true for this fingerprint to apply>
    checks:
      - query: <Q-NNN or inline query>
        expect: <what the result should be if this is the known issue>
        weight: <required|supporting>  # required = must match; supporting = strengthens confidence
    confidence_rule: all required checks match + ≥1 supporting → CONFIRMED match
    false_positive_guards:
      - <condition that would make the fingerprint match but ISN'T this issue>
  
  fix_tracking:
    diff: <D-number or "none">
    owner: <unixname>
    expected_land: <date or "unknown">
    post_fix_check: <query to run after fix lands to verify it worked>
    
  recurrence_log:
    - date: <YYYY-MM-DD>
      incident: <SEV/alert/thread ref>
      fingerprint_match: <true|false>
      notes: <any deviation from expected fingerprint>
```

---

## Known Issues Registry

### CL-013: Training Example-Age Spike

- lifecycle_state: CONFIRMED
- state_entered: 2026-05-18
- fingerprint:
  - preconditions:
    - Model is OT (TMS ONLINE_READY)
    - MAST job is RUNNING
  - checks:
    - query: Q-001 (Training Example Age)
      expect: >30 min sustained for >15 min
      weight: required
    - query: Q-002 (Training QPS)
      expect: non-zero (trainer is running, not dead)
      weight: required
    - query: Q-040 (Scribe QPS)
      expect: stable or dropped (distinguishes data pipeline issue from trainer issue)
      weight: supporting
    - query: Check for active DPP/Scribe/ZippyDB SEVs
      expect: if active infra SEV → CL-003 (not CL-013)
      weight: required (exclusion)
  - confidence_rule: example age >30 min + QPS non-zero + no active infra SEV → CL-013
  - false_positive_guards:
    - Active infra SEV (DPP/Scribe/ZippyDB) → this is CL-003, not CL-013
    - QPS = 0 → this is a zombie (DP-001), not an example-age issue
    - Example age spike <15 min → transient, wait before confirming
- fix_tracking:
  - diff: none (multiple root causes — R-007, R-008, R-009, R-012, R-015, R-017)
  - owner: multiple
  - post_fix_check: "Example age stays <5 min for 4 consecutive weeks"
- recurrence_log:
  - date: 2026-05 (4 weeks in a row)
    incident: multiple alerts
    fingerprint_match: true
    notes: Rank #1 by recurrence

### CL-001: Snapshot Stuck CREATING / Full Snapshot Missing

- lifecycle_state: CONFIRMED
- state_entered: 2026-05-18
- fingerprint:
  - preconditions:
    - Model is OT (TMS ONLINE_READY)
  - checks:
    - query: Q-010 or Q-011 (Full Snapshot Status, family-dependent)
      expect: no VALID snapshot for >2x expected cycle
      weight: required
    - query: Q-003 (MAST Job State)
      expect: RUNNING (job alive but snapshot not publishing)
      weight: required
    - query: Q-005 (Training Iteration Progress)
      expect: iterations advancing (trainer working, publisher stuck)
      weight: supporting
    - query: Q-050 (Root Model Snapshot — retrieval only)
      expect: if retrieval model, check upstream root model health
      weight: supporting
  - confidence_rule: no snapshot >2x cycle + job RUNNING + iterations advancing → CL-001
  - false_positive_guards:
    - Job is DEAD → this is a crash-loop, not a publish stall
    - Retrieval model with root_model_snapshot_id stuck → upstream issue (not CL-001 proper, but related)
    - dai_modelstore shows 0 events but gmpp shows activity → schema gap (Q-011 corrected path)
- fix_tracking:
  - diff: multiple (3+ root mechanisms per INDEX.md)
  - post_fix_check: "Full snapshot cadence within SLO for 4 consecutive weeks"
- recurrence_log:
  - date: 2026-05-23
    incident: facebook_reels_ifu_i2i 2132070936
    fingerprint_match: true (partial — root cause was upstream dependency, not publisher)
    notes: Stream publishes masked the issue. Full fused snapshot stalled 8+ hours due to root model crash-loop.

### CL-012: StuckJobDetector Coverage Gap (Zombie Jobs)

- lifecycle_state: CONFIRMED
- state_entered: 2026-05-18
- fingerprint:
  - preconditions:
    - Model is OT (TMS ONLINE_READY)
    - MAST job is RUNNING
  - checks:
    - query: Q-002 (Training QPS) or DP-001 pattern
      expect: QPS = 0 for >1 hour
      weight: required
    - query: Q-005 (Training Iteration Progress)
      expect: iteration count not advancing
      weight: required
    - query: Q-014 (Hedwig Publisher Activity)
      expect: isActive=false (optional — covers silent publisher variant)
      weight: supporting
    - query: Q-080 (TMS/MAST Desync)
      expect: states match (rules out DP-006 desync as the cause)
      weight: supporting (exclusion)
  - confidence_rule: QPS=0 >1h + iterations not advancing + job RUNNING → CL-012
  - false_positive_guards:
    - TMS/MAST desync → this is DP-006/D106193941, not CL-012
    - Job just started (<15 min) → startup phase, not zombie
    - PT2 compilation in progress → slow start (DP-002), not zombie
- fix_tracking:
  - diff: D-001 through D-007 proposed (D-007 landed)
  - owner: training platform
  - estimated_impact: ~512 GPU-hr/mo waste
  - post_fix_check: "Zero RUNNING jobs with QPS=0 >1h across fleet for 4 consecutive weeks"
- recurrence_log:
  - date: 2026-05-23
    incident: reranker 2125081901 (6 days zombie, 1,152 GPU-hr wasted)
    fingerprint_match: true
    notes: SJD didn't catch it — process alive, no error, no crash. isActive=false variant.

### CL-DESYNC: TMS/MAST State Desync (NEW — from D106193941)

- lifecycle_state: FIX_LANDED
- state_entered: 2026-05-26 (D106193941 fix)
- fingerprint:
  - preconditions:
    - Model registered in TMS
    - Fire or Chronos job launched the MAST job
  - checks:
    - query: Q-080 (TMS/MAST State Desync)
      expect: MAST RUNNING + TMS PAUSED or EXPIRED
      weight: required
    - query: Q-081 (Crash-Loop with External Kill)
      expect: ≥3 DEAD attempts <10 min + kill message contains "training_management_system"
      weight: required
    - query: Q-004 (MAST Job Errors)
      expect: kill message from TMS reconciler, NOT from training error
      weight: supporting
  - confidence_rule: MAST/TMS desync + TMS reconciler kill in logs → CL-DESYNC
  - false_positive_guards:
    - Manual TMS pause during planned maintenance → expected, not a bug
    - Brief desync during normal TMS state transition (<5 min) → transient
- fix_tracking:
  - diff: D106193941 (re-raise UNAUTHORIZED instead of swallowing)
  - owner: xingjiama
  - post_fix_check: "Zero MAST RUNNING + TMS PAUSED occurrences across fleet for 4 consecutive weeks (excluding manual pauses)"
- recurrence_log:
  - date: 2026-05-11
    incident: model 2128686073, 21 crash-loops
    fingerprint_match: true
    notes: Fire swallowed TMS UNAUTHORIZED, launched orphan MAST jobs

---

## How the Bot Uses This

### During triage (matching)

```
For each active known issue (lifecycle_state in [CONFIRMED, MITIGATING, FIX_LANDED, MONITORING]):
  1. Check preconditions — if not met, skip
  2. Run required fingerprint checks
  3. If all required checks match + ≥1 supporting → CONFIRMED match
  4. Check false_positive_guards — if any trigger, downgrade or reclassify
  5. Report: "This is a recurrence of CL-NNN (lifecycle: <state>)"
     - If FIX_LANDED: "Fix D-NNNN landed but pattern still recurring → move to RECURRING"
     - If MONITORING: "Post-fix recurrence detected → move to RECURRING"
```

### After triage (lifecycle update)

```
If fingerprint matched:
  - Add entry to recurrence_log
  - If lifecycle = MONITORING or FIX_LANDED → transition to RECURRING
  - Update recurrence count in failure-patterns.md

If fingerprint did NOT match any known issue:
  - Is this a novel pattern? → Create CL-NEW with lifecycle_state=NEW
  - After 2nd confirmed match → promote to CONFIRMED + define fingerprint
```

### Weekly lifecycle audit

```
For each known issue:
  - If FIX_LANDED and no fingerprint match in 4 weeks → promote to ROOT_FIXED
  - If CONFIRMED and fix_tracking.diff is "none" for >8 weeks → flag as stale (no one working on it)
  - If ROOT_FIXED and fingerprint matches again → demote to RECURRING
  - If RETIRED for >12 weeks → archive (remove from active checks to save triage time)
```

---

## Evolution Log

| Date | Change | Trigger |
|---|---|---|
| 2026-05-26 | Created with CL-013, CL-001, CL-012, CL-DESYNC fingerprints | Session learnings + D106193941 |
| 2026-05-26 | Defined 8-state lifecycle with MONITORING gate | User requirement: "old patterns may be root fixed" |
