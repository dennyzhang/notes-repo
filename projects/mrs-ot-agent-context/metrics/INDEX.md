# metrics/ — Prod Health Observability Index

Top-level reference for OT prod health: user journeys, key metrics, canonical queries, and detection patterns.
Four files, each owns one concern. No overlap.

| File | Owns | Updated by |
|---|---|---|
| [user-journeys.md](user-journeys.md) | What matters to users, ranked by incident evidence | Bot after each incident (discovery protocol) |
| [slo-recovery-metrics.md](slo-recovery-metrics.md) | Key metrics per component with thresholds, for health checks and SEV recovery | Bot when thresholds prove wrong or new metrics are discovered |
| [queries.md](queries.md) | Exact queries (Scuba SQL, CLI, MCP tools, SLICK configs) for each metric | Bot when a query fails or a better one is found |
| [detection-patterns.md](detection-patterns.md) | Temporal anomaly patterns (metric + duration + context = detection) | Bot when it finds an incident that thresholds alone couldn't catch |

**Cross-references:**
- `user-journeys.md` UJ-NNN → `slo-recovery-metrics.md` KM-XX (which metrics express this journey)
- `slo-recovery-metrics.md` KM-XX → `queries.md` Q-NNN (how to check this metric)
- Triage uses all three: anchor verdict to UJ → check KM thresholds → run Q queries

**Model family routing:**
Queries differ by model family. Before running any query, resolve the family:
1. If model_type contains `hstu`, `i2i`, `umia` → retrieval family (use Q-011, not Q-010)
2. If model_type contains `mtml` → MTML ranking family (use Q-010)
3. `esr` and `lsr` alone are NOT sufficient — ESR models can be HSTU-based (retrieval) or MTML-based. Check for `hstu`/`i2i` first.
4. If unsure → run both and compare

**Bot-executable vs dashboard-only queries:**
Some queries (Q-001, Q-002, Q-020) are dashboard links requiring auth — the bot cannot run them programmatically. These are marked `type: dashboard`. When the bot needs the metric, it should note "check dashboard manually" rather than attempt to query.
