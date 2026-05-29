# Synced Google Docs (OT Agent Reference)

This directory is **auto-written** by the `ot-gdoc-context-sync` cron.

## What lives here

- `sources.json` — config: list of gdocs to ingest (doc_id, slug, title). Add a new entry to onboard a new gdoc.
- `<slug>.md` — one file per gdoc, frontmatter (`doc_id`, `doc_title`, `doc_url`, `last_synced`, `revision_id`) + raw markdown body. **DO NOT EDIT BY HAND** — the next cron run will overwrite local edits if the upstream revision changes.

## Why these gdocs are referenced

OT meeting notes and cross-team follow-up tables live in gdocs the team
maintains by hand. Bootstrapping a fresh OT-agent session from fbcode
alone misses that context. Sync runs daily, idempotent on `revisionId`
(no rewrite if upstream unchanged).

## To add a new gdoc

1. Append an entry to `sources.json` with the doc id, a kebab-case slug, and a human title.
2. Commit through the standard notes→fbcode flow (notes canonical → sqlite → fbcode weekly sync).
3. Next cron run picks it up; the new `<slug>.md` materializes on first sync.

## To stop syncing a gdoc

1. Remove the entry from `sources.json`.
2. Delete the corresponding `<slug>.md` (or leave it as a frozen snapshot — but it will go stale).

## Read-only

The cron does NOT write back to gdocs. Comments, follow-ups, and edits on
the source gdocs are owned by their human authors; we only mirror.
