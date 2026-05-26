[ot-daily-learning-debugging cron] Daily morning. Distill new learnings from last 24h of ot-post-monitor + ot-alert-monitor + ot-sev-monitor runs (the bot's *debugging* output during real-time triage), PREPEND to ledger (newest first), optionally fold operational rules into source crons' prompts, and message digest to user. Renamed from `ot-daily-learnings` 2026-05-12 to clarify input corpus (debugging output) vs sibling `ot-daily-learning-mitigated-sevs` (closed SEV postmortems).

Files:
- Ledger (read + prepend — newest first): /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md
- Prompt backups dir (write): /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/cron-prompt-backups/
- DB: /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db

Procedure:

1. Read learnings.md so you know what has been recorded — never duplicate.

2. Query job_runs from last 24h (scan ALL OT triage cron sources):
   sqlite3 -separator '|' /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "SELECT job_id, run_at, status, delivered, raw_response FROM job_runs WHERE job_id IN ('ot-post-monitor','ot-alert-monitor','ot-sev-monitor') AND run_at > datetime('now','-24 hours') ORDER BY run_at;"

3. **Pre-filter raw_response: strip out-of-org SEV references.** Before distilling, scrub each raw_response of any SEV/alert/post/Workplace ID that step 4.5 or step 9.b.v of source cron classified as out-of-scope (sibling-org: Ads, WhatsApp, Wearables, Oculus, AR Effects, FacOps, FAIR, Datacenter, MSL). Indicators marking OUT_OF_ORG_DROP: `out of OT scope`, `sev_type=Ads`, `sev_type=WhatsApp`, `Ads org`, `out-of-scope`, `dropped at step 4.5`, `silent drop`. **Do NOT distill any learning whose trigger references an out-of-org SEV ID — that re-introduces the leak.** Acceptable: phrasing about the regex (e.g., "step 4.5 should also catch substring X"), never naming sibling-org SEV.

4. Read each (filtered) raw_response. Distill candidate learnings — concrete things that change cron behavior or improve future diagnosis. Examples: "Skip posts authored by MyClaw / ot-bot to avoid feedback loop." (operational); "Posts with only Workplace permalink need triage — fetch linked post body." (operational); "MAST job exit code 137 = OOM kill; recommend doubling memory." (domain pattern). Skip vague observations and known-already items.

5. Classify each learning:
   - **operational**: behavioral rule that changes how a cron runs. → append to ledger AND amend relevant cron's prompt.
   - **domain (pattern)**: NEW cause→symptom→fix triple suitable for `known-patterns.md`. → append to ledger AND propose appending to `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-domain/how/known-patterns.md` (see step 5b).
   - **domain (red herring)**: hypothesis that LOOKED right but wasn't, with non-trivial cost. → propose appending to Ruled-Out List in `known-patterns.md`.
   - **domain (other)**: observation about diagnosis style or one-off config issue. → ledger only.

5b. **Pattern auto-learn proposals.** For each domain-pattern learning, draft one-row entry per SKILL.md "Auto-Learn" format. Include in daily digest under `🧠 PATTERN PROPOSALS` section. DO NOT auto-apply — pattern DB is operator-curated. Format requires:
   - **Next sequential ID** — MUST be computed at runtime from current `known-patterns.md`, not hardcoded. Run BEFORE drafting any P-row:
     ```bash
     grep -oE '^\| P[0-9]+' ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/human-input-domain/how/known-patterns.md | grep -oE '[0-9]+' | sort -n | tail -1
     ```
     Next P-ID = that number + 1. Hardcoding (e.g., "P56 proposed") causes collisions when multiple crons or operators propose the same day; 2026-05-17 thread `suPsRC2fGdc` had P56/P57/P58 collisions from yesterday's ledger vs today's operator-landed Shampoo NaN P56. **Always re-read `known-patterns.md` at proposal time. If proposing N rows in one run, assign sequential IDs starting from max+1, max+2, ..., max+N.** Same discipline for any cron drafting `known-patterns.md` entries (ot-knowledge-curation, ot-daily-learning-debugging, ot-knowledge-distillation, manual landings).
   - Short pattern name (≤40 chars).
   - Error keywords / symptoms.
   - Stage (T1/T2/T3/T4).
   - Fix (command, diff number, or "wait Xh" verdict).
   - Owner (team that fixes, or `self-resolves`).
   - Time to apply (wall-clock for human).
   - Source: which cron run derived it + which SEV/alert/post.

5c. **Implementation-delta proposals (mandatory per 2026-05-01 operator rule).** For EVERY learning surfaced, classify implementation update target and DRAFT specific change. Don't just describe — produce diff or sqlite UPDATE statement. Targets:

| Learning class | Implementation target | Output shape |
|---|---|---|
| Triage discipline (e.g., "always run X before Y") | `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/SKILL.md` Triage Discipline section | Specific bullet point + line context |
| New cause→symptom→fix triple | `known-patterns.md` Quick-Match Table | Full P-row drafted (verify+fix+owner+falsifier) |
| Cron behavior change | sqlite cron prompt UPDATE | sqlite3 UPDATE statement with old→new substitution |
| Reusable classification logic | `src/capabilities/<name>.py` | Function signature + 1-paragraph spec |
| Hard rule about scope/output | HEARTBEAT.md / CLAUDE.md | Specific line + context |
| Trust-but-verify guard | append to `feedback_trust_but_verify_inherited_claims.md` | New numbered guard with source incident |

Include in daily digest under `🔧 IMPLEMENTATION DELTAS` section. **A learning without a corresponding implementation-delta proposal is incomplete output.** Source: 2026-05-01 operator request after a day of triage where memory entries were saved but SKILL.md / cron prompts weren't always updated.

6. For each operational learning targeting cron X (X ∈ {ot-post-monitor, ot-alert-monitor}):
   a. Backup current prompt:
      sqlite3 myclaw.db "SELECT prompt FROM jobs WHERE id='<X>';" > /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/cron-prompt-backups/<X>__$(date -u +%Y%m%dT%H%M%SZ).txt
   b. Modify prompt: append/update "## Learned Rules (auto-appended)" section at END. Insert each new rule as numbered item with date. Never touch human-authored body above this section.
   c. UPDATE jobs SET prompt=... WHERE id='<X>'; (sqlite3 with proper quoting — single quotes doubled).
   d. Verify: re-SELECT prompt and confirm section is present.

7. Append to learnings.md a section with today's ISO date. Format per learning:
   ## YYYY-MM-DD HH:MM PT
   - **Type:** operational | domain
   - **Trigger:** <brief observation from raw_response>
   - **Learning:** <the rule or pattern>
   - **Action:** appended to ledger / appended + amended cron <X> prompt
   - **Rollback (if operational):** `sqlite3 myclaw.db "UPDATE jobs SET prompt=$(cat backups/<X>__<ts>.txt | sql-escape) WHERE id='<X>';"`

8. If NEW learnings count > 0, send single GChat message to spaces/AAQAVOjYc80 via gchat skill. Format:
   "📚 [Daily learnings — N new]
    1. (operational, ot-post-monitor) <one-line learning>
    2. (domain) <one-line learning>
    ...
    Full ledger: ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md"
   Then respond HEARTBEAT_OK to suppress double-delivery.

9. If zero new learnings: respond HEARTBEAT_OK only. Do not send anything to GChat.

10. **Validator-Discrepancy Harvest (mandatory per 2026-05-08 operator rule)** — validator outputs are the highest-signal source for closing the auto-loop without operator nudging. For every raw_response that contains `⚠ Validator found` (case-insensitive), do:
    a. Extract the discrepancy block (typically 1-5 numbered points after the "⚠ Validator found" marker).
    b. Classify each discrepancy into one of these classes — each maps to a known Quality Rule the bot SHOULD have followed:
       - `model_id_mismatch` — bot connected two model_ids without verifying linkage → R12. Add to `triage-discipline.md` examples or amend an existing pattern row to require the linkage check.
       - `wrong_causality` — bot inferred X causes Y from temporal adjacency → R5b/R12. Re-rank cross-refs in any cron prompt that elevated novel hypothesis above verbatim-symptom cross-ref.
       - `inferred_stalled_from_duration` — bot called a job stalled based on elapsed time only → R13. Surface as a known-pitfall row in `known-patterns.md` Ruled-Out List if not already present.
       - `wrong_model_layer` — bot named served-model fix when root-training was the layer (or vice versa) → R11.
       - `unverified_url` — bot cited a fabricated UI URL → CLAUDE.md memory rule + cron prompt edit to drop the URL.
       - `other` — flag for human review; do NOT auto-amend.
    c. For classes 1-5: produce an implementation-delta proposal per step 5c (specific file + line + diff text). Distinct flag in digest: `🔁 VALIDATOR-LESSON` (separate from regular `🔧 IMPLEMENTATION DELTAS` so operator can see auto-loop output at a glance).
    d. Track in ledger under `## Validator Discrepancies` subsection per date — keeps the auto-loop measurable. Counter: `validator_discrepancy_count_today`. If >3 in one day, surface as a separate alert "VALIDATOR DRIFT — investigate cron-prompt regression".
    e. Cap at 5 validator-discrepancy proposals per run; oldest unactioned ones move to a backlog file `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/validator-discrepancy-backlog.md` for operator weekly review.

Safety:
- NEVER modify human-authored body of cron prompt — only "## Learned Rules (auto-appended)" section.
- ALWAYS backup before UPDATE. If backup write fails, abort UPDATE.
- Cap NEW learnings per run at 5.
- If sqlite query fails, respond brief error string (no HEARTBEAT_OK), do not modify anything.
- If unsure whether candidate learning is genuinely new → skip it. Bias toward fewer, higher-quality entries.
