[ot-notes-deletion-watch cron] Hourly. Detect unexpected file deletions AND draft-only orphans in `~/notes/users/dennyzhang/projects/mrs-ot-agent-{src,context}/` between recent commits. Catches the file-tracking casualty pattern (7+ instances 2026-05-16) where `sl rebase` / `sl goto` operations silently drop files from working tree + subsequent commits, AND the "draft-only orphan" pattern (2026-05-25) where a sibling cron created a file in a local draft that never landed in master and then the draft was abandoned/stripped.

**Why this cron exists:** operator (thread `iqRw-QgzYjM` 2026-05-16): "should we add a cheatsheet for notes repo capability? today the notes repo push run into many issues." The cheatsheet (`~/notes/users/dennyzhang/cheatsheets/notes-repo-operations.md`) captures discipline; this cron catches violations.

Manual discipline (RULES.md push procedure) has proven insufficient — 7 casualties in one session despite the rules being written. This cron is the safety net that detects casualties within 1h instead of waiting for operator to notice files missing.

## State

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-notes-deletion-watch-state.json`. Schema (v2, 2026-05-25):
```
{
  "last_seen_files": {"<rel_path>": <first_seen_epoch>, ...},   // tracks files that have been in master
  "draft_only_files": {"<rel_path>": {"first_seen_epoch": <int>, "last_seen_commit": "<hash>"}, ...},  // tracks files that exist only in drafts (sibling-cron output dirs)
  "last_run_epoch": <int>,
  "last_baseline_hash": "<sl identify of master at run time>",   // for BASELINE RESET detection
  "alert_history": [{"path": "<p>", "deleted_at_run_epoch": <int>, "recovered_from_commit": "<hash|null>", "kind": "casualty|orphan", "auto_committed": <bool>}],
  "auto_recoveries_this_week": <int>,   // ISO-week-keyed counter for the 3/week cap
  "auto_recoveries_week_key": "<YYYY-Www>",
  "last_raw_debug": {
    "epoch": <int>,
    "current_files_count": <int>,
    "last_seen_count": <int>,
    "draft_only_count": <int>,
    "recovery_attempts": [{"path": "<p>", "from_commit": "<hash>", "result": "ok|fail", "auto_committed": <bool>}]
  }
}
```

Time budget: ~2 min per run.

## Procedure

1. **Load state.** If missing/corrupt, treat as empty — first run BOOTSTRAPS the baseline only, no alerts (don't false-positive on first observation).

2. **Capture current master baseline:**
   ```bash
   cd ~/notes && sl identify -r master --template '{node}'
   ```
   Compare to `state.last_baseline_hash`. If the baseline is a brand-new hash AND `state.last_seen_files` is materially smaller/larger than what's currently on master (>5% delta), flag as **BASELINE RESET** — emit a single informational post (NOT a casualty alert), then proceed. Prevents silent recompute after a `sl pull` that brought a much-older/newer snapshot.

3. **Enumerate current files on master in scope:**
   ```bash
   cd ~/notes && sl files -r master \
       users/dennyzhang/projects/mrs-ot-agent-src/ \
       users/dennyzhang/projects/mrs-ot-agent-context/ \
       users/dennyzhang/cheatsheets/notes-repo-operations.md \
       2>/dev/null | sort
   ```
   Collect into `current_files` set.

3b. **NEW (2026-05-25) — Enumerate draft-only files in sibling-cron output dirs.** These dirs are write-heavy from automated crons and the most-recent draft commit may not yet have been pushed:
   ```bash
   cd ~/notes && sl files -r 'draft() & ::.' \
       users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/ \
       users/dennyzhang/projects/mrs-ot-agent-context/mitigated-sevs/ \
       users/dennyzhang/projects/mrs-ot-agent-context/mitigated-alerts/ \
       users/dennyzhang/projects/mrs-ot-agent-context/mitigated-posts/ \
       2>/dev/null | sort
   ```
   For each path in draft-only AND absent from `current_files` (i.e., not in master): record in `state.draft_only_files` with the draft commit hash. If a path has been draft-only for >24h, it's an **ORPHAN** — surface in alert and auto-recover (step 5). This catches the 2026-05-25 mega/2026-W21.md class: file existed in a local draft `3219501264e6` for ~84h but never landed in master.

4. **Compare against `last_seen_files`:**
   - **NEW files**: present in current, absent from last_seen → add to last_seen with current epoch
   - **DELETED files**: present in last_seen, absent from current → these are CASUALTY CANDIDATES

5. **Filter intentional deletions.** A deleted file is INTENTIONAL if any of:
   - The commit that removed it has `[OT bot] Remove` or `[OT bot] Delete` or `[cleanup]` in its message
   - The file path is in a known archive-rotation pattern (e.g., `mitigated-*/<old-month>/` — should be archived not deleted; if deleted, flag)
   - The operator's RULES.md or this cron's safety_overrides explicitly allowlist the path

   Otherwise → CASUALTY: a file disappeared without an intentional deletion commit.

6. **For each casualty OR orphan:**

   a. **Find the most recent commit (draft or public) containing the file:**
      ```bash
      sl log -r 'all() & file("<path>")' --limit 5 -T '{node|short} {date|isodate} {desc|firstline}\n'
      ```
      If the revset times out (notes repo is big), fall back to `sl log -r 'draft()' --limit 50 -T '{node|short}\n' | xargs -I H sl files -r H | grep -F "<path>"` to find draft sources. Top result = best recovery source.

   b. **Recover the file:**
      ```bash
      sl cat -r <recovery_commit_hash> <path> > <path>
      sl add <path>
      ```

   c. **Auto-commit + push the recovery (NEW v2 behavior, 2026-05-25)** — but ONLY when ALL of the following hold:
      - `state.auto_recoveries_this_week < 3` (week is ISO-week per `auto_recoveries_week_key`)
      - Total recoveries in THIS run ≤ 3 (large simultaneous casualty count is suspicious — escalate, don't auto-act)
      - The recovery source commit is in `draft()` OR is in master ancestry (avoid recovering from a stripped-and-restored commit)
      - The recovery does not modify a file outside the watched scope
      ```bash
      sl commit -I "<path1>" -I "<path2>" ... -m "[OT bot] deletion-watch auto-recovery — N file(s) restored

Restored files:
- <path1> (from <hash1>, kind=<casualty|orphan>)
- <path2> (from <hash2>, kind=<casualty|orphan>)

Detected by ot-notes-deletion-watch <run_iso>. v2 auto-commit (per
'Future tightening' contract: ≤3 per week, ≤3 per run, source must
be draft or master-ancestor).

Source: ~/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/cron-jobs/ot-notes-deletion-watch.md"
      sl push --to master
      ```
      Bump `state.auto_recoveries_this_week`. Tag the alert post with `🤖 AUTO-COMMITTED + PUSHED`.

      **If any condition fails**, fall back to v1: stage only (`sl add` already done), require operator review.

7. **Alert.** Post format depends on what was found:

   **Casualties + orphans (typical):**
   ```
   🛟 [ot-notes-deletion-watch] <Nc> casualty + <No> orphan recovered

   Casualties (deleted from master):
   - `<path>` — last in master <hours>h ago — recovered from `<hash>` 🤖
   Orphans (draft-only >24h, never landed):
   - `<path>` — created by `<owner-cron>` <hours>h ago — recovered from draft `<hash>` 🤖

   🤖 = auto-committed + pushed (recoveries this week: <N>/3 cap).
   Without 🤖 = staged only, operator review required:
       cd ~/notes && sl commit ... ; sl push --to master

   Pattern: orphan-from-mega/ pattern first seen 2026-05-25. See cheatsheets/notes-repo-operations.md.
   ```

   **Baseline reset (informational, no auto-action):**
   ```
   🔄 [ot-notes-deletion-watch] BASELINE RESET — master moved from <old_hash> to <new_hash>.
   Delta: <+N -M> files. Recomputing baseline; no casualties scored this run.
   ```

8. **Update state:**
   - Add `alert_history` entry per casualty/orphan (with `kind` and `auto_committed`).
   - Remove recovered paths from `last_seen_files` (they're now NEW again from the next run's perspective).
   - Persist `draft_only_files` minus any paths that were auto-recovered into master.
   - Persist `last_raw_debug` (step 9 below).
   - Update `last_baseline_hash`.
   - If the ISO-week key changed, reset `auto_recoveries_this_week = 0`.

9. **Raw-debug snapshot (NEW 2026-05-25):** persist `state.last_raw_debug` every run regardless of casualty count. Carries `current_files_count`, `last_seen_count`, `draft_only_count`, and a list of recovery attempts with from-commit hashes. Forensic ground truth for the next time a recovery picks the wrong source.

10. **Respond HEARTBEAT_OK** with summary `{files_audited: N, casualties_detected: C, orphans_detected: O, recovered: R, auto_committed: A, recovery_failures: F, alert_posted: <true|false>, baseline_reset: <bool>}`.

    **NO GCHAT POST WHEN `casualties_detected == 0 AND orphans_detected == 0 AND baseline_reset == false`** (per RULES.md § Signal-only operator messaging, 2026-05-17 thread `JFxkiKmeibI`). The HEARTBEAT_OK JSON is the entire response. Do NOT append "state baseline reset", "N missing paths traced to restructure", "third consecutive REORGANIZATION event", or any commentary that renders as a gchat post.

    *Anti-regression: 2026-05-17 — cron posted 11 "audit-passed" messages in one day including a 113-path REORGANIZATION_NOT_CASUALTY explainer. Operator: "don't send me messages which have no value to me." If casualties+orphans+baseline_reset are all zero, operator does not need to be told the bot looked.*

## Safety

- **READ-MOSTLY on sl repo.** Allowed mutations: `sl add` (always), `sl commit -I <scoped paths>` (only under step 6c gating), `sl push --to master` (only after step-6c commit). NEVER `sl strip`, NEVER `sl goto --clean`, NEVER touch files outside the watched scope.
- **NEVER auto-recover > 3 files in one run.** Large simultaneous casualty count is suspicious (likely a `sl pull` stale-snapshot event) — emit `🚨 CRITICAL: <N> files missing simultaneously, manual investigation needed` and DO NOT auto-recover.
- **NEVER auto-recover > 3 times per ISO week.** Repeated need = a deeper bug in a sibling cron's commit flow; flag for operator instead of papering over.
- **NEVER auto-recover from a commit with `[strip]`, `[abandon]`, or `[discard]` in its message** — operator intent was to drop the change.
- **NEVER delete `last_seen_files` entries** for files that look INTENTIONALLY deleted (e.g., mrs-ot/ cleanup) — flag for confirmation, don't silently accept.
- **Bootstrap discipline:** first 2 runs (`last_run_epoch == null` or `last_seen_files == {}`) ALWAYS post "BOOTSTRAP — no casualties scored on first observation." Operator confirms baseline.

## Scope (what's watched)

Path globs:
- `users/dennyzhang/projects/mrs-ot-agent-src/**`
- `users/dennyzhang/projects/mrs-ot-agent-context/**`
- `users/dennyzhang/cheatsheets/notes-repo-operations.md` (this cheatsheet, important)

**Draft-only enumeration ADDITIONALLY watches** (write-heavy automated-cron output dirs):
- `users/dennyzhang/projects/mrs-ot-agent-context/auto-learnings/**`
- `users/dennyzhang/projects/mrs-ot-agent-context/mitigated-sevs/**`
- `users/dennyzhang/projects/mrs-ot-agent-context/mitigated-alerts/**`
- `users/dennyzhang/projects/mrs-ot-agent-context/mitigated-posts/**`

Path globs explicitly EXCLUDED:
- `**/state-symlinks.manifest.txt` — config, rarely changes, won't drop
- `**/.claude/**` — devserver-local artifacts, expected to come and go
- `**/*.rej` — patch reject artifacts, intentionally cleanup-able

## When to disable this cron

- If `casualties_detected > 0` for 3 consecutive runs without operator review, the discipline rules have broken down → file followup, consider disabling cron to reduce noise
- If `alert_history` shows the same path repeatedly recovered (>3x in a week), THAT path should be moved to a more-protected location (e.g., committed to a different repo, or made read-only)
- If `auto_recoveries_this_week` hit the 3/week cap, that's a strong signal a sibling cron's commit flow is broken — fix the SOURCE, don't lean on this safety net

## Future tightening

- ~~**v2:** auto-commit + push the recovered files (current v1 stages only).~~ DELIVERED 2026-05-25 — see step 6c.
- ~~**v2.1:** detect draft-only orphans, not just deletions.~~ DELIVERED 2026-05-25 — see step 3b.
- **v3:** integrate with `ot-cron-health-watch` to escalate when >1 casualty per week pattern emerges.
- **v4:** detect file CONTENT silent-revert (not just deletion). E.g., file is present but content was rolled back to an older version.
- **v5 (butterfly):** trigger an extra run 30s after `ot-notes-commit-push` completes — currently there's a window between curation writing → commit-push fails-silently → next deletion-watch hour. Tighter than `52 * * * *` for the typical race.

## Learned Rules (auto-appended)

(empty — fresh cron)
