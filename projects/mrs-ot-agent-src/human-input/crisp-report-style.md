# Crisp Report Style — Cross-Team / External-Facing OT Triage

When the bot posts to surfaces **outside this team space** (Workplace `mrs.ot` group, SEV GChat space root, cross-team channels), the report MUST follow the crisp 5-element template below. Verbose 9-section internal-debug output (per `output-schema.md`) goes to a paste; the post body links to it.

> **Back to:** [SKILL.md](../SKILL.md)

## When to use crisp style

| Surface | Style |
|---|---|
| `mrs.ot` Workplace group | crisp (this template) |
| SEV GChat space root | crisp |
| Cross-team channels (silvertorch, mvai, recsys, IG-feed-recs) | crisp |
| Threaded reply WITHIN this team space (`spaces/AAQAVOjYc80`) | verbose 9-section (`output-schema.md`) |
| Threaded reply WITHIN a SEV GChat (when bot is asked specifics) | verbose 9-section, capped 3000 chars |

Rule: **the audience for crisp is people who do NOT have the bot's full context** — they need to scan in 10 seconds and know whether they own this. Verbose is for already-engaged debuggers.

## Trigger phrases (natural language — DEFAULT BEHAVIOR, no keyword needed)

When the operator asks for any of the phrases below in interactive conversation, the bot uses crisp 5-element template by DEFAULT. No special `crisp-report` keyword needed.

| Operator says | Bot defaults to |
|---|---|
| `create an issue report` | crisp (5-element + paste) |
| `create a report` / `make a report` / `draft a report` | crisp |
| `report this <X>` / `report on <X>` | crisp |
| `post about this` / `draft a Workplace post` / `draft for mrs.ot` | crisp |
| `tell <team>` / `tell silvertorch` / `tell the model owner` | crisp |
| `summarize for <team>` / `summarize this for posting` | crisp |
| `write up <X>` / `write up the issue` | crisp |
| `share this with <X>` (where X is non-team) | crisp |
| `triage <X>` (operator-direct, in 1:1 or thread) | verbose unless audience is named cross-team |
| `what's wrong` / `debug this` / `investigate <X>` (operator-direct) | verbose 9-section |

**Rule**: any phrasing that implies the output will be SHARED with non-bot-context readers → crisp. Any phrasing that's the operator asking the bot to think/debug/investigate → verbose.

If ambiguous, ask one short clarification: "for posting cross-team (crisp) or for your own debug (verbose)?"

## The 5-element template

```
# [OT triage] <job-id> (<job-class>) — <symptom> at <when>

**Model**: <model_name> (id <model_id>) | arch: <silvertorch|in-trainer|fblearner-flow|other:freeform> | importance: <prod|holdout|qe|canary|dev|unknown> | owner: <unixname>

**PROBLEM**: <one sentence. Include 1-2 supporting numbers — last-good timestamp, gap duration, instance counts. Avoid jargon if cross-team.>

**LIKELY CAUSE**: <one sentence with file:line code-pointer (per Quality Rule R3). If unverified: prefix "[INFERRED]" and state the hypothesis without the code-pointer.>

Detail reporting: [P<paste_id>](https://www.internalfb.com/intern/paste/P<paste_id>)

**ASK**: <one sentence. Who needs to do what. Page-tag if specific (`Need <oncall> help to triage`).>
```

Total target: 6-8 lines, under 700 chars body.

### Model metadata field — controlled vocabulary

The **Model** line is mandatory at the top of every triage output (crisp AND verbose). Cross-team readers need to know the architecture and importance class before scanning the body — `prod` reads vs `qe` reads change the urgency calculus, and `silvertorch` vs `in-trainer` changes who owns it.

| Field | Allowed values | Source of truth |
|---|---|---|
| `arch` | `silvertorch` (STUS publish path), `in-trainer` (training-loop publish), `fblearner-flow`, `other:<freeform>` | `meta ai.mast-job metadata --name=<job> -o json` → `entrypoint` / `job_type` field. Map: `st_update_service` → silvertorch; explicit publish in trainer → in-trainer; flow-id present → fblearner-flow. |
| `importance` | `prod`, `holdout`, `qe`, `canary`, `dev`, `unknown` | Model registry tags / job naming convention. Map: model serving live traffic → prod; A/B treatment arm without traffic → holdout; QE-prefixed job → qe; canary-tagged → canary; ephemeral / sandbox → dev. When ambiguous → `unknown` (do NOT guess). |
| `owner` | unixname | `meta ai.mast-job metadata` → `oncall` or model-registry owner. |

If any field is genuinely unknowable from data within the triage budget, render the literal `unknown` — never fabricate. (Honest uncertainty beats confident hallucination — see CLAUDE.md "Self-Reporting From Data, Not Narrative".)

## Rendering rules

1. **Title is scannable**: lead with `[OT triage]`, then job id, then job class in parens, then dash, then symptom + when. Time format: `at HH:MM <TZ>` for incident time, NOT post time.
2. **PROBLEM** is the symptom in user-impact terms, not a metric definition. "FULL snapshots nearly absent — 1 in last 15h" beats "publishing-stability SLI breached".
3. **LIKELY CAUSE** must be one specific mechanism. If the bot has 3 hypotheses, pick the highest-ranked and state the others lived in the paste. If unranked / unsure → `[INFERRED]` prefix; no code-pointer.
4. **Detail reporting paste** is mandatory when external-facing — the verbose 9-section template goes there. Format: `Detail reporting: [P<id>](https://www.internalfb.com/intern/paste/P<id>)`. Create paste via `meta paste.paste create` BEFORE rendering the post.
5. **ASK** is one sentence, one ask. Multi-step asks go to the paste's "Recommended Actions" section. Format: `Need <person|oncall> help to <verb>` or `Awaiting <verb> by <owner>`.

## Anti-patterns

| Don't | Do |
|---|---|
| Three-paragraph PROBLEM with all the evidence inline | One sentence + 1-2 numbers; rest to paste |
| Confidence/lane scores in the header (`[Bot \| confidence: 0.65 \| lane: ...]`) | Drop the meta-tags from external-facing posts; they're internal debug noise |
| "Falsified hypotheses" / "Investigation commands" / "Files-touched" sections in the post body | All to the paste |
| Bullet list of next-actions | Single ASK; multi-step in paste |
| Multiple bold subheadings | Three bold labels max: PROBLEM / LIKELY CAUSE / ASK |
| Code-pointer that's just a file (no line) | `path:line` per Quality Rule R3, or omit entirely |
| Posting before the paste exists | Paste first, then post — link must resolve when readers click |

## Source

Authored 2026-05-08 from operator-cited example post: https://fb.workplace.com/groups/mrs.ot/posts/1320976936663716 ("[OT triage] mvai-training-online-2133142909 (SilverTorch) — full snapshot ~9 h stale, hourly cadence broke at 07:42 UTC").

Operator note: "I need the OT agent has the capability to report issues in a clear and crispy manner."

## Worked example

Bad (current bot output, 40+ lines):

```
[OT-Bot diagnosis | symptom-attribution: 90% | root-cause: 50%]
Cluster: 1 alert — m2133142909 (ig_textpost_feed_esr), FULL_SNAPSHOT missing ~9.6h. Trainer RUNNING, deltas healthy.
Ground-truth timeline [VERIFIED]:
- FULL_SNAPSHOT cadence ~1/hr: last at 07:42:05 PT (instance :52913) [VERIFIED]
- After 07:42: only ITEM_EMB_DELTA & SPARSE_DELTA, all VALID, ongoing [VERIFIED]
- 0 INVALID instances in 500-instance lookback [VERIFIED]
- MAST v18 att-0: RUNNING since 2026-05-07 04:09, empty error_message [VERIFIED]
- v17: killed by linrongc reason "STUCK" [VERIFIED]
... (35 more lines)
```

Good (crisp, 7 lines):

```
# [OT triage] mvai-training-online-2133142909 (SilverTorch) — full snapshot ~9 h stale, hourly cadence broke at 07:42 UTC

**Model**: ig_textpost_feed_esr (id 2133142909) | arch: silvertorch | importance: prod | owner: chengchengyuan

**PROBLEM**: Threads ESR SilverTorch OT job is generating sparse + item-emb deltas every 1-3 min but FULL snapshots are nearly absent — 1 success in last ~15 h.

**LIKELY CAUSE**: SilverTorch update-service runs the full publish path on every cycle but hits an internal skip — st_update_service.py:1227 [Rank 0] skipped full snapshot publish fires on nearly every attempt.

Detail reporting: [P2315669002](https://www.internalfb.com/intern/paste/P2315669002)

**ASK**: Need silvertorch oncall help to triage.
```

The crisp version surfaces the same root cause faster, gives a verifiable code-pointer, names a concrete next-action, and links to the deep dive for anyone who wants it.
