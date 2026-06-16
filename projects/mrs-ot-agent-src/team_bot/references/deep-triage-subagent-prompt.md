# Subagent Deep-Triage Prompt Template

Paste verbatim into an Agent-tool dispatch for the **source-trace** half of
any triage whose symptom is config / code / checkpoint-rooted (or where the
reporter links a paste / config / diff / source file). Closes the gap from
2026-06-04 thread `EOXLCWrOWZM`: the `ot-post-monitor` cron triaged a Threads
ESR restart-loop off the post text + MAST metadata and paged, never reading
the linked runtime config nor tracing the config FQN into fbcode source — the
SAME prompt run interactively read the code and nailed the root cause + fix.

## When to use (dispatch a subagent instead of tracing inline)

ANY of:
- Symptom is config / code / checkpoint / arch-mismatch / publish-skip-list rooted.
- The reporter (post/SEV/alert) links a paste, config, diff, or source file.
- The root cause requires reading ≥1 fbcode source file or comparing sibling configs.

Why a subagent: the monitor crons run under a ~5min/post budget with heavy
procedural overhead (state, dedup, gchat-recovery, notification) that crowds
out multi-file source-tracing — so under pressure they pattern-match and page.
A focused subagent has the budget + attention to actually open the files. Same
rationale as the diff-subagent (`diff-subagent-prompt.md`): the discipline only
fires reliably when a dedicated subagent owns it.

## Verbatim subagent prompt

Copy below `--- BEGIN ---` to `--- END ---`; fill the `<...>` slots.

```
--- BEGIN ---
You are a focused OT deep-triage subagent. Your job: find the ROOT CAUSE in
the SOURCE CODE/CONFIG and produce the exact fix — not a pattern-match.

Incident: <SEV/alert/post id + url>
Model: <model_entity_id> (<model_type_name>), MAST job <job name>, owner <unixname>
Symptom (reporter's words): <verbatim symptom + any reporter-proposed cause>
Linked artifacts: <every paste P####, config path, diff D####, source file the reporter linked>

== Mandatory steps (ALL required; the answer is in the source — read it) ==
1. READ every linked artifact verbatim (runtime config paste, etc.). Quote the
   relevant lines. Do NOT trust the reporter's file pointer — they often cite
   the symptom-adjacent file, not the one the job actually uses.
2. TRACE to the source the job ACTUALLY uses: from the MAST launch command,
   resolve every `--*-config-fqn` (e.g. `--delta-publish-config-fqn`) and the
   model's trainer_config into the real fbcode file. Use code-search
   (search_files / Grep / Glob / `glass`) → open the file → read it at `path:line`.
3. COMPARE sibling configs/structs (the same struct for other roles/models in
   the same file or family). Drift — "every sibling has X but the one this job
   uses doesn't" — is a top OT root-cause class. State which siblings are correct.
4. PULL ground truth from the run: `meta ai.mast-job error --name=<job>
   --version=<prev failed> --no-truncate` (+ attempts/insights); if attempts
   rotated out of Logarithm, say so and mark the mechanism `[INFERRED]`.
5. STATE root cause with per-fact `[VERIFIED]`/`[INFERRED]` tags. The exact
   command/file:line that proves each fact must appear.
6. PRODUCE the fix: exact `path:line` + the diff hunk (before→after). Prefer the
   de-duplicating fix (define-once-import) when drift caused it. Do NOT write a
   vague "fix the config."

== Output (return this structure; do NOT submit any diff — propose only) ==
- ROOT CAUSE: 1-2 sentences, with the proving file:line.
- EVIDENCE: the artifact lines + the source lines you read (verbatim).
- SIBLING COMPARISON: which configs are correct vs the drifted one.
- FIX: path:line + diff hunk.
- CAVEATS: anything unverified (e.g. mechanism inferred because logs rotated).
- 🧠 Context: skills + files you loaded (SKILL.md / mvai-ot / known-patterns /
  the source files / cheatsheets) — ✓ loaded, ✗ not (with reason).
--- END ---
```

## After the subagent returns

- The dispatching triage folds the subagent's ROOT CAUSE + FIX + 🧠 Context into
  its diagnosis output (the subagent does the source-trace; the cron owns the
  notification + state + validator-spawn).
- If the fix is a real diff, route diff *creation* through `diff-subagent-prompt.md`
  (never auto-land; `--draft` for operator review).
- If the subagent could not reach the source (timeout / access), the triage must
  say so and render `🧠 Context: code ✗ (subagent could not trace)` — never silently
  fall back to a pattern-match-only verdict.

_If you change this file, tell Denny._
