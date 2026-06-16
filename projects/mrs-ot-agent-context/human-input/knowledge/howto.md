# OT Operational How-Tos

Reusable operational knowledge harvested from mrs.ot HOWTO posts/threads. Distinct
from `known-patterns.md` (failure patterns / P-rows): these are "how do I do X on an
OT job" answers that recur. The postmortem digest classifies HOWTO posts as
"no P-row → skip" — so capture them HERE instead of losing them.

---

## Add / change a C++ gflag on an OT job (e.g. `bulk_type=tls-socket`)

Source: mrs.ot W1336148551813221 (Sanket Karnik, 2026-05-27) → Li Lu answer
[P2353215480](https://www.internalfb.com/intern/paste/P2353215480). Captured 2026-06-04.

- **You CANNOT add a gflag to an already-RUNNING MAST job.** Must kill + relaunch
  with the new flag/binary.
- **`fire` CLI has no `--gflag` option**; there is no established MVAI/fire pattern
  for passing arbitrary C++ gflags. Three options, recommended first:
  1. **Rebuild the app-layer from latest (recommended)** — many gflags' defaults
     change via landed diffs. E.g. D105728596 (landed 2026-05-23) flipped the
     `bulk_type` default `socket` → `socket,tls-socket`; any app-layer built after
     2026-05-23 already has tls-socket on, no override needed. Check first:
     `fbpkg info <app-layer-pkg> | grep Created`.
  2. **Programmatic via `premain_init`** in the launcher (code change + new app-layer):
     `from minimal_viable_ai.utils.premain_init import premain_init` then
     `premain_init(["--bulk_type=tls-socket"])`.
  3. **Env-var convention** on the fire command (standard gflags convention, but
     UNTESTED for a given flag): `fire [opts] --env GFLAGS_<flag>=<val> -- [app args]`.
- `bulk_type` valid values: `socket, tls-socket, rdma, gpu-rdma, shmem, block`
  (comma-combos allowed). Defined in `fbcode/thrift_fb/bulk_transport/BulkTransportGFlags.cpp`.

> NOTE: the ot-post-postmortem digest reduced this to "workaround = --env flag" —
> that's the *untested option 3*, not the recommended answer (rebuild-from-latest),
> and it omitted the "can't change a running job" constraint. HOWTO posts need the
> full answer captured here, not a lossy one-line P-row-style summary.
