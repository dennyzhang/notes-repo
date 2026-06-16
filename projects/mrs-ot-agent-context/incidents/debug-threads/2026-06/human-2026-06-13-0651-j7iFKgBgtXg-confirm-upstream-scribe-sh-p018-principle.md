---
name: human-2026-06-13-0651-j7iFKgBgtXg-confirm-upstream-scribe-sh-p018-principle
description: Operator drove bot to build confirm-upstream-scribe.sh (Scuba mast_admission_control_decisions), file dedup task for refuted 878102693, RCA the miss, and save P-018 as generic human input
metadata:
  type: project
  human_involved: true
---

# Thread Summary: confirm-upstream-scribe.sh Built + P-018 Principle Created

_Source: spaces/AAQAVOjYc80 thread `j7iFKgBgtXg` · 38 messages · 2026-06-13 06:51–09:51 PDT_
_Summarized: 2026-06-13 21:04 PDT · last-msg-time: 2026-06-13T16:51Z_

## What was discussed

Operator pushed bot to follow through on the e78lVJptOAI rule: build a solid confirming query for CL-003/P57 (scribe-quota) UPSTREAM_INFRA class. Bot discovered existing P57 "confirmation" (lag + SEV coexistence) was not causation, found Scuba `mast_admission_control_decisions` as the decisive source, and backtested on real data. Operator then pushed for: (a) auto-fix task on refuted cases, (b) RCA of the miss, (c) saving the input as generic human input (P-018).

## Key decisions made

- [14:02:02Z] Ground-truth source for scribe-quota confirmation: Scuba `mast_admission_control_decisions` — `rejected=1` + `policy_name=ONLINE_TRAINING_SCRIBE_USAGE` + tenant_path. Decisively separates real throttling from inferred false-links.
- [14:02:36Z] Backtest results: 878102693 (ig_organic_feed_mtml) → REFUTED (IG tenant `root/Instagram/feed/...`, 0 rejections — not throttled by S669133 "Facebook/Feed" quota); 2119481158 → CONFIRMED (45 rejections on `root/Facebook/Feed/ifr/...`)
- [14:29:59Z] Rule wired: REFUTED → file deduped `--owner=dennyzhang` tracking task (stops re-triage + dedup key); CONFIRMED → upstream SEV tracks (R20, no redundant OT task). T275762912 existing dedup for FB/Feed confirmed case.
- [14:29:59Z] T275766595 filed: tracks 878102693 REFUTED (IG tenant never throttled, mis-attributed to S669133 each cycle)
- [14:32:32Z] RCA of miss: UPSTREAM_INFRA was the one verdict class with no proof-of-work artifact requirement → "blame the SEV" at high confidence needed zero confirming evidence → validator had nothing to flag. Compounded by: no confirming query; R21 groups models under shared SEV without tenant check; R20 forbade follow-up task. Fix: class-agnostic rule (any external-attribution verdict requires [VERIFIED] linking metric regardless of class).
- [16:51:01Z] P-018 created: `human-input/knowledge/principles/P-018-external-attribution-needs-confirming-metric.md` — class-agnostic; external attribution high-confidence needs [VERIFIED] linking metric (scope + window); missing → build it; [INFERRED] if unverified. Cataloged in INDEX.md.

## Files / artifacts touched

| path | what changed |
|---|---|
| `tools/confirm-upstream-scribe.sh` (notes) | New: Scuba mast_admission_control_decisions query for scribe-quota confirmation |
| `triage-discipline.md` (notes) | UPSTREAM_INFRA row + class-agnostic external-attribution bullet; REFUTED→task rule |
| `human-input/knowledge/principles/P-018-*.md` (notes) | New principle file |
| `human-input/knowledge/principles/INDEX.md` (notes) | P-018 cataloged |
| T275766595 | Filed: 878102693 REFUTED tracking task |

## Cluster / pattern references

- [CL-003] / [P57] — `confirm-upstream-scribe.sh` is the decisive discriminator for this class; coexistence-based P57 confirmation is deprecated in favor of mast_admission_control_decisions query
- [P-018] — new principle: external-attribution high-confidence verdict needs [VERIFIED] confirming metric

## Followup items (not yet done)

1. T275766595: drive 878102693 mis-scope detection to fix — real cause of scribe_read_proxy lag on IG tenant still undetermined; owner: dennyzhang

## Cross-refs

- SEVs discussed: S669133 (Scribe/Feed quota, chronically open)
- Tasks: T275762912 (FB/Feed scribe quota, existing), T275766595 (878102693 REFUTED, new)
- Related threads: `e78lVJptOAI` (rule origin), `kELsQU_CtLk` (outreach budget rule)
