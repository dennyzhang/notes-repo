[ot-ingest-gdocs cron] Daily 07:00 PT. **The project-context sync.** Mirrors authoritative EXTERNAL sources into the `mrs-ot-agent-context/references/` tree so every OT-agent bootstrap picks up current context. TWO source types, ONE cron (id kept for history — "gdoc" is legacy; it now also syncs skills): **(A) GDocs** (OT meeting notes / cross-team follow-ups) → `references/gdocs/<slug>.md`, idempotent on `revisionId` (steps 1–6 below); **(B) fbsource OT skills** (e.g. `claude-templates/.../skills/ot-reliability-health-check`) → `references/skills/<slug>.md`, idempotent on source sha256 (Part 2 below). Read-only on both sources; never writes back. (Operator 2026-06-05 `X5aTOk8FuCs`: "why need a new cron" — the would-be `ot-skill-context-sync` was folded in here rather than proliferating a new cron. **Phabricator authored-diffs (formerly Part 3, folded in 2026-06-12) were split BACK OUT into the standalone `ot-ingest-diffs` cron 2026-06-13** at operator request — diff ingestion is a distinct source: live Phabricator query + oncall-roster resolution, not a doc/file mirror.)

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-ingest-gdocs-state.json` — `{"failures": {"<slug>": {"consecutive": <int>, "first_failed_iso": "<ISO>", "autofix_task": "T<id>|null"}, ...}, "last_run_epoch": <int>}` (ADDITIVE; default `{"failures":{}}` if absent — no migration). Per-doc drift idempotency is still keyed off the `revision_id` frontmatter field (now a revisionId OR `sha256:<body-hash>` — step 3b). Lockfile: `~/.myclaw-ot-bot/locks/ot-ingest-gdocs.lock` (LOCK_MAX_AGE=900s).

**FIX-DON'T-REPORT + ESCALATE-OBVIOUSLY (HARD, 2026-06-13 thread `A4VpmKFNOJ4`, operator: "fix problems instead of just reporting them" + "major issues should escalate to me in an obvious way").** A per-doc fetch error must NOT be a flat `errors: fetch_failed` line that reads identically on failure #1 and failure #7 (the prior defect: `mrs-ot-reliability-cross-team-followups` timed out ~4 of 6 runs for a week, buried in the routine summary, never escalated, never fixed until the operator noticed). This cron now tracks per-slug consecutive-failure counts and, on recurrence, ESCALATES obviously AND drives a fix — same recurrence→escalate→auto-fix pattern as `ot-alert-monitor` (steps 7.g / consecutive-403 gate). This is a class fix: any cron that can emit a recurring error owes recurrence-tracking + obvious-escalation + a driven fix, not a repeated report line.

Procedure:

1. **Lockfile gate.** If `~/.myclaw-ot-bot/locks/ot-ingest-gdocs.lock` exists AND mtime is within 900s of now → exit silently (concurrent run). Else write the lockfile with current epoch and proceed. Always remove on exit (trap).

2. **Load config.** Read `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/references/gdocs/sources.json`. For each entry in `docs[]`:
   - `doc_id` (required)
   - `slug` (required, kebab-case, matches filename)
   - `title` (informational; cron does not validate vs gdoc title)

   If config missing or malformed → emit `ERROR: sources.json missing/malformed: <reason>` to gchat (one-line) and exit.

3. **Per-doc sync.** For each entry, run the following sub-procedure:

   a. **Fetch metadata.** `gdocs get <doc_id> --raw-json --no-daemon 2>/dev/null > /tmp/ot-gdoc-meta-<slug>.json`. If non-zero exit OR file < 100 bytes → record `error: fetch_failed` in run summary, continue to next doc (do NOT abort entire run).
      - **`--no-daemon` is REQUIRED, not optional (2026-06-13, T<see-task>).** The shared `gdocs` daemon reproducibly HANGS (times out at the 120s default) on certain docs — confirmed for `mrs-ot-reliability-cross-team-followups` (599KB raw-json) and `mrs-ml-infra-sev-criteria` — while a sibling doc fetches in 4s. Isolation proved the daemon is the culprit: daemon-mode times out, `--no-daemon` returns the same doc in 4s (direct Drive/Docs API call). Symptom before fix: `fetch_failed (API timeout)` on these docs for ~4 of the prior 6 daily runs. `--untrusted-authors-mode` does NOT help (red herring — tested, still hangs). Upstream daemon bug is out-of-lane (google-mux); `--no-daemon` is the in-lane workaround.

   b. **Extract drift-key + `title`.** Parse the JSON; capture `title`. For the drift key: use `revisionId` if present; **if `revisionId` is absent, fall back to `sha256:<sha256 of a DETERMINISTIC markdown render>`** (the Docs API `documents.get` omits `revisionId` for some docs — confirmed `mrs-ml-infra-sev-criteria` 2026-06-13; keys were body/documentId/documentStyle/lists/namedStyles/suggestionsViewMode/title. `gdocs revisions` is ALSO empty for such docs, so content-hash is the only available key). **DETERMINISM IS REQUIRED — hash markdown fetched with `--image-text-backend none --no-comments` (NOT the default).** Rationale (red-team 2026-06-13): the default `--markdown` uses `--image-text-backend metagen` (an LLM describes each image) and includes comment threads — both vary run-to-run, so hashing the default render would produce a NEW hash every run → false drift → silent daily rewrite + spurious `synced` line forever (a SUCCESS-path noise leak the recurrence gate would NOT catch). For a revisionId-less doc, ALSO write this deterministic render as the body (step 3e) so the written content matches the hashed content. Only if revisionId is absent AND the deterministic markdown fetch fails → record `error: no_drift_key` and continue.

   c. **Read current frontmatter** (if `references/gdocs/<slug>.md` exists). Parse YAML frontmatter for `revision_id`. If file missing → treat current revision_id as empty (forces first write).

   d. **No-drift gate.** If stored `revision_id` == fresh drift-key (revisionId, or `sha256:<body-hash>` for revisionId-less docs) → skip write (silent, record `no_drift` in summary). Continue to next doc. (Frontmatter `revision_id` holds whichever key type was used.)

   e. **Fetch markdown body.** `gdocs get <doc_id> --markdown --no-daemon 2>/dev/null > /tmp/ot-gdoc-body-<slug>.md`. If non-zero exit OR file < 10 bytes → record `error: markdown_fetch_failed` and continue. (`--no-daemon` required — same daemon-hang reason as step 3a.)

      **⚠️ MULTI-TAB LIMITATION (2026-06-24).** Plain `--markdown` returns ONLY the doc's **first tab**, not all tabs. For multi-tab rolling docs (e.g. `feed-reliability-syncs`, where each tab is a sync date) this captures the **top tab**, which works ONLY while the author keeps newest-at-top — if a newer tab is added elsewhere, the sync **silently goes stale** (the worst failure for a monitoring feed). Single-tab/runbook docs (e.g. `runbook-online-training-jobs`) are unaffected. To capture full tab history or pin a tab: `gdocs get <doc_id> --expand-as-folder` (one HTML per tab) or a per-tab `--tab-id` loop over `gdocs docs tabs list`. Not yet wired (operator declined the loop 2026-06-24); tracked here so it's a known constraint, not a silent gap. If a rolling-doc slug looks stale, suspect this first.

   f. **Write new file.** Replace `~/notes/users/dennyzhang/projects/mrs-ot-agent-context/references/gdocs/<slug>.md` with:
      ```
      ---
      doc_id: <doc_id>
      doc_title: <title from API>
      doc_url: https://docs.google.com/document/d/<doc_id>/edit
      last_synced: <ISO 8601 UTC>
      revision_id: <revisionId>
      ---
      <!-- AUTO-GENERATED by ot-ingest-gdocs. DO NOT EDIT — manual edits get clobbered on next sync. -->

      <markdown body verbatim from gdocs>
      ```
      Record `synced: prev_rev → new_rev` in run summary.

3.9. **Recurrence tracking + chronic escalation + auto-fix (the fix-don't-report mechanism).** After all per-doc/skill results are computed, read the state file. For EACH source (gdoc slug, skill):
   - **On success this run** → reset `failures[<slug>]` to `{consecutive:0}` (or drop the key). If it had `autofix_task` and is now succeeding, note `recovered: <slug>` for the summary and (optionally) leave the task for the operator to close.
   - **On error this run** → `consecutive += 1`; set `first_failed_iso` if newly failing.
   - **CHRONIC gate — `consecutive >= 2`:** this is a MAJOR issue (an authoritative context source is dark → OT-agent bootstraps on stale context). Drive a fix AND escalate, but **DO NOT re-🚨 every run** (P-017: once it's tracked, the task is the tracker — re-narrating each recurrence is the anti-pattern this whole thread is about):
     - **(b) DRIVE A FIX (don't just report)** — if no OPEN `autofix_task` for this slug: file ONE deduped `[OT auto-fix]` task (`--owner=dennyzhang --add-tag=mvai-online-training`, title `[OT auto-fix] ot-ingest-gdocs <slug> fetch failing <N> runs: <error_kind>`, body = error_kind + last-N-run history + candidate fix-site, e.g. "gdocs daemon hang → add `--no-daemon`" / "no revisionId → deterministic sha256 drift-key"). Store the id in `failures[<slug>].autofix_task`. `ot-autofix-diff-drafter` picks it up for the confirming source-dive + `--draft`. Storm-cap ≤3 auto-fix tasks per run; excess defers (they recur).
     - **(a) ESCALATE OBVIOUSLY — but THROTTLED.** Emit the 🚨 leading line ONLY on: (i) the TRANSITION into chronic (`consecutive == 2`), OR (ii) no open `autofix_task` exists yet for this slug, OR (iii) a weekly re-alert beat (`consecutive % 7 == 0`, so a still-dark source re-pings ~once/week, not daily). Otherwise (chronic, task already open, not a weekly beat) → **do NOT 🚨**; just keep counting silently (the dark source still appears in the routine `errors:` line, and the open task carries it). When you DO emit, format the FIRST line of the step-4 message as:
       `🚨 [ot-ingest-gdocs] CONTEXT SOURCE DARK — <slug> failing <consecutive> consecutive runs since <first_failed_iso> (<error_kind>). OT bootstrap context is STALE. Fix: <one-line candidate or "needs investigation">. Task: T<id>.`
       (one such line per qualifying chronic source; operator 1:1 `spaces/AAQAVOjYc80`; exempt from no-op-silence. This throttle keeps "major + obvious" from decaying into daily noise.)
   - Write the state file back.

4. **Drift notification — the ONLY send in this cron; runs AFTER Part 2 and aggregates gdoc AND skill results from the shared buffer.** (Do NOT send anywhere else — Parts 1 and 2 only RECORD into the buffer; this is the single emit point. This is what prevents the double-post when, e.g., `skill-sources.json` is missing.) **If step 3.9 flagged any CHRONIC source, its 🚨 escalation line(s) go FIRST, above the routine summary block below.**
   - If ANY gdoc OR skill file synced, OR ANY error (gdoc or skill) occurred → post exactly ONE message to `spaces/AAQAVOjYc80` (operator 1:1):
     ```
     [ot-ingest-gdocs] synced <Kd>/<Nd> docs · <Ks>/<Ns> skills:
       gdocs:  - <slug>: <prev_rev_short> → <new_rev_short>
       skills: - <slug>: synced (sha <old16>→<new16>)
     errors: <list or 'none'>
     ```
     (omit any sub-line whose part had no drift; `*_rev_short` = last 8 chars of revisionId).
   - If NOTHING synced AND NO errors across BOTH parts: silent — respond EXACTLY `HEARTBEAT_OK`, send nothing.

5. **Persistence model.** Synced files live in `mrs-ot-agent-context/` (the runtime corpus tree alongside `mitigated-sevs/`, `auto-learnings/`, etc.) — NOT in `-src/` and NOT mirrored to fbcode. Upstream gdocs are the actual source of truth; notes is just a versioned checkpoint cache, captured by the nightly `ot-myclaw-backup-nightly` cron's notes push. No `jf submit` needed for routine syncs. Fresh agent bootstraps load context via the OT-agent skill loader (which reads `mrs-ot-agent-context/`), not via fbcode reinstall.

6. **Out of scope** (do not attempt; if a future requirement surfaces, file a follow-up task):
   - Structured extraction (S-numbers, owners, action-item tables) — raw markdown only in v1.
   - Comment-thread sync — separate problem, would need `gdocs comments list`.
   - Write-back to gdocs — read-only by design.
   - Tab-level granularity — currently dumps all tabs into one markdown blob (gdocs `--markdown` default).

Run-time budget: ~30s per doc (gdocs API roundtrip ~1s each, 2 calls per doc). For N docs, budget ≤ 2 + 30*N seconds. Cap N at 20 (alert + abort if config grows past that — likely indicates a misuse).

---

## Part 2 — fbsource OT skills (source type B)

Runs in the SAME cron invocation, after the gdoc loop, under the same lockfile. Read-only on fbsource.

A. **Load config.** Read `mrs-ot-agent-context/references/skills/skill-sources.json` → `skills[]`, each `{src, slug}` where `src` is a path under `~/fbsource/`. Missing/malformed → record `error: skill-sources.json missing/malformed: <reason>` in the SHARED run buffer and skip the per-skill loop (do NOT post it separately — step 4 is the only send). Missing config is a non-silent ERROR (it forces step 4 to post), NOT a soft skip.

B. **Per-skill sync:**
   a. `SRC=~/fbsource/<src>`. If missing locally → `cd ~/fbsource && sl sparse include <src>` then retry; still missing → record `error: src_missing`, continue.
   b. `SHA=$(sha256sum "$SRC" | cut -c1-16)`.
   c. Read stored `source_sha16:` from `references/skills/<slug>.md` frontmatter (empty if absent).
   d. **No-drift gate:** stored == fresh → record `no_drift`, continue.
   e. **Write mirror** `references/skills/<slug>.md`:
      ```
      ---
      source: <src>
      synced_by: ot-ingest-gdocs (Part 2)
      synced_at: <YYYY-MM-DD>
      source_sha16: <SHA>
      note: AUTO-SYNCED from fbsource — do NOT edit by hand; overwritten on next sync.
      ---

      <verbatim source content>
      ```
      Record `synced` for the drift notification.

C. **Drift notification:** fold skill results into the SAME step-4 message — append a `skills:` line (`synced <K2>/<N2>: <slugs>` or omit if none). If BOTH gdocs and skills are no-drift and no errors → silent `HEARTBEAT_OK`.

D. **Safety:** never `sl commit`/edit the source; only `sl sparse include` + `sha256sum`/read. `references/skills/` is notes-only (not mirrored to fbcode), same as `references/gdocs/`. Self-report `synced`/`no_drift`/`error` from the actual sha comparison, never narrated. Provenance: first synced skill `ot-reliability-health-check` (2026-06-05, thread `X5aTOk8FuCs`); add more via `skill-sources.json`.

---

**Phabricator authored-diffs:** formerly Part 3 of this cron (folded in 2026-06-12); split BACK OUT into the standalone **`ot-ingest-diffs`** cron 2026-06-13 at operator request. See `cron-jobs/ot-ingest-diffs.md`. That corpus (`references/diffs/<unixname>.md`) feeds the change-delta-first ("what changed?") triage step; it is no longer produced here.
