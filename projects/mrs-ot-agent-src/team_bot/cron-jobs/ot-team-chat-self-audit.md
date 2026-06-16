[ot-team-chat-self-audit cron] Daily ~18:00 PT (01:00 UTC). The bot AUDITS ITS OWN team-space outbound and self-corrects — so the operator stops having to police it ("why would team chat care about this msg?"). This is the detection/learning half of the team-chat-noise fix; the prevention half (a hard delivery-layer gate) is T275142534 in myclaw-core. Born 2026-06-09 after the operator flagged the same leak ~4× in one session: "shouldn't you track your outbound msg and keep improving it by yourself?"

**⛔ DELIVERY = OPERATOR 1:1 (`spaces/AAQAVOjYc80`) ONLY.** A noise-audit that posts to the team space would itself be the noise. For any output, EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing self-audit thread, or `# new-topic`> --text="…"`, then respond EXACTLY `HEARTBEAT_OK` (suppress daemon team-delivery). VERIFY-BY-READBACK. NEVER send to `spaces/AAQA2bZMw24`.

State file: `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/state/team-chat-self-audit-state.json` — `{"history": [{"date":"YYYY-MM-DD","sent":N,"leaks":M,"leak_rate":F,"leak_kinds":{"plumbing":a,"q-and-a":b,"meta-ack":c,"status":d}}], "audited_msg_ids": [...]}`. Time budget ~5 min.

## What counts (the gate this audits against — same as CLAUDE.md Team-Chat Send Gate)

- **TEAM-WORTHY (legitimate):** a shared OT INCIDENT triage carrying the bot's verdict + is-handled + action (crisp 5-element), an escalation needing the team, or the ONE fleet-health digest. These the whole team must see/act on.
- **LEAK (should have been 1:1 or silent):** operator↔bot Q&A, build/debug/plumbing answers, design iteration, config-change confirmations, status/"done", and meta-acknowledgments (incl. replying to "why team chat care" IN team chat). If the whole team doesn't need to see or act on it, it's a leak.

## Steps

1. **List the bot's own team-space messages, last 24h.** The bot posts under the operator's identity (current send path), so its outbound = the operator's messages in the team space:
   ```bash
   CUT=$(date -u -d '24 hours ago' +%s)
   meta google.chat.message list --space-id=spaces/AAQA2bZMw24 --limit=80 -o json 2>/dev/null \
     | python3 -c "import sys,json,os
   d=json.load(sys.stdin); rows=d if isinstance(d,list) else d.get('messages',d.get('data',[]))
   cut=int(os.environ.get('CUT','0'))
   for m in rows:
       s=(m.get('sender') or {}); name=(s.get('display_name') or s.get('name') or '')
       # bot posts as the operator; keep operator-authored msgs in the 24h window
       ct=m.get('create_time_epoch') or 0
       if 'denny' in name.lower() or 'Zhang' in name:
           print(json.dumps({'id':m.get('name'),'ts':ct,'text':(m.get('text') or '')[:400]}))
   " CUT=$CUT
   ```
   (If the list call 403s, reuse the `gchat_read_with_recovery` OAuth self-heal wrapper pattern from ot-sev-monitor; on hard-fail, skip the run with a one-line 1:1 note, do NOT fabricate an audit.)
   Skip ids already in `audited_msg_ids`. If zero new bot messages, persist state, `HEARTBEAT_OK`.

2. **Classify each message** against the gate above: `team-worthy` or `leak:<kind>` where kind ∈ {plumbing, q-and-a, meta-ack, status}. Judgment, not a keyword grep (a content-grep is a proven false-positive trap — memory `content-scan-sendhook-false-positives`). Be strict: when unsure, it's a leak (the whole point is to catch the borderline ones the send-time judgment let through).

3. **Compute counts deterministically** from the labels: `sent`, `leaks`, `leak_rate = leaks/sent`, per-kind tally. Append the row to `history`; add the ids to `audited_msg_ids`.

4. **Deliver to the 1:1 ONLY if leaks>0** — a SHORT self-audit (size-budgeted, ≤12 lines):
   ```
   📋 *Team-chat self-audit* — <M>/<N> leaked today (<rate>%), trend <▲/▼ vs 7d avg>
   • <leak kind> — "<≤8-word gist>" → should've been 1:1
   …(≤3 worst; collapse rest to `+K more (<kind tallies>)`)
   *Pattern:* <the recurring leak type, if one dominates>
   ```
   If leaks==0: respond EXACTLY `HEARTBEAT_OK {self_audit: clean, sent:N}` and send nothing (a clean day is not worth a message — principle 0).

5. **Feed the improvement loop.** If the SAME leak-kind dominates ≥3 days in `history`, that's a recurring class the prose rule isn't catching → append a candidate to `learnings-ledger.md` for distillation (and it strengthens the case for the T275142534 hard gate). Cite the trend, not a single instance.

## Why this exists / invariants

- This is self-monitoring, not self-flagellation: the metric is the **leak rate trend** going DOWN over weeks. One leak is noise; the trend is the signal.
- **Read-only on the team space** (lists messages, never posts there). Only write is the 1:1 self-audit + the state file + the ledger candidate.
- Counts computed in code, never narrated (digest-numbers rule). The leak CLASSIFICATION is the one LLM judgment; everything downstream is deterministic.
- Pairs with T275142534 (the hard delivery gate). Until that lands, this audit + the trend is how the bot holds itself accountable instead of the operator doing it.
