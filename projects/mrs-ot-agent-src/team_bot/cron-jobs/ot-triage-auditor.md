# ot-triage-auditor — draft spec

**Status**: DRAFT (not yet enabled). Created 2026-05-19 by live session in thread `2w5Schmk83U` per operator request "C" (prototype + formalize).

**Purpose**: post-hoc audit of `ot-alert-monitor` + `ot-sev-monitor` triage outputs. Catches:
- Cross-ref step misses (SEVs / alerts / patterns the cron should have found)
- TZ rendering bugs in fire-times
- PAGE-on-engaged-owner over-paging
- app_layer_pkg variant conflation
- Carryover anchoring without re-verification
- Threshold-vs-cadence misclassification
- 0-relevant-SEVs claims that are provably false

Surfaces results via escalation ladder (silent → in-thread → morning brief → real-time page). Defaults strongly biased toward minimum-interruption.

---

## Schedule
- **Interval**: every 30 min (5-10 min lag after typical ot-alert-monitor / ot-sev-monitor completion windows)
- **Excludes**: itself + ot-cron-health-watch (avoid recursion)
- **Time budget**: ~5 min per run (operator-set 2026-05-19 thread `2w5Schmk83U` — extra headroom for thorough R-rule evaluation and cross-ref queries; matches existing heavy crons like ot-alert-monitor / ot-sev-monitor)

## State file
Path: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-triage-audit-log.jsonl`

JSONL append-only. One record per audited triage:
```json
{
  "audit_epoch": 1779200000,
  "audited_thread": "JnkWvEebHPY",
  "audited_cron": "ot-alert-monitor",
  "audited_run_at": "2026-05-19T08:50:11-07:00",
  "verdict_class": "TRANSIENT_NOISE",
  "tier": "self-heal | nudge | page | pass",
  "findings": [
    {"rule": "R13-tz", "severity": "self-heal", "detail": "fire time off by 3h: cron said 04:42, actual 07:42"},
    ...
  ],
  "verdict_change_recommended": false,
  "in_thread_followup_drafted": false,
  "brief_summary_line": "<one-line for morning brief if nudge-tier>"
}
```

---

## Procedure

### Step 1 — Find new triages to audit

```bash
sqlite3 -separator '|' /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "
  SELECT job_id, run_at, raw_response
  FROM job_runs
  WHERE job_id IN ('ot-alert-monitor','ot-sev-monitor','ot-post-monitor','ot-triage-summary')
    AND run_at > datetime('now','-3 hours')
    AND status='ok'
    AND (raw_response LIKE '%Bot reply: %' OR raw_response LIKE '%posted reply%' OR raw_response LIKE '%Issues summarized%')
  ORDER BY run_at;"
```

**Scope rationale**: includes 4 cron classes that produce triage-like output:
- `ot-alert-monitor` (hourly, gchat) — alert triages
- `ot-sev-monitor` (hourly, gchat) — SEV triages
- `ot-post-monitor` (15-min, Workplace) — Workplace post triages
- `ot-triage-summary` (daily, gchat + auto-files tasks) — catches the T271102844 class where bot pattern-summaries get cited as authoritative downstream

Workplace-surface gotcha: `ot-post-monitor`'s output schema uses `posted reply` markers (not `Bot reply: <url>`), and R-EV1 (TZ rendering) needs slightly different handling since Workplace posts don't expose `alert_created_time` epochs directly — use post `created_time` field instead.

Cross-check against state log — skip any `audited_run_at` already present.

For each new triage:
- Parse `raw_response` to extract: cluster ids, verdict tier, root-cause class, confidence, owner, model_id, SEV ids cited, Bot reply thread URL.
- Pull the bot's actual posted reply from the messages table (the raw response is the cron's summary; the bot reply in-thread is what operator sees).

```bash
sqlite3 ... "SELECT content FROM messages WHERE thread_name LIKE '%<thread_id>%' AND sender_unixname='ot-bot' ORDER BY create_time LIMIT 1"
```

### Step 2 — Run audit checklist

For each audited reply, evaluate these checks. Each check produces (pass / fail) and a severity tier if fail.

#### Cross-ref checks

- **R-XR1 — SEV substring scan**: for every `model_id` mentioned in the reply, query `meta sevmanager.sev list --in-progress` (3-day window) and search title + overview for the literal model_id substring. If the cron's reply says "no related SEVs" but a SEV explicitly names the model → **nudge**.
- **R-XR2 — Downstream-infra SEV scan**: for any reply mentioning `scribe`, `ZippyDB`, `Manifold`, `CAS`, `throttling`, `lag`, `capacity`, `GMPP`, `Hedwig`, `UMM`, search in-progress SEVs whose title matches the same domain (with synonym table). If cron said "0 relevant" but a matching SEV is live → **nudge**.

   **Terminology convention** (operator-locked 2026-05-19, threads `2w5Schmk83U` and `BclwYcL2-1I`): from the trainer's POV (T2), the **publish path** (T3 GMPP/Scribe/ZippyDB used for publishing, Hedwig, UMM) and **serving path** (T4 predictor) are **DOWNSTREAM**. The **ingest path** (T1 Scribe-for-DPP read, data preprocessing) is **UPSTREAM**. A ZippyDB throttle that delays publishing is a downstream-infra issue; a ZippyDB throttle that starves DPP reads is an upstream-infra issue. The cron's verdict classification MUST distinguish: `UPSTREAM_INFRA` vs `DOWNSTREAM_INFRA` (not generic `*_INFRA`).
- **R-XR3 — Auto-learn corpus scan**: grep `auto_learn/sev-dry-run-*.md` for verdict-class + model-type matches. If cron's `cluster_evidence=[]` but auto_learn has a direct analog → **nudge**.
- **R-XR4 — Carryover thread scan**: for any "FULL_SNAPSHOT missing" / "scribe lag" / similar repeating-condition triage, check if any thread in the last 7 days triaged the same model_id or sibling-pair with a verified root cause (upstream OR downstream). If yes and cron didn't cite it → **nudge**.

#### Evidence-quality checks

- **R-EV1 — TZ rendering**: parse `alert_created_time` epoch from the bot's reply (in the alert URL). Convert to America/Los_Angeles. Compare against any "fired at <time>" string in the reply. If off by >5min → **self-heal**.
- **R-EV2 — `mast-job error` cited for FAILED-attempt models**: if the reply describes a FAILED MAST attempt, the evidence row should cite the literal `error_message` from `meta ai.mast-job error --version=<N>`. If absent → **nudge**.
- **R-EV3 — Freshness pre-check**: for publishing-stability verdicts, the reply should cite a `meta ai.model.instance list` query taken within the last 5 min relative to the cron's run. If absent and verdict is NO ACTION → **self-heal** (add the freshness data).
- **R-EV4 — app_layer_pkg variant fidelity**: if the reply asserts "shared app_layer_pkg" between SEV X and model Y, the FULL pkg name including suffix (`_v4:6`, `:94407d8`) must match. If only family-root matches → **nudge** (or **page** if used as PRIMARY BLOCKER claim).

#### Verdict calibration checks

- **R-VC1 — PAGE-on-engaged-owner**: if verdict is `🔴 PAGE <owner>` AND the cited SEV (if any) has `status=In Progress` AND `owner_name` populated AND no escalation criteria met → **nudge** (verdict should be capped at MONITOR for already-engaged owners on L4+ SEVs).
- **R-VC2 — Threshold-vs-cadence**: if verdict is `THRESHOLD_MISFIT` AND `gap_at_fire > detector_threshold_hours` (where threshold is provable) → **page** (THRESHOLD_MISFIT misclass; real failure being silenced).
- **R-VC3 — NO-ACTION on active crash**: if verdict is `🟢 NO ACTION` AND `meta ai.mast-job error --version=<latest>` returns non-empty error in last 6h → **page** (active crash being marked OK).
- **R-VC4 — Family-recurrence**: count CL-XXX firings across all `model_id`s of the same family in last 24h via grep on thread archive. If ≥5/24h across ≥2 models AND verdict is per-model MONITOR (not family-escalated) → **nudge** (propose family-level SEV).

### Step 3 — Tier the findings

For each audited triage, take the **max severity** across all findings:

| Findings tier | Action |
|---|---|
| All checks pass | Append to audit log only. Silent. |
| Max = self-heal | Optionally post in-thread correction. Increment self-heal counter. |
| Max = nudge | Log + add to morning-brief summary. No thread post unless >1 nudge in same thread. |
| Max = page | Real-time gchat ping to operator: `🚨 [auditor] verdict-override on <thread>: cron said X, audit says Y. Detail: <reason>` |

### Step 4 — Self-heal posting (when applicable)

For `self-heal` findings AND `auto-correction posting=ON` (operator-configured, default OFF):
- Post a follow-up reply in the audited thread with the correction.
- Format:
  ```
  🔍 *Auditor self-heal*: <one-line correction>
  • Original: <what cron said>
  • Verified: <what audit found>
  • Verdict tier unchanged: <verdict>
  ```
- Mark `in_thread_followup_drafted=true` in the audit log entry.

### Step 5 — Morning-brief integration

The morning brief (`ot-human-attention-brief` cron, daily 08:00 PT) should read the audit log and emit a single section:

```
🔍 Auditor (last 24h):
  • <N> triages audited
  • 🔴 Pages: <N> — top: <thread> <one-line>
  • 🟠 Nudges: <N> — top: <thread> <one-line>
  • 🟡 Self-heals: <N>
  • Top recurring rules: <top-3 R-rule ids>
  • Trend: <delta vs prior day>
```

If `🔴 Pages == 0 AND 🟠 Nudges == 0 AND 🟡 Self-heals == 0`: omit section entirely (no noise).

### Step 6 — Persist

Append one JSONL record per audited triage. Cap log file at 10000 lines (rotate oldest → `.archive`).

### Step 7 — Respond

```
HEARTBEAT_OK {triages_audited: N, findings: F, pages: P, nudges: NU, self_heals: SH, passes: PA, in_thread_followups_posted: FU}
```

If `pages == 0 AND nudges == 0 AND self_heals == 0`: respond JSON-summary only, no gchat post (per RULES.md signal-only).

If `pages >= 1`: also post the real-time ping per step 3 (NOT in thread; new top-level message in space).

---

## Safety

- **READ-ONLY by default.** Cron reads from sqlite, meta CLI, notes corpus. No writes to fbcode, no SEV comments, no external posting except gchat.
- **One gchat post tier exception**: when configured `auto-correction posting=ON` (default OFF), posts in-thread self-heal corrections. Operator can toggle by editing this cron's config.
- **Page rate-limit**: max 1 page per audited thread per 6h. Beyond that, demote to nudge in next brief.
- **Mocking infra**: provides a `--dry-run` flag (or env var `OT_AUDITOR_DRY_RUN=1`) for evaluation runs — disables ALL posting, only writes to audit log. Use for initial calibration tonight.

## Open knobs (operator-configurable, all default to safe values)

| Knob | Default | What it controls |
|---|---|---|
| `auto-correction-posting` | OFF | If ON, posts self-heal corrections in-thread automatically |
| `page-threshold` | verdict-change only | Promote nudge → page when finding is more severe than this |
| `nudge-daily-cap` | 5 | Beyond this, batch to next day |
| `morning-brief-include-pass-count` | OFF | If ON, include `<N> triages passed cleanly` in brief |

---

## Backlog: rules to add (numbered from prior backlog in `WApKJGlKThc`)

This auditor's R-rules map 1:1 to the 17-item backlog of prompt-edits identified by live-session review across today's threads:

| Backlog # | Maps to R-rule |
|---|---|
| #1 PAGE-on-engaged-owner guard | R-VC1 |
| #2 THRESHOLD_MISFIT vs REAL classification | R-VC2 |
| #3 ModuleNotFoundError → sl annotate | R-EV2 (extended) |
| #4 auto_learn corpus search | R-XR3 |
| #5 app_layer_pkg variant fidelity | R-EV4 |
| #6 Family-level recurrence detector | R-VC4 |
| #7 Carryover re-verification | R-XR4 |
| #8 MISSED_COMPLETION detector | (separate — lives in ot-cron-health-watch) |
| #9 Temporal coincidence ≠ causation | R-EV4 (related) |
| #10 OneDetection re-fire dedup explanation | (reference doc edit, not auditor) |
| #11 Pre-fire freshness check | R-EV3 |
| #12 Family-recurrence auto-SEV proposal | R-VC4 |
| #13 Alert-time TZ rendering | R-EV1 |
| #14 Evidence confidence calibration | (covered by R-EV2/EV3) |
| #15 Open-SEV downstream attribution suppression | R-XR2 + R-XR4 |
| #16 SEV scan filter audit | R-XR2 |
| #17 Model-id substring scan | R-XR1 |

Coverage: 14 of 17 backlog items map to auditor rules. #8 lives in ot-cron-health-watch (already covered there). #10 is reference-doc only. The remaining 14 collapse into 11 R-rules — single auditor cron instead of 17 cron-prompt patches.

---

## Calibration plan (proposed)

1. **Tonight (operator confirms)**: run dry-run against today's 6 triages already in sqlite. Output is the digest already shown in `2w5Schmk83U` (11 findings, 0 pages).
2. **Tomorrow morning**: re-run dry-run against last 24h. Confirm finding rate (~2/triage today) stays consistent.
3. **Day 3**: if calibration holds, enable cron live with `auto-correction-posting=OFF` and `page-threshold=verdict-change only`. Morning brief gets +1 section.
4. **Week 1**: review trend. If nudges trend down (proves cron prompt-edits are landing), declare success. If trend flat, escalate top-2 R-rules into the source crons' prompts directly (defense in depth).

---

## Why one cron, not 17 prompt patches

Prompt-patching 17 separate edits across 2-3 source crons:
- High risk of regression in unrelated triage paths
- Hard to track which edit fixes which class
- Each edit lengthens the source cron's prompt → context budget pressure
- Operator has to review 17 individual changes

One auditor cron:
- Single review surface
- Source crons stay lean
- A/B comparable (audit findings before/after a source-prompt patch lands)
- Calibration data accumulates in one log → trend analysis possible

The trade-off: auditor adds 30-min latency between bot output and feedback. Acceptable for the 🟡/🟠 tiers (which don't need real-time response); the 🔴 page tier still pings immediately so verdict-overrides aren't delayed.

---

## Status

- [x] Draft spec written
- [ ] Operator review of spec
- [ ] Dry-run against today's 6 triages (proven; see `2w5Schmk83U` audit digest)
- [ ] Tomorrow morning dry-run against full 24h
- [ ] Promote to live cron in `team_bot/cron-jobs/ot-triage-auditor.md` after 3-day calibration
- [ ] Add `MANIFEST.json` entry (interval=1800s, no auto-mitigation)
- [ ] Update `ot-human-attention-brief` to include auditor section
- [ ] Update `RULES.md` to register the new cron + its escalation ladder
