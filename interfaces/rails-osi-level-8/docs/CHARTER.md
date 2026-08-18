# Charter - rails-osi-level-8

Realize the open **OSI Level 8** spec (Cyborg Channel + Profiles 1-8) as an **additive Rails
engine** that is a **semantic adapter atop CPCP**, not a competing RPC surface.

**Invariants (from the Magentic POC design):**
- One public seam: `/_cpcp` (rails-cpcp). This engine decorates it in the Level 8 grammar.
- Context = perception (PULL); Effect = action (PUSH), closed-SHACL validated before admission.
- Three-ledger placement enforced (`canonical` / `sync_intent` / `private_local`); default-deny egress.
- Profile evidence + a pinned CID; grounding via the osi-level-8 profile-*.ttl shapes (mm-shacl-reader).
- Human accountability + never-raise `{ ok:, reason:, because: }`.

**Build order:** wire `CpcpAdapter` to `RailsCpcp.project` ops -> `Grounding.validate` against
profile shapes -> `Ledger` placement + profile evidence -> return the grounded envelope.
