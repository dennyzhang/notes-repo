# Debugging Tools

## Table of Contents

- [TW Commands](#tw-commands)
- [Scuba Queries](#scuba-queries)
- [ODS Queries](#ods-queries)
- [Profiling](#profiling)
- [Log Analysis](#log-analysis)
- [Useful Links](#useful-links)

Common commands and Scuba queries for Hedwig oncall debugging.

## TW Commands

### Check Job Status

Use `tw resolve` to see task states (running, pending, failed) and which hosts tasks are on:

```bash
tw resolve tsp_XXX/hedwig/hedwig.download.superpeer.XXX
```

Use `tw diag` to see recent events (state transitions, preemptions, health checks, crashes) for a specific task:

```bash
tw diag tsp_XXX/hedwig/hedwig.download.superpeer.XXX/0 --start-time '2 hours ago'
```

Use `tw changes show-unhealthy` to see which tasks are unhealthy and why:

```bash
tw changes show-unhealthy tsp_XXX/hedwig/hedwig.download.superpeer.XXX
```

### Find Job Handle

```bash
tw search tsp_XXX/hedwig/hedwig.download.superpeer.XXX
```

Searches for job handles matching the pattern. This only returns matching job names — it does not show job state or task details.

### Resize Job (Add Capacity)

> **⚠️ Write operation**: Do not execute this directly. Suggest this command to the user and let them run it after reviewing.

```bash
tw resize tsp_XXX/hedwig/hedwig.download.superpeer.XXX --add-task-count 4
```

Use this to add more tasks when:
- Load is increasing
- Tasks are failing due to capacity issues

### Restart Job

> **⚠️ Write operation**: Do not execute this directly. Suggest this command to the user and let them run it after reviewing.

```bash
tw restart tsp_XXX/hedwig/hedwig.download.superpeer.XXX
```

Use this when:
- Tasks are in bad state
- Need to pick up new configuration

### View Job Logs

```bash
tw logs tsp_XXX/hedwig/hedwig.download.superpeer.XXX
```

## Scuba Queries

> For full Scuba table schemas, column definitions, sampling strategies, and additional diagnostic query patterns, see [scuba-tables.md](scuba-tables.md).

### Streaming Investigator

Primary table for streaming staleness investigations: `hedwig_streaming_investigator`.

Key columns: `Event`, `client_id`, `host_dcprefix`, `publisherId`, `requester_ip`, `requester_tw_job_name`, `source_ip`, `tracker_endpoint`, `stalenessMs`, `channel_id`, `isRoot`.

#### Identifying Peers

Key columns to identify peers (subscribers or publishers):

| Column | Description |
|--------|-------------|
| `requester_tw_job_name` / `source_tw_job_name` | TW job name. Logged for peer events but not tracker events. |
| `requester_tw_task_id` / `source_tw_task_id` | TW task ID. Logged for peer events but not tracker events. |
| `nonce` | Random number assigned at peer startup. If it changes for the same TW job and task, it means the Hedwig peer client or the TW task itself was restarted. Logged for peer events. |
| `requester_ip` / `source_ip` | IP address. Logged for peer events. |
| `requester_port` / `source_port` | Port. Logged for peer events. |
| `publisherId` | Publisher identifier (UUID). Similar to nonce but for publishers. |

When there are two sides of communication, columns are prefixed with `requester_` (the peer fetching data) and `source_` (the peer providing data).

#### Publisher-Side Lookup: MAST Job → TW Job → client_id → model_id

When the only starting point is a publisher-side MAST job ID (e.g., a model trainer reported a streaming issue), use `hedwig_streaming_investigator` to derive both the Hedwig `client_id` and the `model_id`. Note that the MAST job name is **not** the same as the TW job name — a MAST job spawns one or more TW tasks whose names follow the pattern `<MAST_JOB_NAME>.<TASK_GROUP>.<TASK_INDEX>.<RANDOM>`.

##### For Humans

Open the MAST job page in MLHub (e.g., `https://www.internalfb.com/mlhub/pipelines/runs/mast/<MAST_JOB_ID>`) and read off the backing TW job name(s) under the task groups section. Then proceed to the Scuba step below.

##### For Agents

The MLHub page is a JS entrypoint and **cannot** be loaded via `meta url.load`. Use the `mast` CLI to derive the TW job filter directly from the MAST job ID:

```bash
# 1. Discover task groups (typically "trainer" for ML training jobs)
mast get-job-definition <MAST_JOB_ID> --output json | jq -r '.hpcTaskGroups[].name'

# 2. (Optional) Confirm the exact TW task name format for a task group
mast get-tw-job-spec --task-group-name <TASK_GROUP> <MAST_JOB_ID> --output json | jq -r '.twJobSpecs.id.name'
```

The TW job filter to use in Scuba is `<MAST_JOB_NAME>.<TASK_GROUP>` (e.g., `mvai-training-online-2125053311.trainer`). If `mast` is not installed, run `devfeature install mast_cli` once.

**When the agent must ask the user**: if no MAST job ID is provided (only a screenshot, a model owner unixname, or a vague "training job is broken"), stop and ask the user for the MAST job ID before proceeding — it cannot be guessed.

##### Scuba: TW Job → client_id → model_id

Filter publisher events in `hedwig_streaming_investigator` by `tw_job`. The `client_id` will be `push:ML_REALTIME_PUBLISHER_SPARSE` (sparse models) or `push:ML_REALTIME_PUBLISHER_EBD` (EBD models). Read `model_id` from the `file` column: publisher rows report the channel as `model_<MODEL_ID>_sparse` (sparse) or `model_<MODEL_ID>_res` (EBD) — strip the prefix and suffix to get the numeric `model_id`.

```sql
SELECT client_id, file, COUNT(*) AS cnt
FROM hedwig_streaming_investigator
WHERE time >= now() - 3600
  AND tw_job LIKE '%<MAST_JOB_NAME>.<TASK_GROUP>%'
  AND Event = 'peer_streaming_msg_pub'
GROUP BY client_id, file
ORDER BY cnt DESC
LIMIT 20
```

Once you have `model_id`, downstream investigations (see [streaming-success-rate.md](streaming-success-rate.md)) can proceed.

#### Event Types

The `Event` column contains the following values, grouped by category:

**Staleness Events** (reported by tracker during staleness checks, see [Streaming Runbook - Staleness](https://www.internalfb.com/wiki/Hedwig/Runbook/Streaming/#staleness)):

| Event | Description |
|-------|-------------|
| `staleness_detected` | Tracker's known publisher position is ahead of subscriber and subscriber hasn't been getting messages (including KeepAlive) for too long. **Alarms are set up for this.** |
| `staleness_missing_publisher` | Subscriber is not aware about a certain publisher (received messages from that publisher long time ago or never) and tracker knows it is a valid healthy publisher for that channel. **Alarms are set up for this.** |
| `staleness_no_publisher` | Subscriber reports status for a publisher unknown to the tracker. Expected if publisher is fresh and hasn't sent heartbeat to the tracker yet, or publisher is old and already removed. |

Key columns for staleness events:

| Column | Description |
|--------|-------------|
| `isRoot` | If set to `1`, staleness is between publishers and root subscribers — this affects all downstream subscribers. If root is not stale, staleness is between downstream subscribers. |
| `file` | File/channel identifier. For model streaming, this encodes the model series ID: `model_<MODEL_ID>_sparse` (sparse) or `model_<MODEL_ID>_res` (EBD). Use this to derive `model_id` from a publisher-side investigation — see "Publisher-Side Lookup" above. |
| `publisherId` | When grouped by publisher, useful to determine whether one publisher is affected or many. |
| `publisher_last_publish_time` | How long ago publisher sent messages. |
| `publisher_last_seqno` | Last sequence number published by the publisher. |
| `peer_last_publish_time` | Last message the subscriber received. |
| `stalenessMs` | How long the staleness has been going on. |
| `publisherTimeSinceStreamCreated` | How long ago publisher joined this channel — may need time to catch up. |
| `subscriberTimeSinceStreamCreated` | How long ago subscriber joined this channel — may need time to catch up. |
| `publisher_region` | Where publisher is located, useful in case there's a problem between regions. |

**Peer Streaming Events** (core streaming data plane, see [Streaming Runbook - Root Nodes](https://www.internalfb.com/wiki/Hedwig/Runbook/Streaming/#root-nodes)):

| Event | Description |
|-------|-------------|
| `peer_streaming_subscribe_start` | New subscribe attempt by a peer. |
| `peer_streaming_subscribe_end` | End of subscribe. Useful to check for root failovers. Key columns: `success/exception`, `isRoot`. |
| `peer_streaming_from_endpoint_start` | Start of stream from a publisher endpoint (root nodes). |
| `peer_streaming_from_endpoint_end` | End of stream from a publisher endpoint (root nodes). Key column: `exception`. |
| `peer_streaming_root_tracker_update` | Tracker periodically sends list of current publishers to root. Useful to check tracker's view of publishers (`trackerEndpoints`) vs what root is already fetching from (`currentEndpoints`, `addedEndpoints`). |
| `peer_streaming_root_tracker_update_end` | End of root tracker update processing. |
| `peer_streaming_msg_recv` | Peer received a streaming message. High volume — uses separate sample rate config. |
| `peer_streaming_msg_send` | Peer sent a streaming message to a downstream peer. |
| `peer_streaming_msg_recv_by_client` | Message received by the client application. Used to detect when messages are lost on the peer host between the Hedwig library and the client application. |
| `peer_streaming_msg_pub` | Peer published a streaming message. High volume — uses separate sample rate config. |
| `peer_streaming_provide_start` | Publisher starting to provide a stream for a channel. |
| `peer_streaming_provide_end` | End of publisher call to the tracker to provide the stream. This is not the end of the stream itself. |
| `peer_streaming_provide_end_of_stream` | Publisher sent all messages for the channel and stops being a publisher on that channel (can re-publish in future). |
| `peer_streaming_persisted_msg_recv` | Replayed message received from persistent storage (Axon). Similar to `peer_streaming_msg_recv` but for replay. |
| `peer_streaming_historical_cache_miss` | Historical message cache miss when a reconnecting subscriber requests a seqNo not found in cache. |

**Peer Streaming Recovery (Replay) Events:**

| Event | Description |
|-------|-------------|
| `peer_streaming_recovery_start` | Start of streaming replay/recovery operation from persistent storage. |
| `peer_streaming_recovery_end` | End of streaming replay/recovery operation. |
| `peer_streaming_recovery_init_failure` | Failure during replay/recovery initialization. |
| `peer_fetch_persisted_msg_start` | Start of fetching persisted messages from external storage (Axon/Manifold). |
| `peer_fetch_persisted_msg_end` | End of fetching persisted messages. Key column: `success`. Contains start/end replay time for requested range duration. |

**Peer Lifecycle Events:**

| Event | Description |
|-------|-------------|
| `peer_registration` | Peer registered with the tracker. |
| `peer_deregistration` | Peer disconnected from a given tracker, either due to switching to stick to another tracker instance or peer shutting down. |
| `peer_service_init` | Peer service initialized (startup). |
| `peer_service_destroy` | Peer service destroyed (shutdown). |

**Peer Connection & Fetch Events:**

| Event | Description |
|-------|-------------|
| `peer_chunk_fetch_start` | Start of chunk fetch from source peer. Also includes a `getSourceAndUpdateStatus` request to tracker to get the endpoint of a source peer to fetch from. |
| `peer_chunk_fetch_end` | End of chunk fetch from source peer. For non-root peers, useful to check if peer has a valid source or is reconnecting. |
| `peer_get_chunk_start` | Another peer starts fetching from this logging peer. |
| `peer_get_chunk_end` | Another peer finished fetching from this logging peer. |
| `peer_get_stream_from_peer_start` | Start of getting stream from another peer. |
| `peer_get_stream_from_peer_end` | End of getting stream from another peer. |
| `peer_fetch_from_chunk_services_start` | Logging peer starts fetching from a source peer. |
| `peer_tracker_subscribe_response` | Peer logging tracker subscribe response. Useful to check for root retries. Key columns: `success/exception`, `isRoot`. |
| `peer_reportStreamingStalenessInformation` | Peer reporting staleness information to tracker. |
| `peer_sendHeartbeat` | Peer sending heartbeat to tracker. |
| `peer_buffer_stats_reported` | Peer buffer statistics reported. |
| `peer_max_sending_rate_update` | Peer maximum sending rate updated. |
| `peer_flow_control_fallback` | Peer fell back to flow control mode. |

**Tracker Events:**

| Event | Description |
|-------|-------------|
| `tracker_subscribe_response` | Tracker responding to a subscribe request. Key columns: `isRoot`, `publishers`. |
| `tracker_status_update` | Logged on `getSourceAndUpdateStatus` when requester gets another source. Also logs `requester_penalty_score` and `source_penalty_score`. |
| `tracker_root_disconnect` | Root node disconnected from tracker. Useful to check root failover rate. |
| `tracker_get_source_and_update_status_response` | Tracker response to getSourceAndUpdateStatus request. |
| `tracker_update_chunks_cached_delta` | Incremental update to tracker's cached chunk metadata. |
| `tracker_update_chunks_cached_snapshot` | Full snapshot update to tracker's cached chunk metadata. |
| `tracker_download_complete` | Download completed as tracked by the tracker. For streaming, a download is one subscribe attempt that can involve multiple `getSourceAndUpdateStatus` attempts. |
| `tracker_timeout_download` | Download timed out as tracked by the tracker. |
| `tracker_publish` | Publisher registered/heartbeated to tracker. |

**Flow Control Events:**

| Event | Description |
|-------|-------------|
| `flow_tracker_calculate_max_publishing_rate` | Flow tracker calculated maximum publishing rate. |
| `flow_tracker_consumption_rate_deciding_peers` | Flow tracker identifying peers that determine consumption rate. |
| `flow_tracker_p2p_buffer_update` | Peer-to-peer buffer update from flow tracker. |
| `flow_tracker_consumption_buffer_update` | Consumption buffer update from flow tracker. |

#### Common Queries

```bash
# Check staleness events for a client in a region
scuba -e "SELECT requester_tw_job_name, count(*) as cnt FROM hedwig_streaming_investigator WHERE time >= now()-3600 AND Event LIKE '%staleness_detected%' AND client_id LIKE '%ADINDEXER%' AND host_dcprefix = 'frc' GROUP BY requester_tw_job_name ORDER BY cnt DESC LIMIT 20"

# Check impacted publishers
scuba -e "SELECT publisherId, count(*) as cnt FROM hedwig_streaming_investigator WHERE time >= now()-3600 AND Event LIKE '%staleness_detected%' AND client_id LIKE '%ADINDEXER%' AND host_dcprefix = 'frc' GROUP BY publisherId ORDER BY cnt DESC LIMIT 20"

# Check impacted root nodes
scuba -e "SELECT requester_ip, isRoot, count(*) as cnt FROM hedwig_streaming_investigator WHERE time >= now()-3600 AND Event LIKE '%staleness_detected%' AND client_id LIKE '%ADINDEXER%' AND host_dcprefix = 'frc' GROUP BY requester_ip, isRoot ORDER BY cnt DESC LIMIT 20"

# Check tracker metadata inconsistencies (different trackers reporting different events)
scuba -e "SELECT tracker_endpoint, Event, count(*) as cnt FROM hedwig_streaming_investigator WHERE time >= now()-3600 AND Event LIKE '%staleness_%' AND client_id LIKE '%ADINDEXER%' AND host_dcprefix = 'frc' GROUP BY tracker_endpoint, Event ORDER BY cnt DESC LIMIT 20"

# Identify which tracker task has staleness (for targeted restart)
scuba -e "SELECT tracker_endpoint, count(*) as cnt FROM hedwig_streaming_investigator WHERE time >= now()-3600 AND Event LIKE '%staleness_detected%' AND client_id LIKE '%ADINDEXER%' GROUP BY tracker_endpoint ORDER BY cnt DESC LIMIT 10"
```

### Download Investigator

Main table for investigating download issues:
- Base URL: https://fburl.com/scuba/download_investigator/

Useful queries:
- Identify high-traffic clients: https://fburl.com/scuba/download_investigator/wengex5r

### Coredumper

For crash investigation:
- Base URL: https://fburl.com/scuba/coredumper/

Filter by:
- `job_name` contains "hedwig"
- Time range around incident

### Download Client Stats

Client-side download metrics:
- Base URL: https://fburl.com/scuba/download_client_stats/

## ODS Queries

Use the `ods-counter-analyzer` skill to check ODS counters. The staleness alert fires on `hedwig.download.tracker.streaming.<REGION>@#$staleness_detected_peer_percent`.

Staleness rate reported by hedwig streaming trackers across all regions: https://fburl.com/canvas/h1y501p2

```bash
# Check stale subscription rate for a region
ods read "hedwig.download.tracker.streaming.frc" --key "staleness_detected_peer_percent" --time-range "2h"

# Check root failover rate
ods read "hedwig.download.tracker.streaming.frc" --key "root_disconnect" --time-range "2h"
```

## Profiling

### Strobelight (CPU Profiling)

Use strobelight when:
- CPU usage is unexpectedly high
- Need to identify hot code paths

### Memory Profiling

Check TW dashboard for:
- Memory usage trends
- Memory spikes correlating with issues

## Log Analysis

### Finding Inflow Count

Look for "# in progress" in superpeer logs.

Example log pattern:
```
[INFO] Current state: # in progress: 35, # completed: 100
```

If inflow count > 30, superpeers are at risk of OOM.

## Useful Links

- Cubism (metrics): https://fburl.com/cubism/w2ankhcd
- TW Dashboard: https://www.internalfb.com/intern/tupperware/
