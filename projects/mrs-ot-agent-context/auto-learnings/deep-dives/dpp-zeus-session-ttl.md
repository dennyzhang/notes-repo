# DPP Session TTL — Zeus Dependency Chain

Why every OT job restarts every ~20 days, and why this is an infra
limitation leaking into the training layer.

## The causal chain

```
Zeus nodes have hard TTL (~24 days)
  └─ DPP stores session coordination state in Zeus
       └─ Session-immutable flags, routing maps, heartbeat data
            └─ Zeus GC deletes expired nodes
                 └─ SO crashes looking up deleted DPP flags (SEV S586904)
                      └─ SO crash takes down ALL of AI training
                           └─ DPP preemptively kills sessions at 20 days
                                └─ Training job restarts
                                     └─ Example age spikes ~3-5 min
```

## Three defense-in-depth layers

```
Layer                     Limit                Source file
-----                     -----                -----------
Master session runtime    20d (1,728,000s)     data_preproc/master/ScribeWorkItemManagerV2.cpp:39
Zeus DPP Flags TTL        20d                  data_preproc/experimental/dpp_flags/DPPFlagsBackend.cpp:103
SO session age            23d (1,987,200s)     data_preproc/session_orchestrator/controllers/SessionController.cpp:94
Zeus hard TTL             24d                  Infrastructure limit
```

## Why DPP can't just renew TTLs

DPP stores "session-immutable" flags — config snapshots frozen at session
creation. The design contract is: config doesn't change mid-session to
avoid subtle data processing bugs. Renewing TTLs would mean running on
20+ day old config with no mechanism to pick up flag changes, rollouts,
or fixes. A fresh session is the only way to get fresh config.

## Why this is an infra limitation (not a feature)

From the training job's perspective, this is unnecessary disruption. The
trainer just wants data — it doesn't care about DPP's internal coordination
mechanism. The Zeus TTL is a DPP implementation detail leaking upward.

Possible fixes DPP could implement:
1. Renew Zeus TTLs periodically (accept stale config as tradeoff)
2. Migrate session state to a store without TTL constraints
3. Graceful rotation — start new DPP session, warm it up, swap seamlessly

The original Zeus TTL was 30 days; reduced to 20 after SEV S269223.
Code comment: `TODO: Revert back to 30 days TTL after S269223 is resolved`

## Error signature (P55)

```
facebook::data_preproc::RetryableFatalSystemError: Session <ID>
has been running for 1728118 seconds which is higher than limit: 1728000 seconds.
Triggering a new attempt.
NOTE: This restart is necessary to prevent the session from running in bad state.
ErrorTraits: {ONCALL: DPP_DISTRIBUTED_DATA_READING, RETRYABILITY: 1}
```

Verification: failed attempt duration ≈ 480h AND new attempt auto-starts within minutes.
No action needed — transient example age spike self-resolves.

## Related

- SEV S586904 — SO crashed when session exceeded Zeus TTL
- SEV S269223 — caused TTL reduction from 30 → 20 days
- D86547370 — added 23-day SO backstop after S586904
- D106191904 — fixed MLHub URL in triage skill (discovered during this investigation)
- Investigated 2026-05-23 on mvai-training-online-886797001 (IFR holdout, FEED)
