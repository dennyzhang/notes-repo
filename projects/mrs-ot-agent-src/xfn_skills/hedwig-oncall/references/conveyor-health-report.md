# Hedwig Conveyor Health Report

Generate a comprehensive weekly health report for all Hedwig-owned Conveyor deployments and post it to Workplace.

## When to Use

Use this runbook when:
- The user asks to generate the weekly Hedwig conveyor health report
- MyClaw triggers this skill on the Tuesday schedule
- The user asks about the status of all Hedwig conveyors

## Example Prompts

- `run the hedwig conveyor report`
- `generate the weekly hedwig conveyor health report`
- `hedwig conveyor report`
- `run the hedwig conveyor report, report only`
- `hedwig conveyor report --dry-run`
- `preview the hedwig conveyor report`

## Output Mode

This report supports two output modes:

- **post** (default): Generate the report AND post it to the Workplace group. Use this mode when the user says "generate and post the report", when MyClaw triggers the skill, or when no mode is specified.
- **report-only**: Generate the report and print it directly to the terminal. Do NOT post to Workplace. Use this mode when the user says "just generate the report", "don't post", "report only", "dry run", "preview", or "--dry-run".

If the user's intent is unclear, default to **post** mode. If the user explicitly asks to not post or just see the report, use **report-only** mode.

## Configuration

```
ONCALLS:
  - downloads
  - hedwig_secondary_do_not_use

WORKPLACE_GROUP_ID: 179830296674125
```

## Step-by-Step Instructions

### Phase 1: Discover All Hedwig Conveyors

Run both oncall searches to get the complete list:

```bash
conveyor search --oncall "downloads" 2>&1
conveyor search --oncall "hedwig_secondary_do_not_use" 2>&1
```

Parse the output tables to extract all unique conveyor IDs. Deduplicate across both oncalls. The typical set includes ~15-18 conveyors. New conveyors may appear; always use the live search results.

### Phase 2: Get Node Structure for Each Conveyor

For each conveyor, run:

```bash
conveyor info --conveyor-id <conveyor_id> 2>&1
```

From the output, identify:
1. **Whether the conveyor is enabled or disabled** (look for "Conveyor <id> : enabled/disabled")
2. **Push node names** - look for nodes with `smc_tier: "Conveyor.PushNode"` or `"ServiceFoundry.FbpkgNode"`:
   - Nodes containing "prod", "push", "Production", "ship_to_prod" = production push nodes
   - Nodes containing "rc", "ship_to_rc", "rc:test", "preprod" = RC (release candidate) nodes
   - Nodes containing "canary" = canary nodes
   - Node named "tumbleweed" = configerator staged rollout (treat as prod)
   - Node named "fbpkg" = fbpkg-only publish (no TW push)
3. **Node enable/disable status** (look for "Node <name> : enabled/disabled")
4. **Whether it's a build-only conveyor** (no push nodes at all)

### Phase 3: Get Recent Run Status

For each push node (prod and RC) found in Phase 2, run:

```bash
conveyor run status --conveyor-id <conveyor_id> --node-name "<node_name>" --limit 20 2>&1
```

**Use `--limit 20`, not 3.** Three runs is not enough to find the last SUCCESSFUL prod deploy when a conveyor is stuck behind a wall of failures, nor to measure a failure streak. If all 20 returned prod runs are non-SUCCESSFUL, the conveyor has not shipped in a long time — increase the limit (or page) until you find a SUCCESSFUL prod run or you have looked back ≥ 30 days. Do not stop at the first ONGOING/FAILED run and assume health.

From the output, extract:
1. **Run statuses**: SUCCESSFUL, ONGOING, PAUSED, FAILED, APPLICATION_FAILURE, SCHEDULED, SKIPPED, CANCELLED, INFRA_ERROR
2. **Timestamps**: scheduled time, start time, end time
3. **Release numbers**: R123, R456, etc.

#### Step 3a — Compute two facts per conveyor (independent of current activity)

These two numbers are the backbone of classification. Compute BOTH before picking a bucket:

- **`last_success_age`** = time since the **last SUCCESSFUL prod deploy**. An ONGOING, PAUSED, or FAILED run does **NOT** count as a deploy. Staleness is reset **only** by a SUCCESSFUL prod release. A release that is currently ONGOING does not clear staleness — if the last *successful* one was 10 days ago, the conveyor is 10 days stale no matter what is running right now.
- **`failure_streak`** = number of **consecutive** FAILED / APPLICATION_FAILURE / INFRA_ERROR prod releases since the last SUCCESSFUL one.

#### Step 3b — Classify by precedence (FIRST match wins, evaluated top to bottom)

The buckets overlap, so order matters. Evaluate in this exact order:

| # | Classification | Criteria (first match wins) |
|---|---|---|
| 1 | **Disabled** | Conveyor or push node is disabled |
| 2 | **Build-only** | No push nodes exist (report as "N/A") |
| 3 | **Failing** | `failure_streak >= 3`, OR ≥ 2 of the last 3 prod runs failed. If `last_success_age > 5d` as well, label it **"Failing + Stale (Nd)"** — this is the most severe state. |
| 4 | **Stale** | `last_success_age > 5d`. **This applies even if a run is ONGOING/PAUSED right now** — an in-flight release does not make a stale conveyor healthy. |
| 5 | **Active** | An ONGOING/PAUSED prod/RC run exists **AND** `last_success_age <= 5d` **AND** no failure streak. (i.e. a genuinely healthy in-progress deploy.) |
| 6 | **Healthy** | Last prod run was SUCCESSFUL within the last 5 days, no active failure streak |
| 7 | **RC-only** | No prod node, only RC node |

#### Step 3c — Classification principles (read before bucketing)

- **An ONGOING or PAUSED release never clears Stale or Failing.** "Something is running right now" is not health. Only a SUCCESSFUL prod deploy resets staleness.
- **A sustained run of consecutive FAILED releases IS staleness, not flakiness.** Never dismiss ≥ 3 consecutive prod failures (or a multi-day failure wall) as "release-specific flaky builds" or "newer builds failing while prod is stable." If new releases cannot reach prod for days, the conveyor is broken and stale — flag it Failing, regardless of how stable the last *successful* release looks.
- **A long-ONGOING release is a stuck release, not an active one.** If an ONGOING run's duration is much longer than this conveyor's normal deploy time (rule of thumb: > 2× typical, or > 6h with no multi-region/bake reason), flag it under Failing / Needs Attention as "push stuck", not under healthy Active Deployments.
- **Apply the failure-streak rule consistently.** If 5 consecutive failures escalates one conveyor (e.g. loadgenerator), the same threshold must escalate every other conveyor — do not give one a pass because its prod release "looks stable."

### Phase 4: Format the Report

Split conveyors into sections by status (Failing first for visibility) instead of one giant table. Use short date format (e.g., "Mar 9" instead of "2026-03-09"). Link each conveyor ID to its Conveyor UI page.

```markdown
# Hedwig Conveyor Health Report - [DATE]

**Summary:** [N] total | [N] Healthy | [N] Active | [N] Failing | [N] Stale | [N] Disabled | [N] Build-only

---

## Failing / Needs Immediate Attention

| Conveyor | Issue | Since | Current State |
|----------|-------|-------|---------------|
| [conveyor_id](https://www.internalfb.com/conveyor/<conveyor_id>/releases) | Stale - no prod deploy in [N] days | Last: Mon D (RXXX) | No recent runs |
| [conveyor_id](https://www.internalfb.com/conveyor/<conveyor_id>/releases) | Prod consecutive APPLICATION_FAILUREs | RXXX (Mon D), RXXX (Mon D) | RXXX **PAUSED** |

## Active Deployments

Only list genuinely healthy in-progress deploys here (see Phase 3 precedence — a stuck or behind-a-failure-wall release does NOT belong here; it goes under Failing). Always show **Last Success** (days since last SUCCESSFUL prod deploy) so a long-stale conveyor cannot hide under "active".

| Conveyor | Node | Release | Started | Last Success |
|----------|------|---------|---------|--------------|
| [conveyor_id](https://www.internalfb.com/conveyor/<conveyor_id>/releases) | prod | RXXX | Mon D HH:MM TZ | Mon D (Nd ago) |

## Healthy Conveyors

| Conveyor | Last Prod Deploy | Last RC Deploy | Notes |
|----------|-----------------|----------------|-------|
| [conveyor_id](https://www.internalfb.com/conveyor/<conveyor_id>/releases) | Mon D (RXXX) | Mon D (RXXX) | RC-only / fbpkg-only / Weekly Tue |

## Disabled / Inactive

| Conveyor | Reason |
|----------|--------|
| [conveyor_id](https://www.internalfb.com/conveyor/<conveyor_id>/releases) | Entire conveyor disabled / Push node disabled / Build-only |

---
*Generated by Claude Code on [DATETIME TZ] | Oncalls: downloads, hedwig_secondary_do_not_use*
```

### Phase 5: Deliver the Report

#### If output mode is **report-only**:
Print the full formatted report directly to the terminal as output text. Do NOT post to Workplace. Do NOT run any Workplace CLI commands.

#### If output mode is **post** (default):
Use the `meta` CLI to create a post in the Hedwig Workplace group.

**CRITICAL: You MUST use `--formatting=MARKDOWN`** to enable Markdown rendering (headers, tables, bold, links). Without this flag, Workplace treats the post as plaintext and all formatting is lost.

```bash
meta workplace.post create --group-id 179830296674125 --formatting=MARKDOWN --message "<report_content>" -o json
```

**Formatting notes:**
- The `--formatting=MARKDOWN` flag is **required** for tables, headers, bold, and links to render on Workplace
- Use `[link text](url)` for hyperlinks - link each conveyor ID to its Conveyor UI page: `[conveyor_id](https://www.internalfb.com/conveyor/<conveyor_id>/releases)`
- Use standard Markdown table syntax (`| col1 | col2 |` with `|---|---|` header separator)
- Keep the table compact - use short date format (e.g., "Mar 9" instead of "2026-03-09")
- If the message is very long, focus the "Failing" section and summarize healthy conveyors briefly

## Error Handling

- If `conveyor search` returns an error, retry once after 5 seconds
- If `conveyor info` or `conveyor run status` fails for a specific conveyor, note it as "Unable to fetch status" in the report and continue with the others
- If `meta workplace.post create` fails, retry once. If it fails again, save the report to `/tmp/hedwig-conveyor-report-YYYY-MM-DD.md` and inform the user

## MyClaw Scheduling

### Via GChat (manual setup)

Tell MyClaw in GChat:

> "Every Tuesday at 9 AM PST, run the hedwig conveyor health report. Generate the full Hedwig Conveyor Health Report and post it to Workplace group 179830296674125. Send me a draft in GChat first before posting."

MyClaw will create a recurring cron job that triggers this skill automatically.

### Via Dumbledore (automated, no GChat required)

Dumbledore has a dedicated MyClaw binary that runs Dumbledore **in-process** on the machine where MyClaw executes it. This means all CLI tools (`conveyor`, `ods`, `scuba`) are available just as they are in a normal Dumbledore session.

**Buck target:** `fbcode//confucius/analects/core_systems/platform_foundation/dumbledore:myclaw_dumbledore`

In MyClaw, create a scheduled task with:
- **Schedule:** Every Tuesday at 9:00 AM PST (cron: `0 17 * * 2`)
- **Command:** `buck run fbcode//confucius/analects/core_systems/platform_foundation/dumbledore:myclaw_dumbledore`

This posts to the Hedwig Dumbledore Training Workplace group (`4519087041698082`) by default.

To test immediately:
```bash
buck run fbcode//confucius/analects/core_systems/platform_foundation/dumbledore:myclaw_dumbledore \
  -- --run-now
```

To post to a different group or use a custom prompt:
```bash
buck run fbcode//confucius/analects/core_systems/platform_foundation/dumbledore:myclaw_dumbledore \
  -- --run-now --prompt "run the hedwig conveyor health report and post it to Workplace group 179830296674125"
```
