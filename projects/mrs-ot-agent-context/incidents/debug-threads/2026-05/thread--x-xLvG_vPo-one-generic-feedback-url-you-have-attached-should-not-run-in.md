# Thread Summary: URL Validity — No 404 Links, Canonical URL Forms

_Source: spaces/AAQAVOjYc80 thread `-x-xLvG_vPo` · 8 messages · 2026-05-17_
_Summarized: 2026-05-17 22:33 PT · last-msg-time: 2026-05-17T17:14:24Z_

## What was discussed

Operator flagged that a URL in a bot-generated brief pointed to `internalfb.com/work/permalink/<id>/` which 404s. Bot responded by shipping a system-wide URL validity rule covering 8 canonical URL forms. A follow-up sub-thread clarified whether `fb.workplace.com/groups/.../posts/<id>` or `.../permalink/<id>/` is canonical (API returns `/permalink/`, so that form was kept). Operator confirmed the specific broken URL was from the 09:39 PT brief (pre-fix).

## Key decisions made

- [2026-05-17T17:04:29Z] URL canonical-forms rule added to RULES.md (8 forms defined), propagated to 7+ URL-emitting crons. Workplace URL stays `/permalink/<id>/` (API canonical form), NOT `/posts/<id>`.
- [2026-05-17T17:06:57Z] Self-check rule added: "if URL form unverifiable → omit link entirely" rather than emit a potentially broken URL.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../RULES.md` | New `## URL validity -- NO 404 LINKS` section with 8 canonical URL forms |
| 8 URL-emitting cron prompts | Reference RULES.md URL rule; committed at `dd6b41971ec8` |

## Cluster / pattern references

_(No CL-NNN clusters directly cited in this thread.)_

## Followup items (not yet done)

_(No explicit followup discussed.)_

## Cross-refs

- Related threads: `pFlYRGd0q2c`, `iqRw-QgzYjM` (threading-rule context)
