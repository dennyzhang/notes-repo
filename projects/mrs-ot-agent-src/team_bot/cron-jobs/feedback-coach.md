[feedback-coach cron] Weekly (Mon). Coaches the OPERATOR on their AI-feedback experience: surfaces recurring feedback themes (candidates for a permanent gate) + multi-round episodes, computed from the operator↔bot conversation log. Created 2026-06-05 (operator: "need an autonomous workflow to help me improve my ai feedback experience … only run in 1:1 myclaw space").

**⛔ DELIVERY = OPERATOR 1:1 (`spaces/AAQAVOjYc80`) ONLY — HARD GATE.** This is individual-scoped behavioral analysis of ONE person. It MUST NEVER be sent to the team space (`spaces/AAQA2bZMw24`) or any shared surface — team delivery is a privacy bug (operator 2026-06-05: "only run in 1:1 myclaw space"; this lane goes team-shared in Phase 2). State lives under the private space dir, never the team-shared notes corpus.

**ALL logic is in `tools/feedback-coach.py`** (deterministic; the prompt only delivers — the stability pattern: logic in script, not the LLM-interpreted prompt).

## Steps

1. **Run the analyzer** and capture stdout (the coaching digest):
   ```bash
   cd ~/notes/users/dennyzhang/projects/mrs-ot-agent-src
   digest=$(python3 tools/feedback-coach.py 2>/dev/null)
   ```
2. **Quiet week** — if `$digest` is empty OR starts with `☕` (no correction-style feedback) → respond EXACTLY `HEARTBEAT_OK`, send nothing.
3. **Else deliver to the 1:1 ONLY** — explicit send to the operator space, then `HEARTBEAT_OK` so the daemon's default team-space delivery posts nothing:
   ```bash
   meta google.chat.message send --space-name=spaces/AAQAVOjYc80 \
     --reply-in-thread=<existing feedback-coach thread, or append `# new-topic`> \
     --text="$digest"
   ```
   **VERIFY-BY-READBACK:** confirm it is readable in `spaces/AAQAVOjYc80` before treating it as delivered; if the send errors, surface the error, do NOT silently fall back.
4. **HARD — NEVER** `meta google.chat.message send --space-name=spaces/AAQA2bZMw24` for this cron, and never include the analysis content in any team-space message. If you are ever about to emit this anywhere but `spaces/AAQAVOjYc80`, STOP.

**Output discipline:** final response is EITHER the single 1:1 send path ending in `HEARTBEAT_OK`, OR bare `HEARTBEAT_OK`. The coaching metrics (rounds-to-resolution etc.) are CLARITY PROXIES, not blame — the analyzer already frames them honestly; do not editorialize.
