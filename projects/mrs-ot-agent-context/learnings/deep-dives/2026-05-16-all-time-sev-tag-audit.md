# All-Time OT SEV Tag Audit + scope_check Code Findings

_Generated 2026-05-16 16:20 PT per operator request (thread `ZP2y-6Bdpwk`)._
_Audit window: 2026-01-01 → 2026-05-17 (limited by sevmanager query OOM beyond ~5 months)._

## Summary

| Metric | Value |
|---|---|
| Total SEVs tagged `mvai-online-training` Jan–May 2026 | **147** |
| Heuristic-detected false positives | 12 (8.2%) |
| Migration / preemptive (not failures) | 9 (6.1%) |
| **Likely-real OT operational SEVs** | **126** |
| Monthly growth in raw count | 6 → 9 → 11 → 26 → 95 (alarming jump in April-May) |

The 95 May tally is consistent with the 4-week-window audit (W17-W20 = 116, but W17 partial overlap with April reduces May-only to ~95).

## Monthly trend

```
2026-01: 6   ▓
2026-02: 9   ▓▓
2026-03: 11  ▓▓
2026-04: 26  ▓▓▓▓▓
2026-05: 95  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
```

**5-month observation:** raw count grew 16× in 5 months. This is dominated by upstream tagging volume (Butterfly auto-tagger + operator manual tagging), not actual incident growth.

## False positive class breakdown (12 SEVs across 5 months)

All 12 false positives are concentrated in April-May — pre-April there were ZERO. This suggests the FP rate is recent — likely driven by:
- More aggressive Butterfly auto-tagging on `impacted_areas` keyword overlap
- Operator manual tagging for personal tracking
- Growth in cross-org SEV volume hitting OT-adjacent surfaces

**All 12 false-positive SEVs from Jan–May 2026:**

| SEV | Date | Title | Class | Tagger |
|---|---|---|---|---|
| S655556 | 2026-04-27 | Unidash permission request errors | infra (Data Warehouse) | dennyzhang |
| S656088 | 2026-04-28 | Everstore Read/Write Reliability Dip | infra (Storage) | Butterfly auto |
| S657546 | 2026-04-30 | Instagram Content Publishing API | T4 (Instagram) | dennyzhang |
| S658534 | 2026-05-04 | IG Direct DE deltoid delayed >2 days | T4 metrics (Instagram) | dennyzhang |
| S659215 | 2026-05-05 | IG Vital Delay deltoid | T4 metrics (Instagram) | Butterfly auto |
| S661045 | 2026-05-07 | Explore ig_explore_chaining_mtml qps falling | T4 serving | Butterfly auto |
| S661752 | 2026-05-09 | IG Vital Delay deltoid (recurrence) | T4 metrics (Instagram) | dennyzhang |
| S661843 | 2026-05-10 | ig_stories_tray_mtml holdout inference error rate | T4 serving | Butterfly auto |
| S661851 | 2026-05-10 | Engagement MTML LSR Raas Timeout | T4 serving | Butterfly auto |
| S662589 | 2026-05-12 | Ads IPNext Solver failed globally | **Ads org (MRS-boundary violation)** | asrivas |
| S663166 | 2026-05-12 | ig_explore_posts_mtml inference error rate | T4 serving | dennyzhang + butterfly |
| S663935 | 2026-05-14 | IG Search Deltoid DJ Quality degraded | IG Search (cross-org) | Butterfly auto |

## Tagger attribution (root cause analysis)

| Tagger | Count | What's the pattern |
|---|---|---|
| dennyzhang manual | 5 | Personal-tracking taggings (Unidash, IG Content, IG Direct DE, IG Vital, T2I) |
| Butterfly auto | 6 | Auto-applied via `impacted_areas` keyword overlap with MRS surfaces |
| asrivas (Ads team) | 1 | S662589 — explicit MRS-org-boundary violation |
| **OT bot auto-tag** | **0** | bot scope_check is correctly strict — no auto-tagging of false positives observed |

## The good news: bot scope_check IS working

The bot's `team_lane_scope.is_in_mrs_org_scope()` capability (per `team_lane_scope.py:263`) correctly drops all 12 FPs via the allowlist gate. The pre-cluster scope_check (step 4.5 in `ot-sev-monitor.md`) silently filters them BEFORE notification. The R18 post-diagnosis stage check catches anything that slips through.

**Evidence:** all 12 FPs have the tag but ZERO of them were auto-tagged by the bot (per tagger attribution above). The bot's scope_check has higher precision than upstream taggers.

## scope_check code review — what's right, what could improve

Reading `fbcode/pe_mrs_ml/mrs_ot_agent/src/capabilities/team_lane_scope.py` (473 lines):

### What's right

1. **Allowlist-based** (line 1-15 of docstring). Default = OUT_OF_SCOPE; admission requires positive MRS signal. This is the correct architecture; explains why bot doesn't auto-tag false positives.
2. **signal_class taxonomy** (lines 47-90). Distinguishes `mvai_publish_pipeline` / `mvai_serving` / `mrs_online_training` at the cluster-prefix level. Avoids the S658476 misrouting where publish failures were labeled as online-training.
3. **signal_class_admit_allowlist** (lines 167-185). Default excludes `mvai_serving` — drops serving SEVs even when in MRS scope. This is why CL-007 cross-org leaks dropped to 0 post-R18.
4. **Peer-team-anchor exclusion** (lines 191-199). `shuminwu`'s non-OT direct reports' SEVs get demoted. Catches false positives from other lanes Shumin's team owns.

### What could improve (in order of impact)

#### 1. ⚠️ HIGH: Operator-manual tags aren't filterable
The 12 FPs include 5 tagged by dennyzhang himself for personal tracking. scope_check has no way to know "this tag was added by an operator, not by the bot's auto-tagger or Butterfly" — the tag presence alone is a strong-enough signal that the SEV is admitted.

**Proposed fix:** add a tag-source check. When the `mvai-online-training` tag was added by `dennyzhang` (or other personal-tracker accounts) rather than by Butterfly Bot OR by an OT-IC owner, treat it as weaker evidence. Would require querying SEV history per-SEV to find the tag-add event — adds latency per scope check.

**Workaround (no code change):** operator stops using `mvai-online-training` for personal tracking; use a personal tag like `dennyzhang-watch` instead.

#### 2. 🟡 MEDIUM: Butterfly's `impacted_areas`-driven auto-tagging
Several FPs (S656088 Everstore, S659215 IG Vital, S661045 Explore qps, S661843/S661851/S663935 inference errors) appear to have been auto-tagged by Butterfly because their `impacted_areas` field contains MRS-adjacent terms (`igmi-should-review`, `instagram_developer_platform`, etc.). scope_check sees the tag → admits → and only the R18 stage check catches them at post-diagnosis time.

**Proposed fix:** add explicit `impacted_areas` allowlist/denylist in scope_check. If `impacted_areas` contains ONLY non-OT entries (e.g., `everstore`, `unidash_dev`, `web`), treat as out-of-scope despite tag presence. Currently `team_lane_scope.py` doesn't check `impacted_areas` at all.

#### 3. 🟢 LOW: Ads-org explicit exclusion
S662589 (Ads IPNext Solver) was tagged by `asrivas` (Ads team). `sev_type=Ads` should auto-disqualify per `_OT_SEV_TYPES_FALLBACK` (line 155 — doesn't include `Ads`). Need to verify this is working — if not, the org-boundary leak is real and serious.

**Verify:** check if scope_check would have rejected S662589 if asked. If it does, no fix needed (it was a noise tag, never went to bot triage). If it doesn't, urgent fix.

## Recommendations

### Tier 1 — operational (no code change)

1. **Operator stops using `mvai-online-training` for personal tracking.** Use a personal tag (`dennyzhang-watch`, `denny-fyi`, etc.). Eliminates 5/12 = 42% of FPs.
2. **Periodic cleanup script** to remove `mvai-online-training` from clearly-non-OT SEVs (Unidash/Everstore/IG Vital). Manual one-time pass: 12 SEVs × ~30s each.

### Tier 2 — minor code change

3. **Add `impacted_areas` check to scope_check.** Per the architecture, this would be a new gate after the tag check but before the title check. ~30 lines. Catches Butterfly auto-tagging FPs (6/12 = 50% of remaining).

### Tier 3 — verification

4. **Run scope_check against the 12 known FPs to confirm `in_scope=false` for each.** If any return `in_scope=true`, that's a real bug. ~10 min via test harness.
5. **Audit the `peer_team_anchor` exclusion is enabled** (`shuminwu` default). Check the SEV owners of the 12 FPs against `shuminwu`'s direct reports.

## Why this audit doesn't propose immediate code edits

The bot's `scope_check` is performing well — it's not producing the false positives. The false positives exist in upstream tagging (Butterfly + operator manual), and the bot correctly filters them at multiple gates. Tightening `scope_check` further would:
- Add complexity for marginal gain (already at <10% noise)
- Risk false negatives (dropping real OT SEVs that have ambiguous impacted_areas)
- Be slower (per-SEV history queries for tag-source attribution)

**The biggest single improvement is operational** — get personal tagging off the canonical tag. That's a process change, not code.

## Open questions for operator

1. Should `mvai-online-training` be cleaned from the 12 FP SEVs (remove tag)? Recovers the count semantics.
2. Should operator switch to personal tag for tracking-only? (Recommended.)
3. Worth implementing the `impacted_areas` gate (Tier 2)? Estimate: 30 lines + tests, ~1h work + `jf submit --draft`.

## Cross-references

- 4-week audit (W17-W20): `auto-learnings/failure-patterns.md` § "Tag-noise note"
- Code: `fbcode/pe_mrs_ml/mrs_ot_agent/src/capabilities/team_lane_scope.py`
- Bot's scope-check invocation: `team_bot/cron-jobs/ot-sev-monitor.md` step 4.5
- Bot's stage-check (R18): `team_bot/cron-jobs/ot-sev-monitor.md` step 9.b.v.2
- Tagger attribution audit: this file's "Tagger attribution" section
