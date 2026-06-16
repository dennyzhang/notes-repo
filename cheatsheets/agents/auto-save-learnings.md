# Auto-Save Session Learnings — Cheatsheet

**Load when:** Session is ending or context is about to compress after non-trivial work.

## Format

Save in the **working directory where the session started** (the space / project root), under a `learnings/` subdirectory. One file per learning. Frontmatter:

```yaml
---
name: short-kebab-case-slug
description: one-line summary — be specific, this is used for relevance matching
metadata:
  type: project | feedback | user | reference
---
```

Body: rule/fact first, then `**Why:**` and `**How to apply:**` lines for feedback/project types.

Update `MEMORY.md` index with a one-line pointer (under 150 chars).

## When closing a topic

When the operator says **"close the topic"**, distill the session's learnings into the cheatsheet using the SAME dedup discipline as memory above — the cheatsheet is **not** an append-only log.

| Step | Rule | Why |
|---|---|---|
| **1. Default to LOG, not RULE** | New evidence → the domain learnings-log (e.g. `diff/diff-learnings-log.md`). Promote to a core-cheatsheet bullet only after **≥3 distinct dated occurrences**. | Mirrors the `ai-failure-modes.md` inclusion bar. One-offs are evidence, not rules. |
| **2. Dedup before adding a bullet** | Grep the core cheatsheet for a rule this is a variant of. If it exists, append the dated evidence row to the log *under that rule* — do NOT add a new bullet. | The forensic pipeline appends by default; without this gate the core file bloats (common.md hit 1057 lines / 68 Common-Mistakes rows before the 2026-06-14 split). |
| **3. Size guard on write** | If the append pushes the file past the **800-line cap**, extract an on-demand section to a sibling/reference file first, then write. | `lint-cheatsheets.sh` flags oversize; keep the hot-path file (loaded before the relevant task) lean. |

**Tag + provenance:** tag the entry per `config/CHANGE-TRACKING-CONVENTION.md` (`[A]`/`[O]`/`[H]`) and bump the file's `Last updated` footer.

**Finish — commit to the notes repo directly (do NOT wait for the 4-hourly auto-push):**
1. `bash ~/notes/users/dennyzhang/scripts/lint/lint-cheatsheets.sh --gate <touched-files>` — must pass.
2. `cd ~/notes && sl addremove <new-files>` (only if new files were created).
3. `sl commit -m "<what learning was captured + where it landed>"`, then `sl push --to master`.

Closing a thread is **not done** until the learning is committed and pushed to notes master.

**The asymmetry this fixes:** memory is dedup-by-design (one file per learning, `MEMORY.md` index); the cheatsheet side was append-only. Closing a topic = ask *"is this NOVEL, or another instance of something already captured?"* — default to logging evidence, not adding rules.

## Full guide

`~/notes/users/dennyzhang/scripts/learnings/auto-save-learnings.md`

_Last updated: 2026-06-14. Maintainer: dennyzhang._
