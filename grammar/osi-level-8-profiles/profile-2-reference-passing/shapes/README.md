# Profile 2 shapes (reference-passing for agents)

Seeded with **copies of the Profile 1 (Cyborg Channel) shapes** in `../profile-1/`.
Profile 2 uses the same closed contracts — `envelope`, `canonical-record`,
`sync-intent`, `private-local`, and `allowlist.template` — as its starting point.
They may be specialized for Profile 2's semantics: a published API surface, bounded
Context previews dereferenced on demand, and structured-output Effects enforced
identically at decode time and at ingest time. See
`../../docs/osi-level-8-profile-2-reference-passing.md`.
