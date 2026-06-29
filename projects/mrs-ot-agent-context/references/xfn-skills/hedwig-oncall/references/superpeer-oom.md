# Superpeer OOM Investigation

This runbook covers memory issues in Hedwig Superpeers.

Reference: https://docs.google.com/document/d/1ieCEuLxOmEP91IxDiYF6Pu4ymUU1fh_8h-sKaFgnnus/edit?tab=t.0#heading=h.hwy8m7lv7vzh

## How to Use

Share a superpeer OOM alert link with Claude and ask it to investigate.

**Example prompts:**
- `Investigate Hedwig oncall issue https://fburl.com/onedetection/...`
- `Hedwig superpeer is OOMing in frc, here's the alert: https://fburl.com/onedetection/...`
- `Help me debug superpeer memory issues`

## Step 0: Parse the Alert

Before investigating, extract key context from the alert. If the user hasn't provided the alert link, ask for it (e.g. `https://fburl.com/onedetection/...`).

From the alert, extract:
- **Job handle** — the superpeer TW job experiencing OOMs
- **Region** — which datacenter region is affected
- **Time range** — when the OOM events started

Present a brief summary to the user before proceeding:
> **Alert Summary**: Superpeer job `hedwig.download.superpeer.XXX` is OOMing in `frc` region.

## Key Dashboard

**Superpeer Dashboard**: https://fburl.com/unidash/rk6m7hg6

## Check Outflows

Dashboard: https://fburl.com/canvas/gpb389yn

If outflows increased significantly, reduce max outflows:
- Example diff: D79325782

## Check Inflows

Superpeers are prone to OOMs when inflow count > 30.

### Step 1: Check Logs for Inflow Count

Look for "# in progress" in logs. Example paste: P1917188484

### Step 2: Identify Client Causing Increased Inflows

Query: https://fburl.com/scuba/download_investigator/wengex5r

This query helps identify which client is sending excessive requests.

### Step 3: Reduce Inflows for Specific Client

- Example diff: D79847306

## Mitigation Steps

> **⚠️ Do not execute write operations directly.** Present them as recommendations and let the user run them after reviewing.

1. **Stop any ongoing deployment**:
   https://www.internalfb.com/svc/services/hedwig_download/superpeer/conveyor/hedwig_download/superpeer/releases

2. **Check Superpeer Dashboard**:
   https://fburl.com/unidash/rk6m7hg6

3. **Use strobelight for CPU profiling** if needed

4. **Suggest adding capacity if available**:
   ```bash
   # Suggest this command to the user:
   tw resize tsp_XXX/hedwig/hedwig.download.superpeer.XXX --add-task-count X
   ```

## Common OOM Triggers

| Trigger | Symptom | Solution |
|---------|---------|----------|
| High inflows (>30) | Memory spikes during downloads | Reduce inflow limits |
| High outflows | Memory spikes during uploads | Reduce outflow limits |
| Large file transfers | Sudden memory increase | Check for unusually large files |
| Client misbehavior | Sustained high traffic from one source | Throttle specific client |

## Related Files

- `debugging-tools.md` - TW commands and Scuba queries
- `dashboards.md` - All dashboard links
