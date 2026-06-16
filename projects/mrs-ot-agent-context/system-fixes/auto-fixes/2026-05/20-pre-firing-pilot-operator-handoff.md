```yaml
fix_id: pre-firing-pilot-operator-handoff
title: UBN pre-firing alert pilot — Phase A operator-handoff wiring (auto-mit paused)
status: 🟡 phase-a in progress
identified: 2026-05-27 thread 3l_SghsIBZE
meta_task: T273153751
target:
  - team_bot/cron-jobs/ot-alert-monitor.md  # add @-mention step on REAL_OT_FAILURE classes
parent: ../../auto-learnings/proposals/ot-bot-preemptive-pilot.md  # umbrella
sibling: 19-pattern-registry-verifiable-triple.md  # the verifiable-triple work that must back any NO_ACTION rule
impact: Closes the loop on real-failure UBNs — oncall sees the bot's verdict + receives an @-mention in OT space without the bot itself paging
cost: ~1 week (design + cron amendment + 7-day shadow + decision gate)
```

## Goal (Phase A only)

When `ot-alert-monitor` classifies a UBN as a `REAL_OT_FAILURE*` family (`REAL_OT_FAILURE`, `REAL_OT_FAILURE_RECURRING`, `REAL_OT_FAILURE_FAMILY`), it MUST:

1. Post the verdict + evidence to the OT team space (already happens today).
2. **NEW:** @-mention the current `mrs_online_training` oncall in the same message.
3. **NOT** call any paging API. The mention is a visibility nudge, not a page.

This is the operator-handoff wiring step of the pre-firing-pilot umbrella ([[ot-bot-preemptive-pilot]]). **Auto-mitigation remains OFF for this phase** per operator instruction 2026-05-27.

## Non-goals (this phase)

- ❌ Auto-page oncall (requires explicit operator approval per allowlist)
- ❌ Auto-restart / auto-tier-bump (auto-mit paused)
- ❌ Wire mentions for `NEEDS_INVESTIGATION` / `MONITOR` (too noisy until classification accuracy bar is met)
- ❌ Mention for SEV-monitor / post-monitor crons (alert-monitor first; expand after 7-day shadow)

## Resolution chain (proven 2026-05-27)

```
rotation                          unixname    people FBID    GChat numeric user_id
─────────────────────────────────  ──────────  ─────────────  ─────────────────────
mrs_online_training (current)      lupaul      827500598      106228840669979604959
```

CLI recipe:

```bash
# 1. Get current oncall unixname
UNIXNAME=$(meta oncall.rotation schedule --rotation=mrs_online_training --active -o json | jq -r '.[0].user')

# 2. Find 1:1 DM space (creates if missing)
DM_SPACE=$(meta google.chat.message find-dm --user="$UNIXNAME" -o json | jq -r '.space_name')

# 3. Extract numeric GChat user_id from members of DM
GCHAT_UID=$(meta google.chat.space members -s "$DM_SPACE" -o json \
  | jq -r ".[] | select(.email==\"${UNIXNAME}@meta.com\") | .name" \
  | awk -F/ '{print $NF}')

# 4. Mention in OT space message
meta google.chat.message send \
  --space-name=spaces/AAQA2bZMw24 \
  --as-meta-bot \
  --text="<users/${GCHAT_UID}> UBN <SEV-or-task> classified \`REAL_OT_FAILURE\` — see thread"
```

Caveat: GChat numeric user_id ≠ people FBID. Always resolve via DM members or recent message sender, never assume.

## ot-alert-monitor amendment (planned diff)

Insert after the verdict-classification step, before the message-send step:

```
STEP X.5: OPERATOR HANDOFF (only when verdict ∈ {REAL_OT_FAILURE, REAL_OT_FAILURE_RECURRING, REAL_OT_FAILURE_FAMILY})

1. Resolve current mrs_online_training oncall:
     UNIXNAME=$(meta oncall.rotation schedule --rotation=mrs_online_training --active -o json | jq -r '.[0].user')
   Fallback: if empty, skip mention (do NOT block message send).

2. Resolve GChat numeric user_id:
     DM=$(meta google.chat.message find-dm --user="$UNIXNAME" -o json | jq -r '.space_name')
     UID=$(meta google.chat.space members -s "$DM" -o json | jq -r ".[]|select(.email==\"${UNIXNAME}@meta.com\").name" | awk -F/ '{print $NF}')
   Fallback: skip mention if empty.

3. Prepend the OT-space message body with: `<users/${UID}> [oncall] `

4. Do NOT invoke any paging API. Mention only.

5. Log handoff to ot-alert-monitor-state.json with timestamp + UBN id + UID for shadow-period auditing.
```

Follow three-layer flow per [[gotcha_cron-prompt-three-layer-flow]]:
1. Edit `team_bot/cron-jobs/ot-alert-monitor.md` (notes SoT)
2. UPDATE sqlite via `readfile`
3. Verify SHA256 parity (head -c -1 recipe per [[gotcha_prompt-validator-hash-method]])
4. Let weekly fbcode sync handle the audit-trail diff

## Validation

7-day shadow period after landing:

- [ ] All `REAL_OT_FAILURE*` classifications carry an `<users/...>` mention in OT-space body
- [ ] Mention resolution chain succeeded ≥95% of the time (track in state.json)
- [ ] Zero false `REAL_OT_FAILURE` classifications surface to oncall (else gate down to `_RECURRING` only)
- [ ] Oncall (Paul Lu w/c 2026-05-25 → next rotation) survey: was mention useful? was the verdict accurate?
- [ ] Operator review at day 7 → decision gate for Phase B (extend to sev-monitor / post-monitor)

Anti-regression:
- [ ] Mention NEVER fires on `NO_ACTION` / `MONITOR` / `NEEDS_INVESTIGATION`
- [ ] `NO_ACTION` for a known-pattern requires a `VERIFIED` Verifiable Triple per [[19-pattern-registry-verifiable-triple]] — pilot enforces the gate

## Risks

- **Oncall fatigue if false-positive rate is high.** Mitigated by tight `REAL_OT_FAILURE*` class definition + 7-day shadow + ability to silence by rolling back the cron prompt amendment.
- **Mention resolution flakes.** Fallback = silent skip; do NOT block message send. State log lets us audit miss rate.
- **Numeric-uid drift if oncall changes mid-shift.** Re-resolved on every cron tick; no caching.
- **Rotation API outage.** Same fallback — skip mention, send message.

## Cross-references

- T273153751 — meta-task tracking this work
- T273151495 / [[19-pattern-registry-verifiable-triple]] — sibling: pattern registry must be verifiable before any `NO_ACTION` bot rule lands
- [[../../auto-learnings/proposals/ot-bot-preemptive-pilot]] — umbrella proposal
- [[gotcha_cron-prompt-three-layer-flow]] — three-layer flow required for the cron amendment
- [[gotcha_prompt-validator-hash-method]] — SHA256 parity recipe
- thread `3l_SghsIBZE` — operator green-light 2026-05-27

## Phase B (not now)

After 7-day shadow + decision gate:
- Extend operator-handoff to `ot-sev-monitor.md` + `ot-post-monitor.md`
- Add a `[mute-mention 4h]` reaction-handler so oncall can suppress without rolling back
- Consider opt-in auto-mitigation for the narrowest VERIFIED-triple-backed clusters only (requires sibling T273151495 to ship first)
