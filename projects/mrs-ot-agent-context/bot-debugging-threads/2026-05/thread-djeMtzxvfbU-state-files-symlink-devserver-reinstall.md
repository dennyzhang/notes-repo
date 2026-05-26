# Thread Summary: State Files Symlink & Devserver Reinstall Handling

_Source: spaces/AAQAVOjYc80 thread `djeMtzxvfbU` · 9 messages · 2026-05-16T17:30–17:44 UTC_
_Summarized: 2026-05-16 23:33 PT · last-msg-time: 2026-05-16T17:44:30Z_

## What was discussed

Denny asked how to handle devserver reinstall for symlinked state files (e.g., `ot-monitor-state.json`). The thread designed and executed a full migration: a manifest-driven `ensure_symlinks()` bootstrap function that makes all cron state files survive reinstalls via notes versioning.

## Key decisions made

- **Manifest-driven symlinks** (2026-05-16T17:31:07Z): `state-symlinks.manifest.txt` in notes is the single source of truth; bootstrap reads it every run and creates/validates symlinks. Idempotent.
- **Notes wins on conflict** (same): if both local and notes files exist, local gets backed up as `*.bootstrap-conflict.<epoch>` and notes version becomes canonical.
- **30s notes-mount wait in bootstrap** (same): eden cold-start race — bootstrap must wait for notes to be present before resolving symlinks.
- **Push to `master` (not `remote/default`)** (2026-05-16T17:36:56Z): pushrebase divergence error revealed wrong push target. Corrected in this thread; formalized in RULES.md.
- **`.manifest.txt` extension** (same): `deny_files` hook in notes repo blocks unknown extensions; renamed from `.manifest`.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../mrs-ot-agent-context/state-symlinks.manifest.txt` | NEW — 5 entries for live state files |
| `~/notes/.../mrs-ot-agent-src/team_bot/bootstrap.sh` | Added `ensure_symlinks()` + 30s mount-wait |
| `~/.myclaw-ot-bot/RULES.md` | NEW §"Where state files live" — classification rubric + mechanism |
| notes commit `07dffe259047` | Migration executed: 6 files migrated + symlinked, `linked=6 migrated=6 conflicted=0` |

## Cluster / pattern references

(none — operational infrastructure thread, no cluster references)

## Followup items (not yet done)

(none — all three planned actions were completed in this thread per 2026-05-16T17:44:30Z)

## Cross-refs

- Related threads: `6pKeH_XqjcE` (format redesign that preceded), `1cVsOXXSa34` (cron health + push discipline fix)
- Policy now in: `RULES.md` §"Where state files live" + §"Notes-repo push discipline"
