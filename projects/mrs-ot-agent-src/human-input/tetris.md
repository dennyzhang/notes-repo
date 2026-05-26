# Tetris (MAST Job Placement) — Concept Reference

> **What this is**: glossary + routing entry for "Tetris" as it appears in OT/MVAI escalations. Not OT-owned — but OT oncall is frequently looped in because Tetris kills surface as "MAST job won't start" or "MAST job killed mid-flight," which look like OT failures.
>
> **Cross-refs**: `references/escalation-routing.md` (routing table), `references/pipeline-architecture.md` (stage T2), and fbcode `minimal_viable_ai/fire/fire_options.py` + `tool/resolve_tetris_args.py` for code-level details.

---

## What Tetris Is

**Tetris** is MAST's **data-locality job placement system**. When a MAST job declares which Hive tables/partitions it will read (via `tetrisArgs`), Tetris uses that to place the job in a data center close to the source data — minimizing cross-region network traffic.

Owned by: **`di_tetris`** (Data Infrastructure → Tetris). Adjacent oncalls: **`mast_hpc`** (MAST scheduler / runtime), **`mast_optimizer`**.

NOT owned by: MVAI, mrs_online_training, model_processing, SilverTorch.

## How Tetris Args Are Declared

Trainer fire_args must declare reads via three CLI flags:
```
--table-namespace <ns>          # e.g. instagram, feed_fblearner, search, groups
--table-name <hive_table_name>
--partition-str <partition_filter>
```

Multiple reads can be combined with `|` separators in `--table-name` / `--partition-str` for jobs that read multiple tables (e.g., training + candidate pool).

### Runtime macro substitution

Most IG/Threads run configs use a macro instead of a literal:
```
--table-namespace '{ACTIVE_RUN_CONFIG.train_namespace}'
--table-namespace '{ACTIVE_CONFIG.train_namespace}'
```
The macro resolves at fire-args-parse time from the active `RunConfig` dataclass:
```python
@dataclass
class MyRunConfig:
    train_namespace: str
    ...

CONFIG_PROD = MyRunConfig(train_namespace="instagram", ...)
```
This pattern is canonical across `models/ig_ranking/threads_esr/`, `threads_lsr/`, `threads_retrieval/feed_u2m_*/`, etc. — every IG/Threads model sets `train_namespace="instagram"`. The macro is **not FB-only** despite its surface appearance.

## Canonical Failure Modes

| Error string | Meaning | Stage | Fix |
|---|---|---|---|
| `empty regionSelectionArgs.tetrisArgs` | fire_args declared no Hive reads → Tetris can't place the job | scheduling (job never starts) | declare `--table-namespace` + `--table-name` + `--partition-str` |
| `reading data not specified in tetrisArgs` | trainer attempted to read a partition not declared in fire_args → MAST kills mid-flight | runtime (job dies after starting) | extend the declaration to cover ALL tables the trainer reads (incl. side tables, candidate pools, signal tables) |
| `MAST job PENDING, never scheduled` | possibly a Tetris-side regional-capacity issue (no region has both the data and the GPU type) | scheduling | route to `di_tetris`; check region balance |
| `--partition-str` collapses to single partition | known Tetris bug: trainer reads N partitions but Tetris only auths one (see `models/ig_ranking/lsr/integrity/feed_preport/o3_aa_mvai/launch.py` write-up) | runtime | use multi-day spec with `|` separators OR `--no-resolve-tetris-from-trainer-config` |

## Bypass

To skip auto-resolution and pass tetrisArgs literally:
```
--no-resolve-tetris-from-trainer-config
```
Used by `models/marketplace/ranking/tab_ctr_mtml/`, `models/fb_ff_pass1/`, `models/notif_psmsl/`, and several sandbox launchers. Saves ~1.5 min of resolution time but means the trainer-config doesn't drive declarations — fire_args must be complete.

## When OT Oncall Gets Looped In (and how to route out)

OT oncall is frequently tagged on Tetris issues because:
- The symptom ("trainer won't start" / "MAST killed my training job") looks OT
- The fix touches `extra_fire_args` on OT job configs
- The team launching a new OT model doesn't know Tetris isn't OT-owned

**OT oncall's job here is to recognize the pattern and route**:

| Sub-question | Route to |
|---|---|
| "Is the proposed fix correct?" (specific `--table-namespace` / `--table-name` config) | OT oncall can answer using fbcode patterns above; no escalation needed |
| "Why is MAST killing my job with tetrisArgs error?" | `mast_hpc` (runtime) or `di_tetris` (data-locality) |
| "Job won't schedule, all PENDING" | `di_tetris` / `mast_optimizer` |
| "Tetris arg validation seems broken / silently dropping partitions" | `di_tetris` (known multi-partition bug class, see `feed_preport/o3_aa_mvai/launch.py` for canonical write-up) |

## Code Anchors (fbcode)

- **CLI definition**: `minimal_viable_ai/fire/fire_options.py:262` — `--table-namespace` (help: `e.g. '--table-namespace=instagram'`)
- **Auto-resolve flag**: `minimal_viable_ai/fire/fire_options.py:629` — `--resolve-tetris-from-trainer-config / --no-resolve-tetris-from-trainer-config`
- **Resolver**: `minimal_viable_ai/tool/resolve_tetris_args.py` — script that pulls table info from trainer config; called by fire-launched MAST jobs
- **Partition utility**: `minimal_viable_ai/hive/partition_utils_lite.py:1555` — `get_physical_partition_names_of_logical_view_for_tetris`
- **Documented bug**: `minimal_viable_ai/models/ig_ranking/lsr/integrity/feed_preport/o3_aa_mvai/launch.py` (`get_partition_names_for_tetris` silently drops user-specified partitions in favor of latest-only)
- **External wiki**: `MAST/MAST_FAQs/MAST_Support/job_failure_due_to_"reading_data_not_specified_in_tetrisArgs"`

## OT-Specific Notes

1. **Tetris failures look like OT failures** but are upstream. If you see a MAST kill with "tetris" in the error, fix in fire_args, then route to `di_tetris` / `mast_hpc` if pattern recurs.
2. **`--no-resolve-tetris-from-trainer-config`** can mask issues — if a team adds this flag to silence the error, verify their fire_args are complete (all tables declared). Otherwise the trainer reads data without Tetris auth, which may eventually fail in a less-obvious way.
3. **Streaming / OT specifics**: `models/ig_ranking/threads_esr/tifu/run_config.py:140` defines `TIFU_ESR_STREAMING_TETRIS_PARTITION` — pattern for declaring streaming-table reads to Tetris (different from batch table reads).

## Provenance

Added 2026-05-22 after debugging session in ESR item streaming chat (`AAQAosHzPPs`). The group was launching OT for a new IG ESR prod model (2129445831) and hit a Tetris kill; Keir proposed the `--table-namespace '{ACTIVE_RUN_CONFIG.train_namespace}'` macro fix and asked whether it was correct for IG. Answer: yes, the macro resolves to `instagram` at runtime via the RunConfig dataclass field. Question came in because Tetris is unfamiliar territory for OT-side engineers.
