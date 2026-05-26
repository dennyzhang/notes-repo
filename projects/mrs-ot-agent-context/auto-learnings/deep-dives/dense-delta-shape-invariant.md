# Dense Delta Shape Invariant

Source: 2026-04-24 investigation of m2128214413 (IG Threads retrieval QE model).
General pattern that recurs across OT models whose weight shape is derived from mutable config.

## The Core Invariant

**In-place dense delta update requires the delta's weight tensor shape to match the serving anchor's weight tensor shape EXACTLY.** Applies to both `PACED` and `STREAMING` dense delta modes.

In-place = serving process overwrites numbers in the existing weight tensor without re-allocating memory. No mechanism to grow, shrink, or reshape mid-flight. Shape mismatch → "convergence error" or "size mismatch" → snapshot transition aborts.

## The Failure Pattern

| Step | What happens |
|---|---|
| 1 | Full snapshot built at T0 with feature list A → `input_dim = 15,424` → LayerNorm with 15,424 weights. Promoted to serving. |
| 2 | ML engineer changes feature list: adds features or grows embedding dims. Trainer rebuilds with feature list B → `input_dim = 33,728`. |
| 3 | Trainer emits dense delta with 33,728 LayerNorm elements. |
| 4 | Serving tries to apply 33,728-element delta onto 15,424-element anchor. **Shape mismatch → in-place update fails → snapshot transition aborts.** |

**The trainer is healthy throughout.** The bug manifests only at serve time on the new snapshot transition.

## Why STREAMING Doesn't Fix This

Both PACED and STREAMING assume a stable-shape anchor and apply in-place. Switching to STREAMING gives the SAME error, just faster. Not a mitigation.

## Mitigation Hierarchy

| Priority | Mitigation | Catches |
|---|---|---|
| P0 tactical | **Re-promote full snapshot** from current trainer so `input_dim` matches again | Current break only |
| P1 engineering | **Trainer-side drift check at model init**: assert `trainer.input_dim == anchor.input_dim` | All future recurrences |
| P2 architectural | **Move LayerNorm AFTER first Linear** so shape ties to `output_dim` (fixed) instead of `input_dim` (feature-dependent) | Entire bug class |
| P3 workflow | **Gate feature-list changes behind snapshot re-promotion** | Humans forget |

## Known Landmines (shape-dependent weights)

| Module pattern | Shape depends on |
|---|---|
| `nn.LayerNorm([input_dim])` as first layer of user MLP | Sum of user-feature embedding dims |
| `nn.Linear(in_features=X)` where X is computed from features | Concatenated feature dim |
| Embedding tables with vocab_size tied to hash-bucket count | Hash bucket count config |
| Feature-cross interaction layers | Number of features in cross |

**Audit heuristic:** grep model tree for any `nn.Module` whose `__init__` kwargs derive from `input_config_adaptor` or feature-config objects. Those modules are candidates.

## Triage Checklist (when you see "convergence error" or "size mismatch" on snapshot transition)

1. Check if model recently changed feature config (diff search on model's config provider)
2. Compare `input_dim` in latest trainer vs anchor snapshot metadata
3. If mismatch confirmed → P0 mitigation: re-promote full snapshot
4. File follow-up for P1 drift check in trainer init
