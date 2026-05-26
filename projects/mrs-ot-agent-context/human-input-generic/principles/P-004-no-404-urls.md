# P-004: Every URL emitted MUST work; if form unverifiable, render plain text

**Statement:** No 404 links. Operator-hostile 404s are worse than no-link plain text. Memorize canonical URL forms; don't improvise.

**Discovered:** 2026-05-17 thread `-x-xLvG_vPo` ("one generic feedback: url you have attached should not run into 404 issues")

**Why it matters:**
- Operator clicks URLs to drill in; a 404 wastes the trip + erodes trust
- Validators that check `]()` syntax presence don't catch URL well-formedness
- Each silent-failure compounds: operator can't tell whether the bot is wrong or the URL just happens to break
- Across 8 cron prompts + RULES.md, a wrong URL form propagates fast

**Applies to:** generalizable-to-any-agent-system (any agent that emits links to operator-facing surfaces)

**Current applications:**
- `~/.myclaw-ot-bot/RULES.md` § "URL validity — NO 404 LINKS" (canonical forms for 8 URL types)
- 8 cron prompts that emit URLs: each has a "URL validity rule (cross-cron)" stanza referencing RULES.md
- `ot-prompt-change-validator` subagent checks: URL well-formedness across 4 sub-checks (chat/workplace/sevmanager/onedetection)
- `ot-human-attention-brief` pre-publish lint section #4: per-domain well-formedness

**Anti-patterns it prevents:**
- 2026-05-17 09:39 PT brief: `https://chat.google.com/room/AAQAVOjYc80` (space root, no thread_id) → routes to space, not the thread. Operator can't find the relevant conversation.
- 2026-05-17 09:39 PT brief: `https://www.internalfb.com/work/permalink/1324729222955154/` → 404, wrong domain (correct: `fb.workplace.com/groups/<group>/permalink/<id>/`).
- 2026-05-17 09:57 PT validator PASSED both above because its checklist only checked `]()` syntax, not URL form.

**Canonical URL forms (memorize)**

| Type | Form |
|---|---|
| gchat thread | `https://chat.google.com/room/<space_id>/<thread_id>` — MUST have both segments |
| Workplace post | `https://fb.workplace.com/groups/<group>/permalink/<post_id>/` |
| SEV | `https://www.internalfb.com/sevmanager/view/<numeric_id>` (no `S` prefix) |
| OneDetection alert | `https://www.internalfb.com/onedetection/alert?alert_id=<numeric_id>` |
| fb:notes commit | `https://www.internalfb.com/code/notes/commit/<hash>` |
| fb:notes file | `https://www.internalfb.com/code/notes/<repo_path>` (no `fbsource/` prefix) |
| Phabricator diff | `https://www.internalfb.com/diff/D<id>` |
| Task | `https://www.internalfb.com/tasks/?t=<id>` |

**Self-check:** before emitting `[text](url)`, ask "would I be able to open this URL in a browser RIGHT NOW and reach the intended target?" If unsure → omit link, render plain text.

**Related principles:** P-005 (conciseness — bad URLs are also visual noise), P-009 (validator coverage — URL well-formedness was the missing check that surfaced this principle), P-011 (spec vs lint)
