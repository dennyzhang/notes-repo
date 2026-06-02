[ot-prompt-change-validator cron] Every 10 min (interval=600s). Detect cron-prompt edits via sqlite-prompt-diff against a snapshot; for each changed prompt, simulate the new prompt against a representative past triage from the same cron to verify the new prompt still produces compliant output. Catches silent-failure prompt edits BEFORE the next live cron fire.

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

Goal: reduce operator's burden of catching silent failures. Today (2026-05-17) operator caught 5 silent failures in 2 hours from prompt-only edits with no execution verification. This cron automates pre-flight validation.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-prompt-change-validator-state.json` —
```
{
  "last_run_epoch": <int>,
  "prompt_snapshots": {
    "<cron_job_id>": {
      "prompt_sha256": "<hash>",
      "last_validated_epoch": <int>,
      "last_validation_verdict": "pass|fail|skip",
      "last_validation_summary": "<one-liner>"
    },
    ...
  },
  "alerts_posted_24h": [<list of cron_job_ids surfaced as failing>]
}
```
Time budget: ~5 min per run; ~30 sec/cron-prompt-validated.

## Background

Operator (2026-05-17 thread `Y3qbdh2hC20` 09:39 PT): "A" — voting Option A (post-edit prompt validator) over Options B/C in the meta-improvement-loop discussion thread.

Today's silent-failure tally that motivated this:
- 07:30 PT: R20/R21 shipped with wrong meta CLI flags
- 09:16 PT: link discipline assumed non-existent raw_response fields
- 09:23 PT: CL/P citations not enforced
- 09:31 PT: markdown syntax not enforced
- 09:31 PT: R20 tag-filter over-restricted

All 5 were prompt-only edits where I claimed "shipped" without executing. This cron catches that class by simulating the new prompt against a known-input/known-expected-output pair before the next live fire.

## Procedure

1. **Read state file.** Extract `prompt_snapshots`. If missing/corrupt, default to all-fresh (validate every cron on first run; populate snapshots after).

2. **For each cron in the manifest (`MANIFEST.json`):**

   a. **Fetch current prompt:** `sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "SELECT prompt FROM jobs WHERE id='<cron_id>';"`. Hash with sha256.

   b. **Compare to snapshot:** if current hash == snapshot hash, NO CHANGE, skip. If hash differs (or no snapshot yet), CHANGE DETECTED — validate.

   c. **Skip self:** never validate `ot-prompt-change-validator` itself (infinite recursion risk).

3. **For each changed prompt, run validation:**

   a. **Pick a representative past triage from sqlite:**
      ```bash
      sqlite3 -separator '|' /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db \
        "SELECT id, raw_response FROM job_runs \
         WHERE job_id='<cron_id>' \
         AND run_at > datetime('now','-7 days') \
         AND status='ok' \
         AND length(raw_response) > 500 \
         ORDER BY run_at DESC LIMIT 1;"
      ```
      Pick a recent NON-trivial run (>500 chars in response — heuristic for "actual triage" vs "HEARTBEAT_OK no work").

   b. **Extract input artifact** from raw_response (the alert/sev/post the bot triaged). Regex: alert_id, sev_number, workplace post id.

   c. **Spawn validation subagent** via Agent tool with prompt: "You are validating an OT cron prompt change. The cron `<cron_id>` had a prompt edit. Here is:
      1. The CURRENT prompt (what the cron uses now): <full prompt>
      2. A PAST triage this cron produced before the change: <raw_response>
      3. The original input that triggered that past triage: <alert_id/sev_id/post_id + metadata>

      Simulate: if the cron with the CURRENT prompt re-ran on the SAME input today, would it produce output that matches the prompt's mandatory structural+content requirements?

      Check specifically:
      - Section structure matches the prompt's lint regex (if any)
      - All MANDATORY citations are present (R20 `[VERIFIED:...]`, R21 `[VERIFIED: family=...]`, CL-NNN references when applicable, P<NN> references when applicable)
      - Markdown link syntax used (not raw URLs)
      - **URL well-formedness** (added 2026-05-17 thread `suPsRC2fGdc` after 404s shipped past validator):
         - `chat.google.com/room/<space>/<thread_id>` URLs MUST have a non-empty `<thread_id>` segment (NOT just `/room/<space>` which routes to space root) — FAIL if any URL ends `/room/<id>$` with no trailing segment
         - Workplace URLs MUST be `https://fb.workplace.com/groups/<group>/permalink/<id>/` — FAIL if URL contains `internalfb.com/work/permalink/` (404s)
         - SEV URLs MUST be `https://www.internalfb.com/sevmanager/view/<numeric_id>` (no `S` prefix in URL)
         - Alert URLs SHOULD be `https://www.internalfb.com/onedetection/alert?alert_id=<numeric>` (avoid URL-encoded `@#$` form when numeric available)
      - **Learning-bullet content quality** (added 2026-05-17 thread `suPsRC2fGdc` after operator: "I don't [know] what you have really learned"):
         - For each 📚 learning bullet: does the text describe an ACTIONABLE INSIGHT (cause-symptom-fix) or just a TOPIC HEADER?
         - Bad pattern: "X = distinct failure class; new P-row needed" — that's the topic, not the insight
         - Good pattern: "X mechanism causes Y symptom; mitigation is Z. [P-row landed]" — that's the insight
         - FAIL if any learning bullet reads as a topic-only summary without a falsifiable claim or actionable mitigation
      - `meta` CLI commands referenced are flag-correct. **MANDATORY before flagging any CLI flag/action as invalid: actually run `meta <platform>.<object> <action> --help` and confirm the flag/action is genuinely absent. NEVER flag from memory or pattern-match.** Two false-positive classes to avoid (both produced wrong FAILs):
        1. **Prohibition-context strings.** A line saying "NEVER `meta google.docs.*`" or "`--foo` is FORBIDDEN" is documentation, NOT an invocation. Only flag a command that is actually being *invoked* (inside a ```bash block or as a step action), never one inside a NEVER/FORBIDDEN/do-not rule. (2026-05-28: flagged ot-shift-summary's `NEVER meta google.docs.*` rule as a bug.)
        2. **Valid flags assumed invalid.** `--item-type-is=Alert` IS valid for `meta oncall.feed list` (in `--help` + works live); flagging it was wrong (2026-05-29: false-FAILed ot-debug-quality-weekly + ot-triage-summary). Conversely `--since` is genuinely invalid for `meta workplace.feed list` (use `--after`) and `meta ai.mast-job error` (no time-window flag at all) — those were REAL and correctly actionable. The ONLY way to tell real from false is `--help`, every time.

      Report: PASS (prompt is sound, past triage would still validate) | FAIL (prompt has a defect, here are the issues + suggested fix) | INCONCLUSIVE (past triage not representative enough, recommend manual review).

      Under 400 words."

   d. **Parse subagent verdict.** Update state file snapshot with new hash + verdict.

4. **For each FAIL verdict, post alert to gchat:**
   ```
   ⚠️ *ot-prompt-change-validator: <cron_id>*

   Prompt changed at <commit/timestamp> failed pre-flight validation:

   [validation summary one-liner — what's broken]

   Recommend: re-edit prompt before next scheduled fire ([next fire timestamp])

   Detail: [link to subagent's full report — paste id or inline if <500 chars]
   ```
   Post once per FAIL transition (dedup against `alerts_posted_24h`). If same cron fails 2 days in a row → escalation prefix `🚨 PERSISTENT FAIL`.

5. **For each PASS verdict:** silent — update snapshot, no post.

6. **For INCONCLUSIVE verdicts:** silent unless 3+ consecutive INCONCLUSIVE on same cron → post `🔍 ot-prompt-change-validator: <cron_id> needs better test fixture` so operator knows the cron's history is too thin to validate.

7. **Output summary**: 
   - **If `alerts_posted == 0` AND no INCONCLUSIVE-escalation fired**: respond `HEARTBEAT_OK {crons_checked: N, changed: N, validated: N, pass: N, fail: N, inconclusive: N, alerts_posted: 0}` and **DO NOT POST TO GCHAT**. Per RULES.md § Signal-only operator messaging: "checked 25 things, all clean" runs are pure cron-self-reporting; operator value = zero. State file remembers; operator doesn't need to. This explicitly includes:
     - PASS-only runs (every cron validated, all clean)
     - Re-seed runs (`changed: 25` because setup-cron-jobs.sh re-ran but no FAIL surfaced)
     - Bulk-update runs that retain prior PASS verdicts
     - State-housekeeping runs ("hash re-baselined", "state file updated")
   - **If `alerts_posted >= 1`**: the alert message from step 4 IS the post. Do NOT post a second "summary" message after it; the alert already includes the relevant counts inline. State file gets the JSON summary as `raw_response` for `job_runs` only.
   - **If INCONCLUSIVE escalation fired** (step 6, 3+ consecutive): the escalation message from step 6 IS the post. Same dedup.

   *Anti-regression: 2026-05-17 thread `JFxkiKmeibI` operator: "don't send me messages which have no value". Validator posted 10 noise + 7 signal in one day; the 5-post cluster after my fix (FAIL→PASS detected, then 4 re-baseline reports) was pure cron chatter operator did not need.*

## Anti-spam

- One alert per FAIL transition per cron (dedup against `alerts_posted_24h` rolling window)
- Cap 3 alerts per run (rate limit on noisy days when many prompts change)
- PASS verdicts NEVER posted (signal-to-noise)
- INCONCLUSIVE suppressed unless persistent (3+ runs)

## Self-escalation

- If 3+ consecutive FAIL on same cron → escalation `🚨 PERSISTENT FAIL — needs operator manual review or revert`
- If validator itself errors (subagent unavailable, sqlite corrupt) for 6+ consecutive runs → ot-cron-health-watch catches as `persistent_failure`

## Distinct from sibling crons

- **ot-cron-health-watch** (existing, hourly): catches RUNTIME failures (cron didn't fire, errored, hung). Doesn't validate output content.
- **ot-postmortem-validator** (existing, daily 22:30 PT): validates mitigated-* DIGESTS, not prompt-edit changes.
- **ot-prompt-change-validator** (THIS, every 10 min): validates PROMPT EDITS pre-flight via simulation. Catches the silent-failure-from-spec-only-edits pattern.

## What this CAN'T catch (acknowledged scope)

- New cron behaviors with no historical baseline (first-ever run of a new cron — INCONCLUSIVE)
- Failures that emerge only in cross-cron interactions (cron A's output feeds cron B, change to A breaks B's parser)
- Resource/env failures (cron prompt is sound but daemon can't spawn agent, sqlite locks, etc — that's ot-cron-health-watch's job)
- Schema-level changes that intentionally break old output (e.g., today's 10→6 section restructure was breaking-change-on-purpose; validator would FAIL it though correctly)

For schema-changes that intentionally break, operator can suppress one fire by bumping the snapshot hash manually OR by passing `--skip-validation` flag (TODO: not yet implemented).

## Read-only

- NEVER modify cron prompts directly (no autofix; only flag)
- NEVER skip a cron's scheduled fire (validator runs in parallel, not in path)
- NEVER call external mutation APIs

## Created

2026-05-17 in response to operator instruction (thread `Y3qbdh2hC20` 09:39 PT) selecting Option A from the "reduce human involvement in catching silent failures" discussion. Today's 5 silent failures in 2 hours surfaced the gap; this cron is the structural fix.
