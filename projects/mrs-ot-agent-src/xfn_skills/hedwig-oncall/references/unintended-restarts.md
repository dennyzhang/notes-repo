# Unintended Task Restarts

This runbook helps debug the "Unintended task restarts" alarm for Hedwig TW jobs.

## How to Use

Share an unintended restarts alert link with Claude and ask it to investigate.

**Example prompts:**
- `Investigate Hedwig oncall issue https://fburl.com/onedetection/...`
- `Hedwig TW job is restarting unexpectedly, here's the alert: https://fburl.com/onedetection/...`
- `Help me debug unintended_job_restarts alarm for hedwig superpeer`

## Step 0: Parse the Alert

Before investigating, extract key context from the alert. If the user hasn't provided the alert link, ask for it (e.g. `https://fburl.com/onedetection/...`).

The alarm shows a Timeseries ID that identifies which TW job is restarting unexpectedly:

```
Timeseries ID: tsp_gtn/hedwig/hedwig.download.superpeer.smart_cache.gtn@#$tw.unintended_job_restarts.sum.60
```

From the alert, extract:
- **Job handle** — from the timeseries ID (e.g., `tsp_gtn/hedwig/hedwig.download.superpeer.smart_cache.gtn`)
- **Region** — from the job handle prefix (e.g., `gtn`)
- **Component** — from the job handle pattern (superpeer, tracker, or seeder)
- **Time range** — when the restarts started occurring

Present a brief summary to the user before proceeding:
> **Alert Summary**: Job `hedwig.download.superpeer.smart_cache.gtn` is experiencing unintended restarts in `gtn` region. Component: Superpeer.

## Step 0.5: Check for Confucius Turnup (Short-Circuit)

Before continuing, check whether this alert is for a Confucius-hosted Hedwig service being turned up. These services emit unintended-restart alerts during initial bring-up, but the restarts are expected and need no action.

**Apply this check only when the job handle starts with `confucius_`** (e.g., `confucius_dumbledore_webhook`). These are Hedwig-owned services hosted on the Confucius oncall-agent framework — the `confucius_` prefix refers to the hosting framework, not the owning team.

Check the job's creation time:

```bash
tw print <job_handle>
```

Look for the job creation timestamp in the output. If the job was created within ~24 hours of the alert window, treat the alert as a turnup:

- **Post a comment on the alert** explaining the situation. Suggested wording:
  > Alert is for `<entity>`, a Confucius-hosted Hedwig service that was recently turned up (job created `<timestamp>`). Task restarts during initial bring-up are expected. No Hedwig oncall action is required.
- **Do NOT page or escalate any oncall.** Stop investigation here.

If the job is older than ~24 hours, this is not a turnup — continue to Step 1.

> **Oncall routing for `confucius_*` entities**: When the entity is `confucius_*` and the cause turns out to be a real failure (not a turnup), escalating to Confucius oncall at the end of investigation IS appropriate — Confucius hosts the service. The rule above only blocks escalation when the restarts are caused by a turnup.

## Step 1: Identify the Failing Tasks

1. Click the **Failing Timeseries** link in the alarm to see which specific tasks are failing
2. Note the job handle and region from the timeseries ID

## Step 2: Identify the Production Area

Parse the job handle to determine which Hedwig component is affected:

| Job Handle Pattern | Component | Next Steps |
|-------------------|-----------|------------|
| `hedwig.download.superpeer.*` | Superpeer | See `superpeer-oom.md` |
| `hedwig.download.tracker.*` | Tracker | See `tracker-crash.md` |
| `hedwig.download.seeder.*` | Seeder | See `tracker-crash.md` |

## Step 3: Determine Root Cause

Common causes for unintended restarts:

### OOM (Out of Memory)

OOM kills are done by the kernel (cgroup limit enforcement) and do NOT produce `coredumper` crash stacks. If `coredumper` shows no results but tasks restarted, it is likely an OOM kill. Confirm by checking `tw.mem.anon` approaching the memory limit right before the restart.

For superpeers: Check inflow/outflow counts (see `superpeer-oom.md`).

For trackers: Classify whether the OOM was caused by increased traffic or by recovering from a prior task crash. The key differentiating signal is the **per-task memory timeline**:

- Check per-task memory using entity `twtasks(job=hedwig.download.tracker.XXX)` with key `tw.mem.anon`
- Check job-level restarts using entity `tsp_XXX/hedwig/hedwig.download.tracker.XXX` with key `tw.unintended_job_restarts.sum.60`

#### Category A: Traffic Increase

All tasks climb in memory together before any task dies. A load spike floods the tracker with downloads, pushing tasks past their memory limit.

**Confirming signals:**

| Counter | Entity | What to look for |
|---|---|---|
| `tw.mem.anon` | per-task `twtasks(...)` | All tasks climbing in parallel before any death |
| `hedwig_download.tracker.num_downloads_in_progress` | job-level | Rising across all tasks simultaneously |
| `hedwig_download.tracker.num_peers` | job-level | New peers joining the tier |

**Next steps:** Check the `download_investigator` Scuba table to identify which client ID is flooding the tracker (see `debugging-tools.md` for query examples). Check per-client configs in configerator for rate limiting options.

#### Category B: Recovery Cascade

One task dies first (from preemption, a smaller OOM, or a crash), then surviving tasks OOM as they absorb the dead task's peers and metadata.

When a tracker task dies, its peers re-register on surviving tasks, bringing their full cached chunk lists. This increases memory on surviving tasks through additional `PeerMetadata` objects, chunk-peer associations in `ChunkMetadata::cachers_`, and a snapshot storm (full chunk set exchange instead of incremental deltas). If surviving tasks were already near their memory limit, this added load pushes them over, causing a cascade.

**Confirming signals:**

| Counter | Entity | What to look for |
|---|---|---|
| `tw.mem.anon` | per-task `twtasks(...)` | One task drops to 0 (death), then others spike |
| `tw.unintended_job_restarts.sum.60` | job-level | Initial spike of 1, then a later spike of N |
| `hedwig_download.tracker.generate_chunk_snapshot_size` | job-level | Spikes after the first task death (snapshot storm) |
| `hedwig_download.tracker.update_chunks_cached_snapshot_latency_us` | job-level | Jumps from 0 to hundreds of ms |
| `hedwig_download.tracker.num_peers_failed` | job-level | Spikes on surviving tasks |
| `hedwig_download.tracker.num_chunks` | job-level | Dips then recovers (dead task's chunks erased, then re-added) |

**Next steps:** Determine what killed the first task:
- **TW preemption?** Check `tw diag` for scheduler events around the first death.
- **Prior OOM?** Check if `tw.mem.anon` was near the memory limit before the first death.
- **Application crash?** Check `coredumper` Scuba table for crash stacks (see `tracker-crash.md`).

#### Category C: Both (Most Common)

A traffic increase pushes one task over the edge, then the recovery cascade amplifies it. The Apr 21 (FTW RE trackers) and Apr 26 (global main trackers) incidents both followed this pattern. Look for rising `num_downloads_in_progress` before the first task death, followed by the cascade signals above.

### Application Crash
- Search `coredumper` scuba table for crash stacks
- Check TW logs for crash information
- Look for recent code changes that may have introduced bugs
- See `tracker-crash.md` for detailed steps

### Preemption
- Check TW scheduler events
- Verify capacity and entitlements

## Quick Mitigation

> **⚠️ Do not execute these commands directly.** Present them as recommendations and let the user run them after reviewing.

1. **Stop any ongoing deployment**:
   - Superpeer: https://www.internalfb.com/svc/services/hedwig_download/superpeer/conveyor/hedwig_download/superpeer/releases

2. **Suggest adding capacity if available**:
   ```bash
   # Suggest this command to the user:
   tw resize tsp_XXX/hedwig/hedwig.download.superpeer.XXX --add-task-count 4
   ```

3. **Suggest restarting the job** (if needed):
   ```bash
   # Suggest this command to the user:
   tw restart tsp_XXX/hedwig/hedwig.download.superpeer.XXX
   ```

## Reference Documentation

- Hedwig Runbook: https://www.internalfb.com/wiki/Hedwig/Runbook/
- Superpeer OOM Investigation: https://docs.google.com/document/d/1ieCEuLxOmEP91IxDiYF6Pu4ymUU1fh_8h-sKaFgnnus/edit?tab=t.0#heading=h.hwy8m7lv7vzh
