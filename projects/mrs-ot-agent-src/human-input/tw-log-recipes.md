# tw log recipes — canonical patterns for time-bounded trainer-log grep

`tw log` is the production tool for time-bounded grep against MAST trainer
logs at scale. Use it when:

- A specific time window is in scope (alert fired at HH:MM, want logs ±30 min).
- `meta ai.mast-job logs` would OOM (PHP 537 MB limit on large stderr files).
- You need to search across multiple trainers or attempts in one query.

`tw log` queries the underlying tw scribe storage directly — it bypasses the
PHP wrapper that enforces the size cap.

For full mast-job log triage workflow including OOM bypass via `lg` CLI,
see the `mvai:mast-job-inspector` skill. This file is the time-bounded grep
recipe library that complements it.

## Anatomy of a `tw log` command

```
tw log "<scribe_category>" --file <stream> -s "<start>" -e "<end>" -p "<regex>" -n <N>
```

| Flag | Required | Purpose |
|---|---|---|
| `<scribe_category>` | Yes | Trainer log path. Pattern below. |
| `--file` | Yes | `stderr` for trainer Python output, `stdout` for app stdout. |
| `-s` / `-e` | Yes | Start/end timestamps. Format `YYYY/MM/DD-HH:MM:SS`. Window <2h or query gets slow. |
| `-p` | Recommended | grep regex applied server-side. Reduces network + display volume. |
| `-n` | Recommended | Max line cap. Default unbounded — set to 200-500 for triage. |

### Scribe category path pattern

```
tsp_<region>/mast_hpc/<mast_job>.<role>.<rank>.<scheduler>/<attempt>
```

| Segment | Example | Notes |
|---|---|---|
| `tsp_<region>` | `tsp_maz`, `tsp_kcm`, `tsp_vll` | Region the trainer ran in. Find via `meta ai.mast-job metadata --name=<JOB>` `assignedAcc` field. |
| `mast_hpc` | (literal) | All MAST trainer logs live under this prefix. |
| `<mast_job>` | `mvai-training-online-2125763080` | Full MAST job name. |
| `<role>` | `trainer`, `dpp_worker` | Trainer process or DPP worker. |
| `<rank>` | `0`, `3`, `7` | Process rank within role. Rank 0 is usually the most informative. |
| `<scheduler>` | `0jk2f4`, `9ygk68` | 6-char per-attempt scheduler suffix. Find via `meta ai.mast-job attempts --name=<JOB> -o json`. |
| `<attempt>` | `0`, `1` | Attempt number within version. Most recent attempt is usually what you want. |

The scheduler suffix changes every attempt — copy it from the
`attempts` output for the attempt you're targeting.

## Common recipes

### 1. Find trainer-side errors in a time window

```
tw log "tsp_maz/mast_hpc/<JOB>.trainer.3.<sched>/0" \
  --file stderr \
  -s "2026/05/01-21:00:00" -e "2026/05/01-23:00:00" \
  -p "error|ERROR|warn|WARN|NCCL|timeout|hang|stuck|stall|exception|CUDA" \
  -n 500
```

Use when an alert fires and you want every fault-class signal in the window.
Cap at 500 lines to avoid drowning in `WARN`s.

### 2. Reconstruct NE-reporting cadence

```
tw log "tsp_maz/mast_hpc/<JOB>.trainer.3.<sched>/0" \
  --file stderr \
  -s "2026/05/01-21:00:00" -e "2026/05/01-23:00:00" \
  -p "CLIPS_PLIKE/train at step" \
  -n 200
```

Each match is one NE report. Compute time deltas between consecutive
matches to detect "training stalled" gaps. Normal cadence is 30-60
seconds; gaps over 5 min are anomalies; over 30 min indicates a
publish-blocking stall.

### 3. Find publish-blocking PublishRateLimiter activity

```
tw log "tsp_maz/mast_hpc/<JOB>.trainer.3.<sched>/0" \
  --file stderr \
  -s "<window-start>" -e "<window-end>" \
  -p "PublishRateLimiter|published partial message|TGIF.*Saving subgraph" \
  -n 300
```

Surfaces Hedwig adaptive flow control activity during a publish window.
Look for `Max publishing rate set to <N> bytes/sec` lines — if the rate
stays at the 2 MiB/s floor (`hedwig/streaming:flow_control_min_publishing_rate`)
for >5 min on a sparse channel, the publisher is starved.

### 4. Find DPP starvation / data-pipeline stuck

```
tw log "tsp_maz/mast_hpc/<JOB>.trainer.3.<sched>/0" \
  --file stderr \
  -s "<window-start>" -e "<window-end>" \
  -p "DataClientStuckException|DPP.*stuck|getNextBatch|data_starvation|DPP_WORKER_STUCK" \
  -n 200
```

DPP-stuck symptom is the canonical "trainer waited for data and got
nothing" signal. Pull the verbatim error including session ID and tag
(e.g., `DPP_WORKER_STUCK_FULL_OUTPUT_QUEUE`) for the diagnosis.

### 5. Checkpoint save and TGIF publish lifecycle

```
tw log "tsp_maz/mast_hpc/<JOB>.trainer.3.<sched>/0" \
  --file stderr \
  -s "<window-start>" -e "<window-end>" \
  -p "checkpoint|save|saving|snapshot|Force validate metrics|Memory usage|Read checkpoint commit" \
  -n 500
```

Reconstructs the checkpoint + publish lifecycle. `Force validate
metrics starting` typically appears every ~4 min when training is
healthy; gaps over 10 min mean training is blocked.

### 6. Check TGIF model packaging duration

```
tw log "tsp_maz/mast_hpc/<JOB>.trainer.3.<sched>/0" \
  --file stderr \
  -s "<window-start>" -e "<window-end>" \
  -p "torch_package_utils|tp packaged_model_bytes|sample_input_utils|dense_quantization_pass" \
  -n 100
```

Measures the on-rank-0 model packaging step that precedes the BD/Hedwig
publish. If this step itself takes >5 min, the bottleneck is CPU-bound
torch packaging, not Hedwig delivery.

## Time-window selection

| Symptom | Window | Reason |
|---|---|---|
| Alert fired at HH:MM | `[HH-1:00, HH+1:00]` | Captures trigger event + post-fire state |
| Stuck/hang reported by user | `[trigger-30min, trigger+1h]` | Stuck symptoms develop over 10-30 min |
| Publish stall | `[hourly_publish_window-15min, +1h]` | TGIF publishes are hourly; align to that boundary |
| NCCL / collective timeout | `[symptom-2h, symptom]` | NCCL watchdog can fire long after the rank that hung |

Keep windows under 2 hours per query for performance. Run multiple
narrow queries rather than one wide one.

## When `tw log` fails or isn't enough

- **Region wrong:** `tsp_maz` only catches Maz-region trainers. Check
  `meta ai.mast-job metadata --name=<JOB>` for assignedAcc; if it shows
  `tsp_kcm` or `tsp_vll`, swap the prefix.
- **Scheduler suffix wrong:** the suffix changes per attempt. If the
  query returns nothing, recheck `meta ai.mast-job attempts -o json` for
  the right suffix on the right attempt.
- **Log file rotated out:** logs older than ~14 days may be archived. Use
  `lg` CLI (per `mvai:mast-job-inspector` skill) for archived logs.
- **Trainer dead before timestamp:** if attempt 1 started at HH:00, no
  trainer logs exist before HH:00 for that attempt. Query attempt 0 for
  pre-restart logs, attempt 1 for post-restart.

## Cross-references

- `mvai:mast-job-inspector` skill — canonical mast-job log triage
  including `lg` CLI for OOM cases. Load via Skill tool when log access
  is the blocker.
- `mvai:mvai-ot` reliability skill — broader OT triage workflow that
  invokes these `tw log` recipes as the log-evidence step.
- `references/triage-reference.md` — when a triage needs both `tw log`
  evidence AND the broader symptom-to-stage routing.
