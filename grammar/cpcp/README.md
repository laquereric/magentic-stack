# grammar/cpcp/  🟢 OWN IT

**CPCP — the Cyborg-Pod-Contract-Package.** The contract profile served at the
`/_cpcp` seam: resources projected as CID-grounded JSON-RPC-LD, conforming to the
broader JSON-RPC-LD protocol.

- **Implementation (vendored):** [`../../interfaces/rails-cpcp/`](../../interfaces/rails-cpcp/)
  — the mountable Rails engine (subtree-imported).
- **Vocabulary / shapes:** the projection targets the public OWL/SHACL vocabulary
  at `https://w3id.org/laquereric/cpcp/ns#` and mirrors the `JSON-RPC-LD-PS1-P1/P2`
  CID shape. Those shapes are **canonical in external repos**
  (`cyborg-pod-contract-package`, `JSON-RPC-LD-PS1-P1`, `JSON-RPC-LD-PS1-P2`) and
  are a **pending subtree import** here (tracked in [`../../docs/SOURCE_STATUS.md`](../../docs/SOURCE_STATUS.md)).
- Deploy doctrine: CPCP is **mandatory two-pod** (Rails BACK + a distinct FRONT),
  never co-located.

> No SHACL shapes are fabricated in this directory. Until the CPCP shape repos are
> imported, CPCP conformance is exercised via the seam-contract specs in
> `interfaces/rails-cpcp` (see Gate 1).
