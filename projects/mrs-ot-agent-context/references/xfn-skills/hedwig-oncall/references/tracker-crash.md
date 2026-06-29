# Tracker/Seeder Crash Investigation

This runbook covers application crashes in Hedwig Tracker and Seeder components.

Reference: https://www.internalfb.com/wiki/Hedwig/Runbook/

## How to Use

Share a tracker/seeder crash alert link with Claude and ask it to investigate.

**Example prompts:**
- `Investigate Hedwig oncall issue https://fburl.com/onedetection/...`
- `Hedwig tracker is crashing, here's the alert: https://fburl.com/onedetection/...`
- `Help me debug tracker crash in frc`

## Step 0: Parse the Alert

Before investigating, extract key context from the alert. If the user hasn't provided the alert link, ask for it (e.g. `https://fburl.com/onedetection/...`).

From the alert, extract:
- **Component** — tracker or seeder (from the job handle pattern)
- **Job handle** — the TW job experiencing crashes
- **Region** — which datacenter region is affected
- **Time range** — when the crashes started

Present a brief summary to the user before proceeding:
> **Alert Summary**: Tracker job `hedwig.download.tracker.XXX` is crashing in `frc` region.

## Step 1: Check for Crashes

### Search Coredumper Scuba Table

Query coredumper for crash stacks:
- Scuba table: https://fburl.com/scuba/coredumper/

Filter by:
- Job name (e.g., `hedwig.download.tracker.*`)
- Time range around the incident
- Region if known

### Check TW Logs

```bash
tw search tsp_XXX/hedwig/hedwig.download.tracker.XXX
```

Look for:
- Crash information
- Error messages
- Stack traces

## Step 2: Identify Root Cause

Common crash causes:

| Cause | Symptoms | Investigation |
|-------|----------|---------------|
| Code bug | Crash after deployment | Check recent diffs, revert if needed |
| Bad input | Crash on specific requests | Check request logs, identify bad data |
| Resource exhaustion | Crash under load | Check memory/CPU usage |
| Dependency failure | Crash when calling external service | Check downstream service health |

## Step 3: Mitigation

> **⚠️ Do not execute write operations directly.** Present them as recommendations and let the user run them after reviewing.

### Revert to Older Version (if push is happening)

ServiceFoundry UI/CLI: https://www.internalfb.com/intern/wiki/ServiceFoundry/UserGuide/Push/Reverting/#reverting-from-the-cli

```bash
# Suggest this command to the user:
sf push revert --service hedwig_download_tracker
```

### Stop Ongoing Deployment

If a deployment is in progress and causing issues, stop it immediately.

### Restart Job

```bash
# Suggest this command to the user:
tw restart tsp_XXX/hedwig/hedwig.download.tracker.XXX
```

## Analyzing Crash Stacks

1. Get the crash stack from coredumper
2. Look for the failing function/line
3. Check recent changes to that code area
4. File a task if bug found, or revert if urgent

## Related Files

- `debugging-tools.md` - TW commands and Scuba queries
- `dashboards.md` - Tracker dashboard link
