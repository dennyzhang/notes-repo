---
name: hedwig-oncall
description: Debug Hedwig alarms and oncall issues, generate conveyor health reports, and guide customer onboarding of manifold buckets to Hedwig. Use when investigating TW job restarts, task crashes, OOMs, preemption issues, streaming staleness, missing publishers, stale subscriptions, streaming success rate drops, in-order delivery rate drops, in-order consumption rate drops, publisher queue buildup, flow control issues, publishing rate throttling, slow subscribers, slow P2P links, delivery rate SLI regression, SLICK SLI breach, aggregate delivery rate drops across clients, blob distribution issues, or other Hedwig service problems. Also use when onboarding a new manifold bucket or customer to Hedwig, setting up evaluation mode, enabling direct onboarding, or creating Hedwig configerator configs for a new bucket. Also use when checking if a model is onboarded to flow control, verifying flow control onboarding correctness, enabling flow control for a model, or onboarding a trainer/predictor to flow control. Also use when the user mentions "hedwig oncall", "hedwig alarm", "hedwig conveyor report", "conveyor health report", "flow control", "flow control onboarding", "onboard to flow control", "enable flow control", "is flow control enabled", "flow control config", "flow control bug", "flow control typo", "publishing rate", "delivery rate regression", "SLI regression", "SLI breach", "blob distribution", "BD tick failure", "BD client crashes", "BD subscription failures", "BD latency", "BD exceptions", "BD tenant metadata", "tenant metadata resolution", "cannot resolve tenant metadata", "BD deployment service error", "deployment service unexpected error", "BD patch tenant failures", "patchTenant failure rate", "BD create tenant failures", "putTenant failure rate", "too many create tenant failures", "BD bypass pacing failures", "BD retry attempt failures", "retry release failure", "bypass pacing failure", "BD health check failure", "deployment service health check", "health check failure prod", "health check failure RC", "BD excessive retries", "excessive execute retries", "too many retries deployment service", "onboard to hedwig", "manifold bucket onboarding", "hedwig onboarding", "evaluation mode", asks about Hedwig dashboards, runbooks, debugging tools, or wants to run Scuba or ODS queries for Hedwig metrics.
allowed-tools: Read, Bash, Bash(scuba:*), Bash(ods:*), Bash(conveyor:*), mcp__plugin_meta_www__knowledge_load
---

# Hedwig Oncall

Knowledge base for debugging Hedwig TW job alarms and issues, and guiding customer onboarding of manifold buckets.

> **📖 Source of Truth**: The canonical runbook is the [Hedwig Runbook Wiki](https://www.internalfb.com/wiki/Hedwig/Runbook/).
> This skill provides quick reference and supplementary context.

## How to Use This Skill

Share an alert link or describe a Hedwig oncall issue and Claude will investigate it.

**Example prompts:**
- `Investigate Hedwig oncall issue https://fburl.com/onedetection/zu7bih2w`
- `Help me debug this Hedwig alarm https://fburl.com/onedetection/3cdof8of`
- `Hedwig superpeer is OOMing, here's the alert: https://fburl.com/onedetection/irqbiubl`
- `Why is this Hedwig tracker crashing? https://fburl.com/onedetection/qoka4r37`

Claude will:
1. Parse the alert to identify the affected component, region, and time range
2. Route to the appropriate investigation runbook (staleness, OOM, crash, restarts)
3. Run Scuba and ODS queries to gather data
4. Analyze the root cause and suggest mitigation steps for you to execute

## Prerequisites

This skill uses several other skills for querying metrics and analyzing infrastructure. Before starting an investigation, check if the following skills are installed and offer to install any that are missing:

- **scuba_cli** — for querying Scuba tables (`claude-templates skill scuba_cli install`)
- **ods-counter-analyzer** — for querying ODS counters (`claude-templates skill ods-counter-analyzer install`)
- **tupperware** — for TW job/task diagnostics (`claude-templates skill tupperware install`)

Ask the user for consent before installing any missing skills.

## Safety Policy: No Automatic Write Operations

**CRITICAL**: Never automatically execute mutating/write operations. This includes:
- `tw resize`, `tw restart`, `tw update` — suggest the command and let the user run it
- `sf push revert` — suggest the command and let the user run it
- Configerator changes — draft the diff description and let the user create it
- Any operation that modifies production state

Always present these as **recommended mitigation steps** with the exact command, and ask the user to execute them after reviewing. Explain what each command does and why it's recommended.

## Quick Links

| Resource | Link |
|----------|------|
| **Hedwig Runbook (Source of Truth)** | https://www.internalfb.com/wiki/Hedwig/Runbook/ |
| Main Dashboard | https://www.internalfb.com/intern/unidash/dashboard/hedwig |
| Superpeer Dashboard | https://fburl.com/unidash/rk6m7hg6 |
| Tracker Dashboard | https://www.internalfb.com/intern/unidash/dashboard/hedwig/hedwig_tracker |
| Oncall Workplace Group | https://fb.workplace.com/groups/179830296674125 |

## Querying Scuba and ODS

This skill relies on the `scuba_cli` and `ods-counter-analyzer` skills for running queries. When investigating issues, **proactively run the relevant Scuba and ODS queries** from the runbook files rather than asking the user to check them manually.

For common Scuba and ODS query examples, see [references/debugging-tools.md](references/debugging-tools.md).

## Knowledge Base

Read the relevant file(s) based on the alarm or issue.

### Alerts

Each runbook starts with alert parsing (Step 0) to extract the affected component, region, and time range.

| Alarm/Topic | File | When to Use |
|-------------|------|-------------|
| Unintended task restarts | `references/unintended-restarts.md` | TW job restarting unexpectedly, alarm shows "unintended_job_restarts" |
| Superpeer OOM | `references/superpeer-oom.md` | Memory issues in superpeers, inflow/outflow problems |
| Tracker/Seeder crash | `references/tracker-crash.md` | Application crashes, coredumps |
| Streaming staleness | `references/streaming-staleness.md` | Stale subscriptions, missing publishers, staleness_detected alarms |
| Client success rate drop | `references/client-success-rate-drop.md` | Download client success rate drop alert |
| Client slow download rate | `references/client-slow-download-rate.md` | Download client slow download rate alarm |
| Streaming success rate | `references/streaming-success-rate.md` | Streaming success rate drops, in-order delivery/consumption rate drops, publisher queue buildup, model streaming message loss |
| Streaming delivery rate regression | `references/streaming-delivery-rate-regression.md` | Aggregate streaming delivery rate regression across all clients, SLICK SLI breach, identifying contributing clients, volume-weighted delivery rate drops |
| Flow control | `references/flow-control.md` | Flow control issues, publishing rate throttling, slow subscribers, slow P2P links, publishingRateDecider analysis, adaptive flow control debugging |
| Flow control onboarding | `references/flow-control-onboarding.md` | "Is this model onboarded to flow control?", "Is there a bug in flow control onboarding?", "Can you onboard trainer/predictor to flow control?", "Enable flow control for model X", flow control config verification, flow control typo detection |
| Digest mismatch | `references/digest-mismatch.md` | Download digest mismatch, client digest mismatch, CRC checksum failures |
| OSS peer | `references/oss-peer.md` | `Client success rate drop (OSS): hedwig-oss-peer` and `Download digest mismatch (OSS): hedwig-oss-peer` alarms; OSS peer (`hedwig-peer-oss`) running as `s32m-cks-proxy` DaemonSet in CKS clusters |
| Customer onboarding | `references/customer-onboarding.md` | New customer onboarding requests, Manifold bucket enablement, evaluation mode setup, direct onboarding |
| Customer FAQ | `references/customer-faq.md` | Customer questions about Hedwig download metrics, cache hit rate, errors, ODS metrics, dashboard access |
| Customer reachout (429) | `references/customer-reachout-429.md` | Everstore 429 errors, cache performance issues, customer reachout for high error rates |

### Blob Distribution Alerts

| Alarm/Topic | File | When to Use |
|-------------|------|-------------|
| BD: Approaching TW API Quota | `references/bd-approaching-tw-api-quota.md` | TW API quota approaching limit for blob distribution controller |
| BD: Client Library Crashes | `references/bd-client-library-crashes.md` | Blob distribution client library crashes, coredumps in BD namespace |
| BD: Deployment Service Excessive Execute Retries | `references/bd-excessive-execute-retries.md` | Excessive release retries in blob distribution deployment service |
| BD: Deployment Service Health Check Failure | `references/bd-deployment-service-health-check-failure.md` | Deployment service E2E health check failure in RC or prod tier |
| BD: Deployment Service Unexpected Error | `references/bd-deployment-service-unexpected-error.md` | Unexpected or miscellaneous errors in the blob distribution deployment service |
| BD: CPEntity Ensemble Usage Exceeded | `references/bd-cpentity-ensemble-usage-exceeded.md` | CPEntity storage usage exceeded threshold for blob metadata |
| BD: Too Many Create Tenant Failures | `references/bd-too-many-create-tenant-failures.md` | putTenant success rate drop in blob distribution deployment service |
| BD: E2E Latency Too High | `references/bd-e2e-latency-too-high.md` | End-to-end latency too high in blob distribution pipeline |
| BD: Reliable END Message Delivery Failure | `references/bd-reliable-end-message-delivery-failure.md` | Reliable END message delivery failures in blob distribution |
| BD: Retry Attempt / Bypass Pacing Failures | `references/bd-retry-and-bypass-pacing-failures.md` | Retry attempt or bypass pacing custom action failures in blob distribution deployment service |
| BD: Tenant Metadata Resolution Failure | `references/bd-tenant-metadata-resolution-failure.md` | Pacing writer or release tracker cannot resolve tenant metadata for blob distribution |
| BD: Tick Failure Rate Too High | `references/bd-tick-failure-rate-too-high.md` | ICSP controller tick failure rate too high for blob distribution |
| BD: Too Many Patch Tenant Failures | `references/bd-too-many-patch-tenant-failures.md` | patchTenant success rate drop in blob distribution deployment service |
| BD: Too Many Exceptions on Download | `references/bd-too-many-exceptions-on-download.md` | getData/getChunks download exceptions in blob distribution client |
| BD: Too Many Exceptions on Streaming Blob Metadata Write | `references/bd-too-many-exceptions-on-streaming-blob-metadata-write.md` | Streaming blob metadata write exceptions |
| BD: Too Many Exceptions on Transition Complete | `references/bd-too-many-exceptions-on-transition-complete.md` | onTransitionComplete callback exceptions in blob distribution client |
| BD: Too Many Exceptions on Update | `references/bd-too-many-exceptions-on-update.md` | Update stream exceptions in blob distribution client |
| BD: Too Many Subscription Failures | `references/bd-too-many-subscription-failures.md` | Subscription failures in blob distribution client |

### Release Health

| Topic | File | When to Use |
|-------|------|-------------|
| Conveyor health report | `references/conveyor-health-report.md` | Generate weekly conveyor health report, check status of all Hedwig conveyors, MyClaw-triggered reports |

### Reference

| Topic | File | When to Use |
|-------|------|-------------|
| Scuba tables & columns | `references/scuba-tables.md` | Writing Scuba queries, understanding table schemas, column meanings, sampling |
| Peer ODS counters | `references/scuba-peer-counters.md` | ODS counters emitted by PeerCounters (hedwig_download.peer.*), cache hit rate, download success/failure |
| Tracker ODS counters | `references/scuba-tracker-counters.md` | ODS counters emitted by Hedwig Tracker, tracker-level metrics |
| Debugging tools | `references/debugging-tools.md` | Scuba queries, TW commands, profiling |
| Dashboards | `references/dashboards.md` | Links to monitoring dashboards and Scuba tables |

## Post Investigation

After resolving any issue, post findings based on who invokes the skill
- For user initiated skill, post in Hedwig oncall Workplace group https://fb.workplace.com/groups/179830296674125
- For agent initiated skill, post in the Dumbledore agent's training group https://fb.workplace.com/groups/4519087041698082
