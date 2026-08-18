# apps/magentic-market/  🔵 OFFICIAL

MagenticMarket — a marketplace for **verified offers without data inspection.**
Offers carry attestation and a policy digest; the market verifies capability, not
content. The bottom of the adoption flywheel.

- Minimum viable offer = attestation + policy digest.
- “Build an offer, not a chatbot.”

## Verified offers (Gate 3)

A sample offer lives in [`offers/`](offers/): a `*.capability.json` (what the offer
can do — operations only, no data) bound by digest to a `*.policy.json` (purpose,
egress, no content inspection). **Gate 3** ([`.github/workflows/attestation.yml`](../../.github/workflows/attestation.yml))
verifies the capability↔policy digest binding **offline** and signs the capability
as an in-toto DSSE attestation — capability verified without inspecting content.
