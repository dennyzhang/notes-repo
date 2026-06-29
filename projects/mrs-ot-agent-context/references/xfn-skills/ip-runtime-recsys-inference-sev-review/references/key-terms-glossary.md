# Key Terms Glossary

Load this reference after building the timeline (Step 2) to identify domain-specific technical terms that appear in the SEV comments. Include a "Key Terms" table in the Supporting Analysis section with SEV-specific explanations.

## Table of Contents

- [Term Identification Rule](#term-identification-rule)
- [Standard Glossary](#standard-glossary)
- [Generating the Key Terms Section](#generating-the-key-terms-section)

## Term Identification Rule

After building the timeline (Step 2), scan all SEV comments and investigation docs for terms from the glossary below. Include explanations for any term that:
- Appears in the root cause or mitigation description
- Is central to understanding the SEV's impact
- Would be unclear to a ranking engineer or EM who doesn't work on inference infra

Do NOT include every term -- only those relevant to THIS specific SEV. Tailor each explanation to show how the term relates to the incident.

## Standard Glossary

| Term | Definition | Context |
|------|-----------|---------|
| **In-place snapshot transition** | A method of updating a model's weights without taking it offline. The new snapshot is loaded into the same container as the old one, and serving switches over atomically. Faster than out-of-place (~1hr vs ~3hr) but more complex -- the old and new model state coexist briefly during the transition. | When "in-place is disabled," the model falls back to out-of-place transitions (fresh container), which is slower but safer. |
| **Out-of-place snapshot transition** | Loading a new model snapshot into a completely new container, then swapping traffic. Slower (~3hrs) but avoids state corruption risks since there's no shared state between old and new. | Used as a fallback when in-place transitions are broken. Causes increased model staleness. |
| **Model staleness** | How old the model's current weights are compared to the latest available snapshot. Fresh models have better recommendation quality because they reflect recent user behavior and content. | Staleness >5hrs is typically SEV-worthy. Normal is ~1hr with in-place, ~3hrs with out-of-place. |
| **Binary (Sigrid Predictor binary)** | The compiled software package running on GPU machines that serves model inference. Contains all code for model loading, warmup, snapshot transitions, and GPU operations. Versioned (e.g., v1108, v1139). | "Binary regression" = a new version introduced a bug. "Binary revert" = rolling back to a previous version. |
| **Pin a binary** | Manually locking a model's serving tasks to use a specific binary version, overriding automatic updates. "Pinning to v1093" means forcing the model to stay on that version. "Unpinning" re-enables automatic updates. | Fastest mitigation for binary regressions (minutes). No code change required. |
| **Binary revert** | Rolling back the entire fleet (or specific models) from a bad binary version to the last known good version. Different from pinning: a revert changes the default version for all models, while pinning only affects specific models. | Fleet-wide reverts are rare and require oncall approval due to blast radius. |
| **Warmup** | After loading a model snapshot, running a set of synthetic or cached inference requests to "warm up" GPU caches, JIT compilation, and memory allocations before serving live traffic. Without warmup, the first real requests hit cold caches and may timeout or error. | Normal warmup: ~100-200ms per operator. If warmup takes >5s, something is wrong (e.g., ROCm debug agent overhead). |
| **ZCH (Zero Collision Hashing)** | A hash table technique for embedding lookups in recommendation models. Maps billions of item IDs to embedding vector indices with zero hash collisions. Maintains a free slot queue for new items and an eviction policy for stale ones. | ZCH state is per-predictor-instance. If two ZCH instances diverge (serving vs streaming using different ones), massive cache misses occur. |
| **ZCH cache miss** | When a serving request looks up an item ID in the ZCH hash table but the item doesn't exist in that instance. The model must use a fallback embedding, degrading recommendation quality. Normal miss rate is low; >10% is a SEV signal. | Often caused by serving and streaming using different ZCH instances after a bad in-place transition. |
| **NE (Normalized Entropy)** | A standard metric for recommendation model prediction quality. Lower NE = better predictions. An "NE spike" means the model suddenly got worse at predicting user engagement. | NE spikes usually indicate model quality issues, making infrastructure-caused NE spikes (like S619839) hard to diagnose -- oncalls naturally investigate model/feature changes first. |
| **KFS throughput estimation** | The system that estimates how much traffic each model task can handle, based on measured inference performance. SRM and Solver use these estimates to allocate tasks and route traffic. | If a corrupted model produces incorrect output, KFS may overestimate throughput -> fewer tasks allocated -> overload -> errors. |
| **Demand multiplier** | A scaling factor applied to a model's capacity allocation. Multiplier of 1.0 = baseline. Increasing to 1.2 means allocating 20% more capacity. Used as a temporary mitigation during capacity crunches. | Escalation pattern: 1.0 -> 1.15 -> 1.2 -> 1.3. If you need >1.3, capacity is probably masking another issue. |
| **Blob distribution** | The system that distributes model snapshot files (blobs) from storage to GPU machines. If blob distribution is stuck, models can't load new snapshots regardless of transition type. | Check blob distribution status in IPNext model lifecycle dashboard before investigating transition-specific issues. |
| **Delta updates / streaming** | Incremental updates to model embeddings between full snapshot transitions. Instead of reloading the entire model, only changed embeddings are streamed in. Uses the ZCH operator's update_embedding_cache method. | Streaming updates go to the container's module (ZCH-B in S619839), while serving may use the predictors_ cache (ZCH-A) -- this divergence caused the cache miss SEVs. |
| **AOTI (Ahead-Of-Time Inference)** | A model compilation mode where PyTorch models are compiled to optimized native code before deployment, rather than using JIT interpretation. Has different code paths for model loading and in-place transitions. | Many SEVs involve bugs at the AOTI/non-AOTI boundary -- code changes intended for AOTI models accidentally affecting non-AOTI paths. |
| **Multi-forward model** | A model with multiple inference entry points (e.g., merge.forward, remote_request_only.forward). Each entry point may have its own predictor with different capabilities. | If one entry point's predictor is lost during a bad transition (e.g., remote_request_only), that specific inference path fails while others appear to work -- making diagnosis harder. |
| **Vanguard test** | An automated serving test framework that runs model inference in a controlled environment to validate binary changes, model compatibility, and performance. Can test specific binary versions with specific model configurations. | "Vanguard confirmed the fix" = the test showed the fix resolves the issue in a controlled environment before production deployment. |
| **ROCm debug agent** | A diagnostic tool for AMD GPUs (librocm-debug-agent.so.2) that intercepts HSA (Heterogeneous System Architecture) calls to capture GPU debugging information. When enabled, adds significant CPU-side overhead to every GPU operation. | The debug agent is useful for diagnosing GPU crashes but should NOT be enabled in production serving paths. In S622516, it caused 80x warmup regression. Controlled via JK: ipnext/system_perf/amd:enable_rocm_debug_agent. |
| **Tenant / Tenant pipeline** | A model deployment configuration in IPNext that defines which binary version, model snapshot, hardware type, and capacity settings a model uses. "Tenant revert" = rolling back a model's deployment configuration. | Each model has a tenant ID (e.g., m2138521890). Tenant pipeline changes are tracked at fburl.com/services/{hash}. |
| **TDS (Threads-Driven Sessions)** | A topline engagement metric for Threads measuring sessions that are driven by Threads content. Used to assess model quality impact in holdout experiments. | >1% TDS regression is SEV2-worthy (as seen in S622516). |
| **FSR (Feed Success Rate)** | A metric measuring the success rate of feed item retrieval and rendering. Drops in FSR indicate that content isn't being successfully served to users. | FSR drops can be caused by inference errors (model can't produce predictions) or retrieval failures. |

## Generating the Key Terms Section

Format for the report's Supporting Analysis:

**Key Terms:**

| Term | What It Means in This SEV |
|------|--------------------------|
| {term} | {2-3 sentence explanation tailored to this specific SEV, showing how the term relates to the incident} |

Example (from S622516):

| Term | What It Means in This SEV |
|------|--------------------------|
| **In-place snapshot transition** | The mechanism that was failing -- models couldn't load new snapshots because warmup was taking too long during the in-place swap. Disabling it was the first mitigation but caused 3hr staleness. |
| **Warmup** | The step that was regressed 50x (200ms -> 10s) due to the bad binary. This blocked in-place transitions from completing during peak traffic. |
| **ROCm debug agent** | The root cause component in the bad binary -- this AMD GPU diagnostic tool was intercepting HSA calls and adding massive CPU overhead to every warmup operation. |
| **Binary pin/revert** | The definitive fix -- reverting from v1167 to v1139 removed the debug agent from the serving path. Should have been tried on Day 1 instead of Day 8. |
| **Demand multiplier** | Used as a temporary mitigation (escalated from 1.0 to 1.3 over several days), but did not resolve the underlying snapshot loading issue -- a classic case of capacity masking the real problem. |
