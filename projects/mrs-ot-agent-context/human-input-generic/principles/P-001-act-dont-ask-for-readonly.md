# P-001: Act, don't ask, for read-only investigation work

**Statement:** When the bot says "investigation needed," treat that as the trigger to act, not as the reason to ask. Default to running the read; only ask before writing.

**Discovered:** 2026-05-17 thread `2KD3EVyCv08` ("Why you wait" — operator caught agent posing "want me to run the lineage query?" instead of running it)

**Why it matters:**
- Each "want me to..." round-trip costs 5-30 min of operator time
- Read-only meta/sqlite/grep queries are zero-risk and ≤30 sec
- The asymmetry: missed read is recoverable (do it next message); wrong write isn't
- Without this principle, the agent feels collaborative ("checking in!") but is actually adding latency

**Applies to:** generalizable-to-any-agent-system

**Current applications:**
- `~/.myclaw-ot-bot/RULES.md` § "Wait-reduction protocol (2026-05-17 thread `2KD3EVyCv08`)"
- `mrs-ot-agent-src/team_bot/cron-jobs/ot-alert-monitor.md` step i-d (R19 STUS-lineage-resolution — bot auto-runs the 5-command chain instead of flagging "investigation needed")

**Anti-patterns it prevents:**
- 2026-05-16 22:28 PT: bot triage on A1955974 said "Root trainer ID not found in STUS metadata — investigation needed." Agent then asked operator "Want me to run the lineage query?" instead of running the 5-command chain. Operator caught 8h later. (R19 cron rule now auto-runs at triage time.)
- 2026-05-17 08:00 PT: agent listed "standing offers" for CL-018, P-row backfill, alert-config audit — all read-only work. Operator flagged: "you didn't address your question." (Same root pattern.)

**Calibration**

Just-do-it when ALL of:
1. Query is read-only (meta describe/list/metadata, scuba query, gchat read, people.profile get, grep, sqlite SELECT)
2. Investigation surfaces info directly actionable for current thread
3. Bounded output (~1 screen, not bulk dump)
4. The bot or a flagged-state has triggered it ("investigation needed", "low confidence", "validator unavailable")

Ask first when ANY of:
- Mutation (any --add-tag, comment-create, post-create)
- External message (gchat outside current conversation, workplace, oncall)
- Bulk read with cost concern (>24h scuba on high-volume dataset)
- Operator just said "don't act" or "wait"

**Related principles:** P-002 (shipping requires execution — same root: passive spec/wait vs active probe)
