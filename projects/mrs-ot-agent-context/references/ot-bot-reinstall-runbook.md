# OT Team Bot (ot-bot / MyClaw-OT) — Reinstall Runbook

Operational runbook to reinstall/reprovision the OT team bot and reapply the working config.
Paste the block below to an agent. Canonical copy also at `~/work/claude/context/ot-bot-reinstall-prompt.md`.
Last verified working: 2026-06-02.

---

Reinstall the OT team bot ("ot-bot", display name MyClaw-OT 🛟) and reapply the working configuration.

GROUND TRUTH (do not deviate):
- Host: **DevWork = devvm28012.ftw0.facebook.com** (the NEW server). NOT devvm8258.scu0 (decommissioned) and NOT devvm6205.
- Connect via SSH ControlMaster mux only (BPF Jailer blocks direct keys):
  `ssh -F /dev/null -o ControlPath=~/ssh-mux/%h devvm28012.ftw0.facebook.com`
- Instance home: `~/.myclaw-ot-bot` (alias `myclaw-ot-bot`). Run instance commands as:
  `MYCLAW_HOME=$HOME/.myclaw-ot-bot myclaw <cmd>`
- Reusable settings backup (lives on the primary, devvm20552): `~/tmp_backup/.myclaw-ot-team/`
- Spaces: **1:1 / control = spaces/AAQAVOjYc80**, **team / workstream = spaces/AAQA2bZMw24**
- Team trigger word: **!ot-bot**

STEPS:
1. Install: `sudo dnf install -y fb-myclaw` then verify `which myclaw`.
2. Create instance: `myclaw init ot-bot` (creates `~/.myclaw-ot-bot`, alias, systemd unit; the setup wizard may error on "create Google Chat space" — that's OK, we reuse the existing config instead of creating a new space).
3. Reuse settings — rsync the backup into the new instance (run FROM the primary, devvm20552):
   `rsync -az --exclude 'backups/' --exclude 'logs/' -e "ssh -F /dev/null -o ControlPath=$HOME/ssh-mux/%h" ~/tmp_backup/.myclaw-ot-team/ devvm28012.ftw0.facebook.com:.myclaw-ot-bot/`
4. Set the spaces:
   - `~/.myclaw-ot-bot/config.json` → `"space_id": "spaces/AAQAVOjYc80"` (1:1/control)
   - `~/.myclaw-ot-bot/team_bot_config.yaml` → `target_space_id: spaces/AAQA2bZMw24` (team)
5. **THE correction that makes `!ot-bot` respond in the team space** — add these two keys to `~/.myclaw-ot-bot/config.json`:
   - `"trigger_words": ["ot-bot"]`
   - `"cross_space_triggers": true`
6. If google-mux fails (`client.pem` missing / `CAT mint failed`): run `fixmyserver --yes` on DevWork.
   - NOTE: an empty `klist` (no Kerberos ticket) is NORMAL on devservers and is NOT the blocker — don't chase it.
7. Start: `MYCLAW_HOME=$HOME/.myclaw-ot-bot myclaw start`
8. Verify:
   - `meta google.chat.space describe --space=spaces/AAQAVOjYc80` returns the space (connectivity OK).
   - Daemon log shows: `Iris consumer: cross-space triggers enabled (... extra_words=['ot-bot'])`.
   - Post `!ot-bot ping` in the team space (AAQA2bZMw24) → expect a reply. (`?ot-bot` replies privately to the 1:1 instead.)

NOTES:
- Replies post as **Denny's name** until the WIB-bot live toggle + CAT/cert are resolved (`mode: live` in team_bot_config). Shadow/reply_on_mention until then.
- Do NOT set `instance_type: TEAM` unless the team-identity hard-gate (D102499943) is resolved — it can block responses. The `trigger_words` cross-space path above gives a response without that risk.
