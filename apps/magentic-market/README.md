# apps/magentic-market/  [EXTERNAL / uncoupled]

**The MagenticMarket marketplace app is a standalone product, uncoupled from this
monorepo** (own repo, own deploy). It is **not vendored** here; the stack
interoperates with it through the **offer contract** (attestation + policy digest),
not by building its source.

What lives in this directory is the **stack-owned offer-attestation contract**:
the schema and fixtures that define how an offer is verified without inspecting
content. The marketplace verifies **capability, not content**.

## Verified offers (Gate 3)

A sample offer lives in [`offers/`](offers/): a `*.capability.json` (what the offer
can do - operations only, no data) bound by digest to a `*.policy.json` (purpose,
egress, no content inspection). **Gate 3** ([`.github/workflows/attestation.yml`](../../.github/workflows/attestation.yml))
verifies the capability<->policy digest binding **offline** and signs the capability
as an in-toto DSSE attestation - capability verified without inspecting content.

This contract is owned by the stack and applies to any (external) marketplace that
consumes it.
