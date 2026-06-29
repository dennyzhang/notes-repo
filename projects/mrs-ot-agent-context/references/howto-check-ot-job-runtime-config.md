# HOWTO — Check an OT job's runtime trainer config (e.g. `scribe_reader_catchup_sec`)

The authoritative value of any OT-job config field is in the **runtime trainer config**
(what the job actually ran), not the configerator `.cconf` (which can be overridden at
job-resolution time). Fetch it with the `chug` CLI; read any field with `jq`.

## Method

```bash
JOB=mvai-training-online-<MODEL_ENTITY_ID>
# 1. MAST job version
meta ai.mast-job metadata --name="$JOB" -o json | jq -r .version
# 2. fetch runtime trainer config (install chug once if missing: devfeature install chug --persist)
chug ot-utils fetch-mvai-trainer-config --job-name "$JOB" --job-version <VERSION> \
  --output /tmp/cfg.json
# 3. read the field(s) — e.g. scribe lookback:
jq '.trainer_config.config.data_source_config
    | {scribe_reader_catchup_sec, scribe_reader_catchup_sec_compute_mode}' /tmp/cfg.json
```
The config JSON is 10K+ lines — never load it whole; `jq` the specific key. Any field
lives under `.trainer_config` (Checks 1/2 of the `ot-reliability-health-check` skill use
`.trainer_config.config.data_source_config`).

**`chug` 3-tier resolution** (it picks the first that works): (1) AIX run metadata paste
[primary, no checkpoint needed], (2) MAST `applicationMetadata.mvai_trainer_config`,
(3) checkpoint `serialized_job`. The log line tells you which tier resolved it — all
three reflect what the job actually ran.

## `scribe_reader_catchup_sec` — interpretation

- It's the **scribe lookback window (seconds)** in `DataSourceConfig`: on restart the job
  won't consume data with example-age older than this. e.g. `300` → only data ≤5 min old.
- **Unset / `null` (default)** → no configured lookback; on restart the job consumes the
  **most-recent scribe data only** (no historical catch-up). This is EXPECTED, not a bug
  (Paul Lu / Tai Guo, W1352798703481539; the unset default may be ~2h server-side, TBC).
- **Dynamic resolution** (`job_resolver.py::_resolve_scribe_data_source`): with
  `scribe_reader_catchup_sec_compute_mode = always_try` (the default) the runtime value =
  `min(configured_value, now − last_trained_timestamp)`, so the runtime number is often
  **below** the configured cap. `no_op` mode uses the configured value as-is.
- Health-check verdict (`ot-reliability-health-check` skill, Check 1): `>7200` → FAIL;
  `always_try`(or missing) & `≤7200` → PASS; `no_op` & `==7200` → PASS; `no_op` & `≠7200`
  → FAIL. (`null` = unset = default behavior, not a FAIL.)
- The `scribe_reader_catchup_sec=0` trap: a value of 0 disables the holdout delay → the job
  reads real-time data instead of the expected ~5-min holdout (W1218910203488316 / P55;
  the `latency_injection_ms` propagation fix is D102533010).

## Worked example (verified 2026-06-25)

Job `mvai-training-online-883407104` (v17): both fields **`null`** (resolved via the
checkpoint `serialized_job` tier) → no lookback configured; consumes most-recent scribe
data on restart. Expected default.

Sources: `claude-templates/.../skills/ot-reliability-health-check/SKILL.md` (QC Step 1a +
Check 1); fbcode `minimal_viable_ai/core/trainer/job_resolver.py`; W1352798703481539,
W1218910203488316.
