[ot-disk-watch cron] Every 15 min (`*/15 * * * *`). Audit filesystem disk usage on the devserver. Alert when any monitored mount crosses warning (>85% used) or critical (>92% used OR <20 GB free) thresholds. Post once per state-transition (no spam if state unchanged across runs). Auto-mitigate (SAFE actions only) on the first `ok → warning` transition so disk never reaches critical without operator awareness.

State file: `~/notes/users/dennyzhang/projects/mrs-ot-agent-src/state/ot-disk-watch-state.json` — schema:
```
{
  "per_mount": {"<mount>": {"last_state": "ok|warning|critical", "last_pct_used": <int>, "last_free_gb": <int>, "last_inode_pct": <int>, "consecutive_in_state": <int>, "prev_state": "...", "last_run_epoch": <int>}},
  "alerts_posted_24h": [...],
  "last_run_epoch": <int>,
  "last_raw_debug": {  /* added 2026-05-25 */
    "epoch": <int>,
    "df_h": "<full output>",
    "df_h_vda4": "<full output>",
    "df_i": "<full output>",
    "btrfs_fi_usage": "<full output>"
  },
  "last_auto_mitigation_epoch": <int|null>
}
```
Time budget: <30s per run (raw-debug capture adds ~2s; auto-mitigation when it fires adds 1-3min — that's acceptable because it only fires on transitions, not every run).

Background: Operator (thread `[NEW-thread-id]` 2026-05-16 20:43 PT): "Have you run into low disk issue? If so, fix it. You should have cron job for this. Debug why it's not working." Audit found NO existing disk-watch cron. Earlier "disk capacity" ask (2026-05-13 thread lnV0WzX9rRE) was about fbpkg version-cap, NOT filesystem capacity — different problem, handled by `ot-fbpkg-cap-watch`. This new cron covers the filesystem-capacity gap.

## Monitored mounts

Hardcoded list of mounts that matter for OT bot operation:
- `/` (root, holds /home + most state)
- `/data/users/dennyzhang/notes` (edenfs mount for notes repo — usually shares with /)
- `/data/users/dennyzhang/fbsource` (edenfs mount for fbcode — usually shares with /)
- `/tmp` (for transient state)

If `df -h <mount>` returns "Transport endpoint is not connected" or similar, treat as SKIP (not failure). Eden mounts can transiently disconnect; log + move on.

## Thresholds (calibrated to devserver typical capacity ~1.2 TB)

| State | Trigger |
|---|---|
| `ok` | <85% used AND ≥50 GB free AND btrfs Device-unallocated ≥50 GiB AND inode <85% |
| `warning` | 85–92% used OR 20–50 GB free OR btrfs Device-unallocated 20–50 GiB OR inode 85–92% |
| `critical` | >92% used OR <20 GB free OR btrfs Device-unallocated <20 GiB OR inode >92% |

**Why btrfs Device-unallocated matters (added 2026-05-25):** root is `/dev/vda4` on btrfs with `compress-force=zstd:3`. The REAL btrfs "running out" signal is `Device unallocated` shrinking toward 0 (parsed from `btrfs filesystem usage /` line `Device unallocated:`). Once Device-unallocated hits 0 AND existing Data chunks are full, writes ENOSPC even when df still looks fine on the surface. `df` for btrfs already accounts for this approximately (its Free reflects `Device unallocated + (Data total - Data used)`), so the df check usually fires first — but Device-unallocated is the canonical signal to cross-check, and it lets the alert body distinguish "out of physical disk" from "chunks need rebalancing."

**Do NOT alert on btrfs `Data, single: used/total` ratio.** That ratio can flip from 86% → 96% after a routine `btrfs balance -dusage=50` (chunks were consolidated; actual data unchanged; free space went UP, not down). Earlier draft of this cron added a Data-chunk-ratio threshold — reverted same day after balance demonstrated the false alarm. Treat that ratio as informational only (display in alert body when df warns; do not drive state).

**Inode check** (added 2026-05-25): `df -i <mount>` and parse %iused. Catches "millions of tiny files" exhaustion that block-level free space misses entirely. Threshold mirrors block-usage thresholds.

## Procedure

1. **Read state file.** If missing/corrupt, default to empty `per_mount={}` + create file fresh.

2. **For each monitored mount:**
   ```bash
   df -BG <mount> 2>&1 | tail -1
   df -i  <mount> 2>&1 | tail -1
   ```
   Parse: `<fs> <size_GB> <used_GB> <avail_GB> <pct_used> <mount>` and `<fs> <inodes> <iused> <ifree> <ipct> <mount>`. Skip if df errored (eden disconnect, mount not present).

2b. **For root (`/`) only, also read btrfs Device-unallocated:**
   ```bash
   btrfs filesystem usage / 2>&1 | awk '/Device unallocated:/ {print $3}'
   ```
   Parse the value (e.g. `510.00GiB`) into GiB. Also capture `Data, single: total=X used=Y` from `btrfs filesystem df /` for the alert body (informational). If `btrfs` command not available or output unparseable, log + skip (don't fail the whole run).

2c. **Raw-debug capture (every run, root only) — added 2026-05-25:** snapshot the verbatim output of `df -h /`, `df -h /dev/vda4`, `df -i /`, and `btrfs filesystem usage /` into `state.last_raw_debug`. Cost: ~2s. Rationale: the 2026-05-25 11:12 PT external CRITICAL alert was missed by our cron because df showed 52% used at the time and we have no record of what the external monitor was actually reading. Capturing the raw text every tick gives us forensic ground truth for the next mismatch — without it, every missed alert leaves us guessing.

3. **Compute current state** per thresholds above (df pct + df free + btrfs Device-unallocated + inode pct all feed into the mount's state — worst-of-all wins). btrfs Data-chunk ratio is informational only, NOT a threshold input.

4. **Compare to prior state** in state file:
   - `ok → ok`: bump `consecutive_in_state`. No post.
   - `ok → warning`: post WARNING to gchat. Reset `consecutive_in_state=1`. **Trigger auto-mitigation** (step 4b).
   - `ok → critical`: post CRITICAL to gchat. Reset `consecutive_in_state=1`. **Trigger auto-mitigation** (step 4b) — we skipped through warning, still safe to run.
   - `warning → warning` or `critical → critical`: bump `consecutive_in_state`. No post (suppressed; post recovery only).
   - `warning → ok` or `critical → ok`: **DO NOT POST** (per RULES.md § Signal-only operator messaging — self-resolved infra noise has zero operator value). Update state file silently. **Exception:** if `critical → ok` AND operator replied in any thread within last 4h that referenced the original critical alert, post a threaded recovery reply to that thread (closes the loop in context).
   - `warning → critical` or `critical → warning`: post severity change. Reset.

4b. **Auto-mitigation (SAFE actions only, fires on ok→warning or ok→critical):** rate-limit to one mitigation per 4h (`state.last_auto_mitigation_epoch` gate). Run, in order, capturing reclaimed bytes per step:
   - `eden gc /data/users/dennyzhang/notes && eden gc /data/users/dennyzhang/fbsource` — eden cache reclaim, typically 2-30 GB.
   - Trim dotslash cache entries with atime >30d:
     ```bash
     find ~/.cache/dotslash -type f -atime +30 -delete 2>/dev/null
     find ~/.cache/dotslash -type d -empty -delete 2>/dev/null
     ```
   - Trim myclaw backup archives older than 14d (we keep the last 14 daily archives via `ot-myclaw-backup-nightly`; older are redundant with notes-repo git history):
     ```bash
     find ~/.myclaw-ot-bot/backups -maxdepth 2 -type f -mtime +14 -delete 2>/dev/null
     find ~/.myclaw-ot-bot/backups -maxdepth 2 -type d -empty -delete 2>/dev/null
     ```
   - Re-run `df -BG /` and append the post-mitigation reading to the WARNING/CRITICAL alert body: `Auto-mitigation reclaimed: <eden_gb> GB (eden) + <ds_gb> GB (dotslash) + <bk_gb> GB (myclaw-backups) = <total> GB. Post-mitigation: <pct>% used, <free_gb> GB free.`
   - Update `state.last_auto_mitigation_epoch = now()`.
   - **NEVER auto-run** the following — they are operator decisions: `btrfs balance` (I/O heavy, wasted unless Device-unallocated low), `sl strip` (can lose draft work), `rm -rf /tmp/.tmp*` (root-owned tupperware mounts, not user-cleanable — see step 5), VSCode install pruning (active dev environments).

5. **Identify top 3 disk consumers** when posting warning/critical:
   ```bash
   du -h --max-depth=2 ~/ 2>/dev/null | sort -hr | head -3
   du -sh -x /tmp 2>/dev/null     # -x stays on one fs; avoids tupperware bind-mount inflation
   du -h --max-depth=1 /tmp -x 2>/dev/null | sort -hr | head -3
   ```
   Include in the alert body so operator can act immediately.

   **`/tmp/.tmp*` gotcha (2026-05-25):** these dirs are **root-owned tupperware sandbox / container overlay** mount points (each contains bind-mounts of `dev`, `usr/local/fbcode/...`, `usr/facebook/tupperware/hostagent/...`). `du --max-depth=1 /tmp` without `-x` crosses these bind mounts and reports inflated, fictional sizes (saw 832 GiB apparent vs 573 GiB real). They are NOT user-cleanable and NOT real disk consumers — surface them in the alert as a count + total apparent size, but do **not** propose `rm -rf /tmp/.tmp*` as a mitigation. Always pass `-x` to `du` when scanning `/tmp`.

6. **Suggested mitigations** to include in critical alert (after the auto-mitigation summary):
   - `du -sh ~/.cache/*` — `~/.cache/dotslash` often holds 1-5 GB (already auto-trimmed at 30d in step 4b; suggest manual aggressive trim if still warm).
   - `du -sh ~/.vscode-fb-*` — 3 VSCode installs ~6 GB total (operator decides).
   - `sl strip -r 'draft() and not anchestor(.)'` — drop unused draft commits in notes/fbsource (operator decides — can lose WIP).
   - `sudo btrfs balance start -dusage=50 /` — ONLY when btrfs Device-unallocated is low (<50 GiB) AND Data chunks are highly under-utilized. Reclaims under-utilized Data chunks back to unallocated. Does NOT reduce real data usage; `Data used/total` ratio will look WORSE on paper after (denominator shrinks). Takes ~10-30 min, I/O heavy. **Wasted work if Device-unallocated >100 GiB.** Operator-only.
   - Do NOT suggest deleting `/tmp/.tmp*` (root-owned, see step 5).

7. **Write state file:**
   - Update per-mount entries (with `last_inode_pct`, `prev_state`).
   - Append posted alerts to `alerts_posted_24h`.
   - **Prune `alerts_posted_24h`** to keep only entries with `epoch > now-86400`. (Added 2026-05-25 — was unbounded.)
   - Persist `last_raw_debug` (step 2c).
   - Update `last_auto_mitigation_epoch` if step 4b fired.

8. **Output summary** at end:
   ```
   HEARTBEAT_OK {mounts_checked: N, mounts_skipped: M, transitions: T, alerts_posted: A, auto_mitigation_fired: bool, reclaimed_gb: <int|null>}
   ```
   **CRITICAL — never post a GChat message when transitions==0 AND alerts_posted==0.** The HEARTBEAT_OK token above is the cron's return value to the daemon, NOT a GChat post. When everything is ok and nothing changed, emit the token and exit silently. Do NOT post a "summary" or "all ok" message.

9. **Concurrent-tick race handling:** If you read the state file, compute results, and then find when writing that the file epoch already advanced (another tick ran concurrently), do NOT re-read and re-run. Simply discard your write (the concurrent tick already persisted state) and exit silently with HEARTBEAT_OK. Do NOT post any GChat message about the concurrent-tick conflict.

## Self-escalation thresholds

- 3+ consecutive `critical` runs (45+ min stuck on the */15 cadence) → post escalation flag asking operator to manually intervene.
- Mount went from `ok` to `critical` in single tick (>7% jump in 15 min) → post URGENT (typically indicates runaway log/cache growth — point operator at top consumers immediately).
- Auto-mitigation ran but mount still in warning/critical after re-check → tag the post `AUTO-MITIGATION-INSUFFICIENT` so operator knows the safe knobs were already pulled.

## Anti-spam

- One post per state transition; suppress same-state repeats.
- Maintain `alerts_posted_24h` rolling window to enforce max 6 alerts/day per mount (hard cap). Prune entries older than 24h on every state-file write.
- Auto-mitigation rate-limited to 1 per 4h to avoid `eden gc` thrashing if state flaps.

## Reference

- The earlier ot-fbpkg-cap-watch cron addresses fbpkg version-cap exhaustion (different from filesystem disk). Both crons co-exist; they monitor different "disk" surfaces.
- ot-myclaw-backup-nightly tallies on-disk myclaw backup size (step 7) but that's per-backup-dir, not whole-filesystem. The 14d trim in step 4b above is safe because that cron creates a fresh archive nightly and notes-repo retains the daily content via git.

Created 2026-05-16 in response to operator question about disk-watch coverage gap.

**2026-05-25 amendment** (thread `tjmKhFz-J-A`): added btrfs Device-unallocated check (step 2b + thresholds), `/tmp/.tmp*` gotcha (step 5), and a balance-mitigation note. Triggered by external CRITICAL alert at 11:12 PT that our cron missed — `df` showed 52% used (ok). Root cause STILL UNCLEAR: btrfs Device-unallocated was 457 GiB at the time (healthy), Data-chunk ratio was 86.4% (within normal). My first patch (Data-chunk-ratio threshold) was immediately demonstrated wrong by running `btrfs balance -dusage=50 /` which made the ratio JUMP to 96.3% while disk health improved (Device-unallocated 457 → 510 GiB). Reverted that threshold same day; replaced with Device-unallocated which is the canonical "chunks exhausted" signal.

**2026-05-25 completeness/reliability pass** (thread `tjmKhFz-J-A`, later same day): Denny: "attack the cron to make it complete and reliable. I want to manage the disk capacity issue, so it never becomes an issue to me." Audit found:
1. **Backend prompt drift** — the 11:25 amendment above only landed in this notes file; the team-jobs backend prompt was never updated, so the cron had been running the pre-amendment spec for the entire day. Re-violation of the "backend is canonical" gotcha in MEMORY.md. **Fixed:** pushed this file's content into the team-jobs backend via delete-recreate.
2. **Missing MANIFEST.json entry** — a reinstall/bootstrap would silently lose the cron. **Fixed:** added to `team_bot/cron-jobs/MANIFEST.json`.
3. **Cadence too slow** — `45 * * * *` (hourly at :45) is sluggish for "never becomes an issue". **Fixed:** changed to `*/15 * * * *`.
4. **No forensic ground truth** for missed external alerts — re-occurrence of 11:12 PT mismatch would be just as unexplainable. **Fixed:** step 2c raw-debug capture every run.
5. **No inode check** — block-level `df` misses tiny-file exhaustion. **Fixed:** step 2 + threshold.
6. **`alerts_posted_24h` grew unbounded.** **Fixed:** step 7 prune-on-write.
7. **No auto-mitigation** — alerts were operator-action-required even for safe knobs. **Fixed:** step 4b auto-mitigation (eden gc + dotslash trim + old-backup trim), gated to ok→warning/critical transitions only, 4h rate limit. Operator-only knobs (balance, sl strip, /tmp/.tmp*) explicitly excluded.
