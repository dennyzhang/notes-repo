# Cheatsheet Flywheel — Status

| Phase | Item | State | Notes |
|-------|------|-------|-------|
| 1 | Structural gate + audit + heal (`lint-cheatsheets.sh`) | ✅ done | gate/fix/stamp/fix-index/audit-grounding |
| 1 | Grounding gate (trust-gradient) | ✅ done | CS_STRICT=block, human=warn |
| 1 | Adversarial content verify (LLM) | ✅ done | `cheatsheet-content-verify.sh` |
| 1 | Acceptance gate (one call) | ✅ done | `cheatsheet-accept.sh` (det→LLM) |
| 1 | Dedup sweep (existing corpus) | ✅ done | `cheatsheet-dedup-sweep.sh` |
| 1 | Daily sweep + grounding backlog | ✅ done | `cheatsheet-sweep.sh` |
| 1 | Weekly harvest | ✅ done | `cheatsheet-harvest.sh` |
| 1 | Prompt-coaching + placement hook | ✅ done | live, pinned-top, hook-enforced |
| 2 | Golden backfill (cold-start) | ✅ done | `golden-backfill.py` → 58 `diff/` cases |
| 2 | Golden ongoing collector | ⏳ next | tee corrections + outcomes + gate verdicts → `golden/`; lane-filter + sensitive-strip |
| 3 | Eval harness (linchpin) | ⛔ blocked | needs **operator oracle approval + 5-case spot-check**; oracle = existing gates for `diff/` |
| 4 | Provisional tier + probation | ⬜ todo | `provisional:` frontmatter + lint check; shadow-load + measure |
| 5 | Usage telemetry | ⬜ todo | session-start load log → demote-not-delete |

## The one blocker
Phase 3 (eval) needs the operator to **approve the diff-domain oracle (the existing gates) and
spot-check ~5 golden cases** in `golden/diff.jsonl`. Everything labeled eval/probation/trim/promote
waits on that. Everything else is build-without-the-operator.

## Next build (no blocker)
Phase 2 ongoing collector — tee `cron-autolearn-corrections.sh` Before/After (+ landed/reverted
outcomes + gate verdicts) into `golden/`, so the answer key grows from every correction.

_Last updated: 2026-06-14. Maintainer: dennyzhang._
