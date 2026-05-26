# TMS Registration State × Command Matrix

Source: Paul Lu's integration testing spec (2026-04-15).
Cross-reference: `restart-mechanism-analysis.md` (4-layer restart stack — Layer 4 is TMS).

## TMS Registration States

Every model in TMS exists in exactly one state. State determines auto-restart and reconcile behavior.

| State | TMS Reconcile | Auto-Restart |
|---|---|---|
| **Not Registered** | No | No |
| **Recurring Only** (no `online_launch_config`) | Yes (recurring) | — |
| **ADHOC + ONLINE_READY** | No | No |
| **ADHOC + PAUSED** | Actively kills job | No |
| **ADHOC + EXPIRED** (TTL elapsed) | Kills job | No |
| **PROD + ONLINE_READY** | Yes, full reconcile | Yes (NEVER_EXPIRE default) |
| **PROD + PAUSED** | Actively kills | No (need `start_training_job`) |
| **PROD + EXPIRED** (rare — PROD is NEVER_EXPIRE) | Kills | No (must unexpire) |

## Commands

| Command | Effect |
|---|---|
| `register-and-run` `-m MODEL -a ENTITLEMENT -i IDENTITY -o ONCALL --customer CUSTOMER` | Register as PROD + ONLINE_READY. Handles: not-registered, ADHOC, EXPIRED, recurring-only |
| `update-training-job` `-m MODEL [-a] [-i] [-o]` | Update attribution/identity/oncall. Does NOT change importance or training state |
| `unregister-training-job` `-m MODEL [--reason]` | Stop job + remove from TMS entirely |
| `unexpire-training-job` `-m MODEL [--reason]` | EXPIRED → PAUSED → ONLINE_READY; starts training |
| `handle -s online` `-m MODEL` | `start_training_job`. Resume paused models |
| `handle -s off` `-m MODEL` | `stop_training_job` → PAUSED. TMS actively kills |

## State × Command Quick Reference

Legend: ✅ Success · ❌ Error · ⚪ No-op · ➡️ State Transition

| State | register-and-run | update | unregister | unexpire | handle -s online | handle -s off |
|---|---|---|---|---|---|---|
| Not Registered | ✅→PROD+READY | ❌ NOT_REGISTERED | ❌ NOT_REGISTERED | ❌ not EXPIRED | ❌ no state | ❌ not registered |
| Recurring Only | ✅→PROD+READY (uses update, not register) | ✅ | 🗑️ | ❌ RECURRING_ENABLED | ➡️ | ➡️ PAUSED |
| ADHOC+READY | ✅→PROD+READY (promotes) | ✅ (stays ADHOC) | 🗑️ | ❌ not EXPIRED | ⚪ | ➡️ PAUSED |
| ADHOC+PAUSED | ✅→PROD+READY | ✅ (stays PAUSED) | 🗑️ | ❌ not EXPIRED | ➡️ READY | ⚪ |
| ADHOC+EXPIRED | ✅→PROD+READY (unexpires first) | ✅ (stays EXPIRED) | 🗑️ | ✅→ADHOC+READY | ❌ must unexpire | ⚪ |
| ADHOC+EXPIRED (app-layer expired) | ❌ app layer fbpkg expired | ❌ same | 🗑️ | ❌ same | ❌ | ⚪ |
| PROD+READY | ⚪ (idempotent start) | ✅ | 🗑️ ⚠️ removes prod | ❌ not EXPIRED | ⚪ | ➡️ PAUSED |
| PROD+PAUSED | ⚪+➡️ READY | ✅ (stays PAUSED) | 🗑️ | ❌ not EXPIRED | ➡️ READY | ⚪ |
| PROD+EXPIRED | ✅→PROD+READY | ✅ (stays EXPIRED) | 🗑️ | ✅→PROD+READY | ❌ must unexpire | ⚪ |

## State Transition Paths

```
UNREGISTERED  —[register-and-run]→  PROD + ONLINE_READY
ADHOC         —[register-and-run]→  PROD + ONLINE_READY   (promotes importance)
EXPIRED       —[register-and-run]→  PROD + ONLINE_READY   (unexpire → promote → start)
EXPIRED       —[unexpire]→          PAUSED —[start]→ ONLINE_READY
PAUSED        —[handle -s online]→  ONLINE_READY
ONLINE_READY  —[handle -s off]→     PAUSED
ANY           —[unregister]→        REMOVED
RECURRING     —[register-and-run]→  PROD + ONLINE_READY   (update, not register)
```

## Triage Relevance

**Common triage scenario:** model stopped training, auto-restart didn't fire.

| Check | What to look for |
|---|---|
| `mvai online-training-mgr print -m <id>` | If ADHOC → no auto-restart (need `register-and-run` to promote to PROD) |
| State = EXPIRED | TTL elapsed. Need `unexpire-training-job` (or `register-and-run` which auto-unexpires) |
| State = PAUSED | Someone ran `handle -s off`. Need `handle -s online` |
| "app layer fbpkg expired" error | App layer package expired. Must preserve/rebuild app layer BEFORE any TMS mutation |
| Not registered | `register-and-run` is the idempotent fix for most non-running states |
