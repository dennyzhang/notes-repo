# Open Questions — OT Knowledge Sharing

Questions I'm personally interested in but don't have answers to yet. Tracked here so I can investigate or ask the right people.

## Quantification Gaps

### Q1: How much data is actually lost per OT restart?
We say "data loss on every restart" and cite ~weekly restarts per model, but we don't measure the actual volume. How many training examples are lost per restart event? What's the distribution — is it usually 5 minutes of data or 2 hours?

**Why it matters**: This directly determines the NE impact and the ROI of watermark-checkpoint integration. Without this number, we can't prioritize the fix.

**How to answer**: Instrument the gap between last checkpoint timestamp and restart timestamp. Could query MAST restart events + UMM checkpoint metadata.

### Q2: What is "0.1% NE = material revenue impact" in actual dollars at current scale?
The slides cite $49K from a 2021 SEV analysis (50% data loss over 26h). That's 5 years old. What is the current-scale revenue impact of 0.1% NE? The number matters for justifying OT reliability investments.

**Why it matters**: Every reliability proposal needs an ROI argument. Without a current dollar figure, "material revenue impact" is hand-waving.

**How to answer**: Ask Ads Science or the NE-to-revenue conversion team. There may be an internal model.

### Q3: What is the actual OT restart frequency per model?
I say "roughly weekly per model" but this is an estimate. Is it 0.5x/week? 2x/week? Does it vary by model type (retrieval vs ranking)?

**How to answer**: Query MAST job restart events filtered by OT jobs, grouped by model, over the last 3 months.

## Architecture Understanding Gaps

### Q4: How does the watermark-checkpoint integration design actually work?
The slides say it's "in design phase" but I haven't read the design doc. What's the proposed mechanism? Does the trainer write the Scribe watermark into the checkpoint, or does UMM store it separately? What are the known tradeoffs?

**How to answer**: Find the design doc. Ask the MVAI team or check the OT roadmap.

### Q5: Why are ESR and Reels LSR at 30 min P90 when the target is 10 min?
The current state slide shows these models 3x over the SLI target. Is this a known, accepted gap? Is there active work to fix it? Or is the 10 min target aspirational?

**How to answer**: Check the IG OT Reliability Planning doc for these specific models. Ask the model owners.

### Q6: What happens to user embeddings between full snapshots?
I note that "only item embeddings get streamed; user embeddings wait for full snapshot" as a gap. But how stale do user embeddings actually get? Is the user tower updated via sparse deltas (embedding table rows include user IDs), or is it truly 1-2 hours stale?

**How to answer**: Trace the sparse delta selection mode for retrieval models. Do sparse deltas include user embedding rows, or only item embedding rows?

### Q7: How does DPP decide which Scribe data to read on OT restart?
I know DPP doesn't checkpoint the Scribe offset. But what exactly does "jumps to Scribe's now" mean? Does it use wall-clock time? A Scribe sequence number? What's the max catch-up window mechanism?

**How to answer**: Read the DPP reader code for OT mode. Check how `start_time` is set on restart.

## Operational Understanding Gaps

### Q8: What does the Hedwig failure blast radius actually look like?
I identify Hedwig outage as the highest-severity correlated risk. But has there been a full Hedwig outage affecting all OT streaming? What happened? How long did it last? How did models recover?

**How to answer**: Search for Hedwig-related SEVs that impacted OT streaming. Check the SEV tracker.

### Q9: Why do 40% of OT SEVs not get tagged mvai-online-training?
The SEV study says multi-source triangulation is required because tag-only search misses 40%. Is this a process gap (people forget to tag)? Or a scope gap (SEVs in DPP/Scribe/MAST aren't considered "OT" by those teams)?

**How to answer**: Look at the untagged SEVs. Who owned them? Were they in other teams' oncall scope?

### Q10: What's the actual cost breakdown of the 2.3-2.6x OT cost multiplier?
The SEV doc cites OT costing 2.3-2.6x recurring training. Where does the extra cost go — GPU for continuous training? Scribe quota? Hedwig bandwidth? Publishing compute?

**How to answer**: Check the MRS cost analysis doc referenced in the SEV study, or ask the capacity planning team.

## Questions That May Come Up in Q&A

### Q11: Why not stream dense deltas too?
Dense deltas are 1-2 GB and currently paced. We list "streaming by default for all delta types" as an opportunity. What's actually blocking this? Is it a Hedwig limitation, a validation concern, or just not prioritized?

### Q12: How does ZCH (Zero Collision Hashing) interact with sparse deltas?
ZCH maps feature IDs to embedding rows. When a sparse delta publishes "hot rows," does it use ZCH indices? What happens when the hash mapping changes between full snapshots?

### Q13: What's the plan for SilverTorch's "no item delta during full snapshot" limitation?
This creates a predictable freshness hole every 1-2 hours. Is there a design to fix this? Or is it accepted as a tradeoff?

---

*Last updated: 2026-02-22*
