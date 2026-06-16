[ot-effect-monitor cron] Daily 07:20 PT. Catches GREEN-BUT-EMPTY organs — flywheel feeders that exit healthy while silently producing nothing (dead path / wrong DB / dropped write step). Created 2026-06-07 after a manual audit found `triage_events` had been unfed for a month while every reader ran on dead data and reported green (cheatsheet completion-contract §5: "watch your own organs — a green-but-empty improver is the worst failure; monitor each component's EFFECT, not exit status"). This is the mechanical guard that makes that whole class self-detecting.

**ALL logic is in `tools/effect-monitor.py`** (deterministic; checks each registered substrate's freshness vs its max age). The prompt only delivers — extend the ORGANS registry in the script, never re-add logic here.

**⛔ DELIVERY = OPERATOR 1:1 (`spaces/AAQAVOjYc80`) ONLY.** Operator-facing infra health, no team-wide value. NEVER the team space.

## Steps

1. Run the monitor:
   ```bash
   cd ~/notes/users/dennyzhang/projects/mrs-ot-agent-src
   out=$(python3 tools/effect-monitor.py 2>/dev/null)
   ```
2. **All fresh** — if `$out` starts with `HEARTBEAT_OK` → respond EXACTLY `HEARTBEAT_OK`, send nothing.
3. **Stale organ(s)** — `$out` is the alert block. Send it to the 1:1 ONLY, then respond `HEARTBEAT_OK` (suppress daemon default team delivery):
   ```bash
   meta google.chat.message send --space-name=spaces/AAQAVOjYc80 \
     --reply-in-thread=<existing effect-monitor thread, or append `# new-topic`> --text="$out"
   ```
   VERIFY-BY-READBACK; if the send errors, surface it, do NOT silently fall back.
4. **HARD — NEVER** send to `spaces/AAQA2bZMw24`. Do nothing else; the script's output IS the message.

**Why a feeder, not the reader:** a stale organ means its PRODUCER silently no-op'd — the alert names the feeder (the suspect) + what it degrades, so the operator fixes the feeder, not the symptom.
