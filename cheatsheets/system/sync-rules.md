# Sync Rules Cheatsheet

Files that MUST stay in sync. When you touch one site, update all paired sites in the **same edit**. A single-site change is a bug.

**Load before:** editing any file in this table, OR adding a state file / hook / cron script / cheatsheet.

## A. Code review hygiene (state-file hiding)

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Adding/removing an auto-generated state file | `.gitattributes` (add `linguist-generated=true`) **AND** `scripts/git-review.sh` `STATE_REGEX` | Both control "skim only" treatment — GitHub web view (gitattributes) and local `git-review.sh` STATE bucket. Mismatch = file shows as SIGNAL in one viewer, STATE in the other. (Caught 2026-04-20) |

## B. Persistence (root copies vs cache copies)

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Editing handoff content | `HANDOFF.md` (root) **AND** `context/cache/state/HANDOFF.md` | `/my-save` writes the cache copy, then `cp` to root. Both must match. |

## C. Hook & settings registration

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Adding/changing a hook script | The script in `config/hooks/` **AND** registration in `.claude/settings.json` `hooks` block | Unregistered hook scripts are dead code. (AUTO-LEARNINGS 2026-03-25 — auto-prescreener.sh stayed unwired and missed Privacy Review) |
| Editing `.claude/settings.json` | User-level settings **AND** project-level `~/work/claude/.claude/settings.json` | Hooks live in both. Updating one creates blind spots. (AUTO-LEARNINGS 2026-03-24) |

## D. Cron registration

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Adding a new cron script under `scripts/cron-*.sh` | The script **AND** crontab block in `scripts/setup-claude.sh` **AND** `source cron-alert.sh` inside the script | An unregistered cron script never runs (ALERTS.md 2026-04-15: `cron-gchat-copilot.sh` existed for weeks unregistered). Missing `cron-alert.sh` source = no failure detection. |
| Changing a cron job's purpose/schedule | The cron script **AND** `cron-ai-health.sh` JOB_DESCRIPTIONS lookup | Dashboard rows without descriptions trigger "what's the difference?" questions. (AUTO-LEARNINGS 2026-04-06) |

## E. Reinstall survival (devserver wipes ~/.myclaw and ~/.metaclaw)

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Fixing `~/.myclaw/config.json` or `~/.metaclaw/config.json` | The live config **AND** an idempotent enforcement block in `scripts/setup-claude.sh` | Devserver reinstalls wipe the live config. The setup script must re-enforce. (AUTO-LEARNINGS 2026-04-01) |
| Adding a new authoritative server/host to scripts | `scripts/setup-claude.sh` server list **AND** `scripts/cron-keepalive.sh` server list **AND** `config/INFRASTRUCTURE.md` "Devservers" table | Three sites currently mirror this list. Drift = reinstall picks wrong host. |

## F. Protocol ↔ enforcement code

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Changing a routine/area protocol RULE | The protocol file (`workflows/PROTOCOL-*.md` or `ROUTINE-DOC-RULES.md`) **AND** the cron script that enforces it | A protocol rule without code enforcement is silent decoration. (ROUTINE-DOC-RULES.md 1636/1800: "Both must change in the same pass.") |
| Changing routine HTML format | The protocol file **AND** `workflows/templates/ROUTINE-TEMPLATE.html` | "Template and protocol were out of sync" was the bug. (ROUTINE-DOC-RULES.md line 181) |

## G. Task & people tracking

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Diff status changes | `TASKS.md` row **AND** linked Meta Task | Stale Meta Tasks become invisible work. (cheatsheets/system/meta-tasks.md) |
| Interacting with a person | The interaction note **AND** `REGISTRY.yaml` `last_interaction` for that unixname | Stale `last_interaction` makes the relationship-cadence dashboard lie. (`.claude/commands/my-people.md` step 5) |

## H. Doc lifecycle

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Project doc merged/renamed/deprecated | Brainstorm doc project index **AND** the doc itself **AND** `FOLLOWUPS.md` cleanup row | Three failure modes: stale standalone listings, name mismatches, dead-doc rows. (AUTO-LEARNINGS 2026-03-26) |
| Doc retired or replaced from monitoring | Comment-processing prompt's Monitored Docs list **AND** `processed.json` | A doc dropped from monitoring silently stops getting comment processing. (AUTO-LEARNINGS 2026-04-12) |

## I. Cheatsheet & memory

| Trigger | Sites that MUST update together | Why |
|---------|---------------------------------|-----|
| Adding a new cheatsheet | The cheatsheet file **AND** `cheatsheets/CHEATSHEET-INDEX.md` Quick Routing **AND** the category file count | Unindexed cheatsheets won't be auto-loaded. |
| Adding a memory file | The `<name>.md` file **AND** an entry in `MEMORY.md` index (one line, ≤150 chars) | `MEMORY.md` is the loaded index. Files without index entries are invisible. (memory bootstrap rule) |

## Meta-rule

> **If a piece of information has two valid homes, both are authoritative — and either home being wrong is a bug.**
> Add to all homes in the same diff. If you can't, add a tracking entry in `FOLLOWUPS.md`.

## Quick self-check (before commit)

1. Re-read the table — did I touch all paired sites?
2. Run `scripts/git-review.sh` — verify SIGNAL/STATE buckets look right.
3. New state file? → in `.gitattributes` AND `git-review.sh`?
4. New cron? → in `setup-claude.sh` crontab AND sources `cron-alert.sh`?
5. New hook? → registered in `.claude/settings.json`?

## How to extend this cheatsheet

Add a new row whenever:
- Boss catches a single-site change ("did you also update X?")
- An AUTO-LEARNINGS entry contains "in sync" / "also update" / "both must"
- A new cron registration / hook registration / config fix incident occurs

Cite the source incident in the row (file path + date or AUTO-LEARNINGS date).

_Last updated: 2026-05-12. Maintainer: dennyzhang._
