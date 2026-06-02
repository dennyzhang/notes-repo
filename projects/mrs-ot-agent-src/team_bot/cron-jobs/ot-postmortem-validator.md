[ot-postmortem-validator cron] Daily 22:30 PT (15-min stagger after ot-daily-learning-mitigated-alerts at 22:05). Read the last 24h of postmortem digests written by ot-daily-learning-mitigated-{sevs,posts,alerts} + ot-knowledge-curation crons (which run in cron context WITHOUT Agent tool access and therefore self-flag `🚫 Validator unavailable` or `validator_status: unavailable`). For each digest, run the validation that the upstream cron couldn't: verify pattern matches against `known-patterns.md`, verify SEV/alert/post metadata via `meta` CLI, verify cluster citations against `failure-patterns.md`, verify mega-learning entries cite valid CL-NNN. Post a single summary reply per parent digest with ✅ confirmed / ⚠️ corrections / 🆕 new-pattern-proposals.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-postmortem-validator-state.json` — `{"validated_digests": [{"thread_id": "<id>", "digest_run_id": "<cron_job_run_id>", "validation_at": "<iso>", "verdict_counts": {"confirmed": N, "corrected": N, "proposed": N}}], "last_run_epoch": <int>}`. Time budget: 5-15 min per run depending on digest count.

Background: Two operator messages on 2026-05-16 (21:10 PT thread gMO2L7p9xaM, 22:16 PT thread LqKW1jLtNeM) flagged "🚫 Validator unavailable (no Agent tool in cron context); digest published unvalidated" — a structural limitation of the cron context (no Agent tool means no meta CLI, no cross-reference checks). Today both digests turned out correct via manual operator-in-the-loop validation, but the gap is real. This cron splits data-collection (sevs/posts/alerts crons, cron context, no agent) from validation (this cron, agent context, full meta access).

Cron context limitations driving this design:
- **ot-daily-learning-mitigated-{sevs,posts,alerts}** + **ot-knowledge-curation** run in cron-only context: no Agent tool, no meta CLI, no sqlite access beyond local
- They produce postmortem digests + per-incident archive files
- They self-flag `🚫 Validator unavailable` when they can't cross-check
- Validation requires: meta sevmanager.sev describe (confirm root cause), meta sevmanager.sev search (find sibling pattern instances), grep failure-patterns.md (verify cluster IDs cited exist), grep known-patterns.md (verify P-row IDs cited exist)

This cron RUNS in agent context (per the OT bot's standard agentic-cron policy), so it CAN do all of the above.

## Procedure

1. **Read state file.** Extract `validated_digests`. If missing/corrupt, default empty list + create file fresh.

2. **Enumerate digest cron-runs from last 24h.** Query sqlite:
   ```bash
   sqlite3 -separator '|' /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db \
       "SELECT id, job_id, run_at, raw_response FROM job_runs \
        WHERE job_id IN ('ot-daily-learning-mitigated-sevs','ot-daily-learning-mitigated-posts','ot-daily-learning-mitigated-alerts','ot-knowledge-curation') \
        AND run_at > datetime('now','-24 hours') \
        AND (raw_response LIKE '%Validator unavailable%' OR raw_response LIKE '%validator_status: unavailable%' OR raw_response LIKE '%validator_status%unavailable%') \
        ORDER BY run_at;"
   ```
   For each row not already in `validated_digests`, queue for validation.

3. **For each queued digest:**

   a. **Extract claims from digest** (raw_response text):
      - Cluster IDs cited (regex `CL-\d{3}`)
      - P-row IDs cited (regex `P\d{1,2}`)
      - SEV IDs (regex `S\d{5,}`)
      - Post IDs (regex `W\d{10,}`)
      - Alert IDs (regex `A\d{10,}`)
      - Hypothesis-vs-confirmed status flags (e.g., "P38/P17 candidate" vs "P52 confirmed")

   b. **Validate cluster citations:**
      ```bash
      grep "^### CL-NNN" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/patterns/failure-patterns.md
      ```
      Flag any cited CL-NNN that doesn't exist in failure-patterns.md as `⚠️ unknown cluster`.

   c. **Validate P-row citations:**
      ```bash
      grep "^| P<NN>" ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-domain/how/known-patterns.md
      ```
      Flag any cited P-row that doesn't exist as `⚠️ unknown P-row`.

   d. **For each SEV ID cited, verify root cause matches digest claim:**
      ```bash
      meta sevmanager.sev describe --sev <ID> -o json | jq -r '.title, .description'
      ```
      Compare extracted root-cause-keywords from digest against actual SEV metadata. Flag major mismatch (e.g., today's S665135 case where digest said "auto-start silent stall" but actual was "Shampoo NaN") as `⚠️ MISATTRIBUTION`.

   e. **For each pattern claim ("MATCH P19", "PROPOSE P55", etc.), check:**
      - Title-keyword fit: does title actually contain P-row's signature keywords?
      - Stage fit: T1 vs T2 vs T3 — does cited stage match the failure layer?
      - Falsifier check: any of the P-row's listed falsifiers visible in digest evidence?
      Flag mismatches as `⚠️ pattern-fit weak`.

   f. **New-pattern proposals (e.g., "PROPOSE P55"):**
      Verify pattern doesn't duplicate an existing P-row. Verify it's distinct from sibling CL-NNN sub-mechanisms. If genuinely novel → ✅ accept and recommend landing; if duplicate → ⚠️ flag as redundant.

4. **Compose validation reply per digest:**

   Post in the SAME thread as the original digest (per gchat RULE #1: reply-in-thread). Format:

   ```
   ✅ *Validator pass (2026-05-16 22:30 PT)*

   *Confirmed:*
   - CL-013 cited × 2 ✓ (both exist in failure-patterns.md)
   - P38/P17 pair-hypothesis ✓ (both exist; falsifiers compatible with digest evidence)

   *Corrections / Misattributions:*
   - (none) | OR
   - S665135 in CL-009 evidence: actual root = Shampoo NaN (see CL-017). Operator already fixed at 21:05 PT ✓

   *New-pattern proposals reviewed:*
   - P55 (OT restart clears scribe holdout): novel ✓, distinct from P28 (publish-stall drift), landed db3e0fd49dec

   *Outstanding:*
   - A2126294138 AGG alert: 27h unassigned, no triage on file — needs operator routing
   - 2 of 5 alerts unmapped to cluster (CL-AGG placeholder — registration decision pending)

   _Run id: <cron_job_run_id> · 3 digests validated · 0 misattributions in this run_
   ```

   Hard cap: 3500 chars. If overflow, prioritize: corrections > new-pattern review > confirmations > outstanding.

5. **Update state file** with validated digest entries + verdict counts.

6. **Output summary** at end:
   ```
   {digests_validated: N, confirmations: N, corrections: N, proposals_reviewed: N, unmapped_archives_flagged: N}
   ```

## Anti-spam

- One validator reply per digest (no repeats if validator re-runs hit same digest_run_id from state file)
- If no digests to validate (all already in state OR no validator-unavailable flags in 24h — check BOTH `Validator unavailable` (emoji prefix) AND `validator_status: unavailable` (JSON field) wording), skip silently with `HEARTBEAT_OK`
- Cap 5 digests validated per run (prevents runaway from backlog)

## Self-escalation thresholds

- If misattribution rate >20% across a 7-day window → post escalation to operator with the misattribution list
- If new-pattern-proposal rate >2/day for 3+ days → propose Proposal D (ot-knowledge-curation extension to auto-update cluster status) — operator decision

## Read-only

- NEVER modify the source digest text or comment on the alert/SEV/post itself
- ONLY post reply in the gchat thread where the digest landed
- NEVER call any meta state-mutation (no add-tag, no comment-create, etc.)

## Distinct from sibling crons

- **ot-daily-learning-mitigated-{sevs,posts,alerts}**: data-collection in cron context (no agent, no meta CLI)
- **ot-postmortem-validator** (THIS): validation in agent context (full meta CLI access)
- **ot-knowledge-curation** (existing nightly 23:00 PT): cross-incident pattern detection + Phabricator diff drafting
- **ot-knowledge-distillation** (existing 13:30 PT weekday): mines incidents/resolved-{sevs,posts,alerts}/ for cross-issue patterns

This cron sits BETWEEN data-collection and knowledge-curation/distillation:
  collect (no agent) → VALIDATE (this cron, agent) → curate/distill (agent)

## Created

2026-05-16 in response to two operator-flagged `Validator unavailable` messages within 1 hour (thread gMO2L7p9xaM 21:10 PT for SEVs cron, thread LqKW1jLtNeM 22:16 PT for alerts cron). Both digests turned out correct via manual operator-in-the-loop validation, but the pattern is recurring and warrants automation. Per Proposal D-adjacent in `~/notes/.../mrs-ot-agent-context/IMPROVEMENT-PROPOSALS.md` (this is the simpler standalone version; Proposal D extends ot-knowledge-curation to also do this work plus auto-update cluster status).
