[ot-notes-weekly-review-paste cron] Weekly Monday 07:00 PDT (`0 14 * * 1` — cron evaluated in UTC; 14:00 UTC = 07:00 PDT). Generate a Phabricator paste that RENDERS AS A DIFF of the past 7 days of MEANINGFUL changes to the notes repo (`users/dennyzhang/`), and post ONE message with the URL so the operator can manually review the week's notes evolution if they want.
**Why:** operator request 2026-05-30 (thread `xc_VJG_out4`): "create a cron which will create a weekly paste for this... my intent to manually review the weekly notes repo changes, if I want." One low-noise weekly artifact (a clickable review link), not a push to read.

**Design note — reuse the validated recipe in `cheatsheets/notes-repo-operations.md` § "View accumulated changes for a folder over N days".** Three traps that recipe encodes (do NOT relearn them):
- `date()` revset ABORTS on the notes graph (100k+ commits) → use the `-d` date FILTER for the baseline.
- `sl diff -X <pat>` SILENTLY NO-OPS with a positional path → drop noise file-blocks post-hoc.
- `pastry`'s upload service is flaky (ERR_INVALID_CHAR on any input when down) → use `meta phabricator.paste create --stdin --language=diff`.

## Procedure

1. **Baseline** = newest commit before 7 days ago:
   ```bash
   cd ~/notes
   SINCE=$(date -u -d '7 days ago' +%Y-%m-%d)
   END=$(date -u +%Y-%m-%d)
   BASE=$(sl log -d "<$SINCE" -l 1 -T '{node}\n')
   ```
   If `BASE` is empty, abort gracefully (respond HEARTBEAT_OK; do not post).

2. **Generate the meaningful diff** (exclude machine churn so it's reviewable, not a multi-MB blob):
   ```bash
   sl diff -r "$BASE" -r . users/dennyzhang/ > /tmp/notes_week_full.diff 2>/dev/null
   python3 - <<'PY'
   import re, os
   noise = re.compile(r'(cron-prompt-backups|/state/|/incidents/|auto-learnings|mega-learnings|bot-debugging-threads|resolved-(sevs|alerts|posts))')
   out, keep, buf = [], True, []
   def flush():
       if keep: out.extend(buf)
   for line in open('/tmp/notes_week_full.diff'):
       if line.startswith('diff --git '):
           flush(); buf=[line]; keep = not noise.search(line)
       else:
           buf.append(line)
   flush()
   open('/tmp/notes_week_meaningful.diff','w').writelines(out)
   print("bytes", os.path.getsize('/tmp/notes_week_meaningful.diff'),
         "files", sum(1 for l in out if l.startswith('diff --git ')))
   PY
   ```
   - If the meaningful diff is **empty (0 files)** → respond HEARTBEAT_OK (no post; quiet week).
   - If it's **> ~5MB** (rare) → paste the `--stat` map instead of full content and note the truncation in the message.

3. **Create the paste** (renders as colored +/- diff via `--language=diff`):
   ```bash
   cat /tmp/notes_week_meaningful.diff | meta phabricator.paste create \
     --title="notes/ weekly review — ${SINCE} to ${END} (meaningful changes; backups/state/archives excluded)" \
     --stdin --language=diff -o json
   ```
   Capture `id` (P-number) + `url` from the JSON. If paste creation fails, retry once; if it still fails, post a one-line failure note (`⚠️ [notes weekly review] paste failed: <reason>`) and HEARTBEAT_OK — do NOT loop.

4. **Final response = the message** (the daemon auto-delivers the final response to spaces/AAQAVOjYc80 — do NOT make an explicit `meta google.chat.message send` call; that double-posts). Emit exactly ONE line as the final response:
   ```
   📋 [notes weekly review] <SINCE>→<END>: <N> files changed → <url> (rendered diff; machine-churn excluded — reply if you want a specific bucket, e.g. state/ or incidents/)
   ```

## Safety / scope
- READ-ONLY on the notes repo (sl log + sl diff only). Creates a paste; no repo writes, no pushes, no gdoc.
- Never use `pastry` (upload service unreliable). Always `meta phabricator.paste create --stdin`.
- One message per week max. Quiet weeks (no meaningful changes) → silent HEARTBEAT_OK.
- Excluded buckets (cron-prompt-backups / state / incidents / auto-learnings / mega-learnings / bot-debugging-threads / resolved-*) are machine-generated churn; surface them only on explicit request.
