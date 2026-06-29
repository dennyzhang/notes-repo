# Inplace Update Test Flags Reference

## Core Test Flags

These are the primary flags for locally reproducing model freshness scenarios. Set `enable_inplace_snapshot_transition=true` as the master switch, then configure the test scenario with the flags below.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `inplace_update_test_mode` | int32 | `0` | Master test switch. `0` = off (normal serving); `1` = test once then exit; `2`+ = continuous testing while serving |
| `inplace_update_test_full_snapshot_id` | int32 | `-1` | Single full snapshot target. Each test cycle toggles between initial and target (A<->B). `<0` = disabled; `>=0` = transition to this snapshot after initial load |
| `inplace_update_test_full_snapshot_ids` | string | `""` | Comma-separated snapshot IDs for sequential rotation (A->B->C->A...). Takes precedence over the single-ID flag |
| `inplace_update_test_delta_snapshot_id` | int32 | `-1` | Target delta snapshot ID. Used with `..._delta_update_manifold_paths` to test specific delta behavior. If not set, uses initial load or full snapshot test ID |
| `inplace_update_test_delta_update_manifold_paths` | string | `""` | Comma-separated Manifold paths to manually inject delta weight files |
| `inplace_update_test_enable_streaming` | bool | `false` | Also initialize the streaming channel in the test path (requires `test_mode` 1 or 2) |
| `force_read_delta_from_manifold` | bool | `false` | Force delta download from Manifold. Set `true` for local delta testing. Defined in `aiplatform/gmpp/streaming/experimental/StreamingUpdateReader.cpp` |
| `inplace_update_interval_between_consecutive_full_snapshots_in_sec` | int32 | `300` | Extra wait seconds between consecutive transitions (only for `test_mode=2`) |

## Common Scenarios

### Full Snapshot Transition (Single)

```
--enable_inplace_snapshot_transition
--inplace_update_test_mode=1
--inplace_update_test_full_snapshot_id=<TARGET_SNAPSHOT_ID>
```

### Continuous Full Snapshot Transition (With Serving Traffic)

```
--enable_inplace_snapshot_transition
--inplace_update_test_mode=2
--inplace_update_test_full_snapshot_id=<TARGET_SNAPSHOT_ID>
```

### Sequential Multi-Snapshot Rotation

```
--enable_inplace_snapshot_transition
--inplace_update_test_mode=2
--inplace_update_test_full_snapshot_ids=<SNAP_A>,<SNAP_B>,<SNAP_C>
--inplace_update_interval_between_consecutive_full_snapshots_in_sec=300
```

### Streaming + Inplace

```
--enable_inplace_snapshot_transition
--inplace_update_test_mode=1
--inplace_update_test_full_snapshot_id=<TARGET_SNAPSHOT_ID>
--inplace_update_test_enable_streaming=true
```

### Delta Update Test (Manual Manifold Paths)

```
--enable_inplace_snapshot_transition
--inplace_update_test_mode=1
--inplace_update_test_delta_snapshot_id=<DELTA_SNAPSHOT_ID>
--inplace_update_test_delta_update_manifold_paths=<MANIFOLD_PATH>
--force_read_delta_from_manifold=true
```

## Additional Flags

If the scenario requires flags beyond the core set above (e.g., verbose logging, streaming rewind, blob distribution, ZCH-specific behavior), search the full flag inventory:

- `fbcode/sigrid/lib/flags/InplaceModelUpdateFlags.cpp` — all inplace/streaming flags
- `fbcode/sigrid/lib/flags/InplaceModelUpdateFlags.h` — declarations

Commonly useful extras:
- `enable_inplace_verbose_debug_logging=true` — more detailed inplace/delta logs
- `streaming_message_dump_path=/tmp/streaming.log` — dump streaming messages to file for inspection

## Source Locations

- Flag definitions: `fbcode/sigrid/lib/flags/InplaceModelUpdateFlags.cpp`
- `force_read_delta_from_manifold`: `fbcode/aiplatform/gmpp/streaming/experimental/StreamingUpdateReader.cpp`
- IPR CLI inplace constants: `fbcode/ip_runtime/scripts/iprcli/utils/constants.py`
- GPU launch script env vars: `fbcode/hpc/inference/scripts/common/launch_gpu_sigrid_predictor.sh`
