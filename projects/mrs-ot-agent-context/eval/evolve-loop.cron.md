# OT-agent evolve loop — cron spec (for reinstall)

The self-improvement loop that runs the eval harness and commits eval-proven
improvements to notes. Registered via Claude Code's `CronCreate` (session
scheduler), NOT the myclaw daemon. Durable = persisted to
`~/.claude/scheduled_tasks.json`, survives Claude restarts; auto-expires after
7 days (re-run to renew).

- **schedule:** `7,27,47 * * * *` (every 20 min, off the :00/:30 marks)
- **recurring:** true
- **durable:** true
- **current job id:** 5352322b (changes on each reinstall)

## Reinstall (any of these)

1. **Easiest:** tell Claude in the OT session: *"reinstall the eval job from
   `eval/evolve-loop.cron.md`"* — it re-runs `CronCreate` with the prompt below.
2. **Manual:** call `CronCreate` with cron=`7,27,47 * * * *`, recurring=true,
   durable=true, and the verbatim PROMPT block below.
3. **Renew before 7-day expiry:** same as above (delete the old id first with
   `CronDelete` if it still exists; check with `CronList`).

## Cadence / mode notes
- Iterations are fast (resume/incremental eval ~40s–min; full scoping mine ~10 min).
  Every 20 min is safe: gaps exceed a typical iteration, and the prompt's
  IDEMPOTENCY guard returns HEARTBEAT_OK if a prior run is still in flight, so
  runs self-throttle instead of overlapping.
- More frequent = faster Goodhart on the gold sample → the zero-regression gate
  runs on the FULL 180 (not just the working sample). Keep that invariant.
- BATCH mode is gated: Stage 1 complete the fitness fn → Stage 2 trust grader →
  Stage 3 batch-mutate. See PROMPT.

## PROMPT (verbatim — keep in sync with the live job)

```
OT agent evolve loop (BATCH mode). Goal: raise the OT master agent's eval fitness fast but safely. Harness: ~/.myclaw-ot-bot/eval-flow.js (triage quality) + ~/.myclaw-ot-bot/eval-scoping.js (detection_recall + scoping_precision). Notes mirrors as .txt under mrs-ot-agent-context/eval/ (notes rejects .js). Fitness = calibration .35 / detection_recall .20 / scoping_precision .15 / owner .15 / decisiveness .15; hallucination = hard per-case gate.

IDEMPOTENCY: if a prior run is still in progress or nothing is pending, respond HEARTBEAT_OK immediately (runs fire every 20 min; do not start overlapping work).

SEQUENCING — do NOT batch-mutate until the measuring stick is complete and trusted:
STAGE 1 (fitness-completion): if detection_recall/scoping_precision are still null/unwired, run eval-scoping.js, fold its two numbers into the composite, and persist. Expand the gold set toward the full 180 eligible + add in-MRS-non-OT scoping negatives. If generalization is still a leak-proxy, implement temporal hold-out (P-row/R-rule creation dates from sl history). One stage-1 item per run is fine.
STAGE 2 (grader trust): before any auto-accept, run a codex/second-model co-grader on a sample and record agreement; if agreement is low, fix the grader, do not mutate.
STAGE 3 (BATCH mutation — only once stages 1-2 done): each run (a) generate K candidate improvements (K=5-10) from the ranked failure list + weakest dimensions (today: detection_recall 0.42, owner 0.25, the 30% R-rule confabulation -> citation-discipline guard P-007); (b) A/B-eval all K IN PARALLEL using INCREMENTAL eval (re-run only the gold cases a change can affect); (c) greedily KEEP every candidate that raises composite AND regresses zero prior gold cases ON THE FULL 180 (not just the sample) AND passes codex adversarial review; (d) after keeping a batch, re-eval the COMBINED set and drop any that regress in combination. Apply kept changes by COMMITTING to the NOTES repo (operator-authorized). NEVER auto-submit a Phabricator diff; NEVER mutate live external surfaces; notes->fbcode mirror stays operator-gated.

Report ONE dense block: composite delta vs prior run + per-change deltas + commit refs + current weight_covered. If only stage-1/2 work or nothing beat baseline, respond HEARTBEAT_OK + one line. Obey CLAUDE.md density + never-auto-submit. Append each run to eval/reports/.
```
