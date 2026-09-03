# gstack Review — Profiles 1–10 (rails-osi-level-8 + mind-pod)

*Reviewer lens (correctness / simplification / efficiency / altitude) + CSO lens
(OWASP Top 10 / STRIDE, `private_local` non-escape, `/_cpcp` as the sole seam,
never-raise). Single-model pass — the second model (grok) is the builder, so it did
not re-review; medium/latent items were escalated and are now resolved in code.*

**Re-run after fixes (commit `2710419`).** The three findings from the baseline review
(`a9c2d77`) are addressed; verified green: **gem rspec 9/9, app rspec 25/25**.

## CSO — no high-confidence (≥8) findings

`private_local` non-escape is enforced end to end:
- Governed socio-economic rows: `Record.cross_boundary = where(ledger_placement: %w[canonical sync_intent])`; every `*.list` PULL uses `.cross_boundary`; a caller-supplied `ledgerScope: private_local` is refused non-disclosingly (`ledger_scope_forbidden`).
- **Canonical homes (Mission/Vision/Persona) now carry a ledger placement too** (fix #1): a `LedgerPlaced` concern adds validation + a `cross_boundary` scope; `intent.mission.get` / `vision.get` / `persona.list` filter through it, and the by-CID lookup runs over the `cross_boundary` relation — a private home is never returned nor existence-disclosed (by id *or* by its own CID). Proven in `spec/p10_ledger_spec.rb`.
- `/_cpcp` remains the only seam; refusals travel as never-raise envelopes (`KnownRefusal`).
- No secrets/PII in the tree; the `private_local` fixtures are test data asserted non-escaping.

## Findings — resolved

1. **[was medium · correctness/altitude] Canonical Mission/Vision/Persona could not represent `private_local`.** ✅ Fixed — `ledger_placement` migration on all six canonical homes; `Projection#default_placement` now honors the actual column (no blanket-`canonical`); the intent PULLs filter `cross_boundary`. A sensitive Mission/Persona is now both expressible and excluded at the boundary.
2. **[was low · efficiency/leak] `find_canonical` by-CID lookup scanned all rows.** ✅ Fixed — the scan now runs over `model.cross_boundary`, so it is bounded and can no longer surface a `private_local` record by CID. The lookup is still O(n) over non-private rows (the CID is derived, not stored) — acceptable at demo scale; materialize a CID column if the corpus grows.
3. **[was low · altitude] Demo-only affordances.** ✅ Marked — the P6 `DENY:`-title-prefix trigger is now labelled DEMO-ONLY with a note that a production PDP must not key authorization on user content. Grounding remains a Ruby allowlist over the SHACL vocab (full `mm-shacl-reader` wiring deferred and tracked); deny-evidence commits outside the outer push txn by design so public deny rows survive a refusal.

## Clean

The no-AR-duplication directive holds: canonical `missions/visions/personas/actors/journeys/flows`, zero `intent_*` duplicate tables, all relationships as RDF graph triples. ruby -c clean; gem 9/9; app 25/25.

**Verdict: clean.** No blocking issues; the one remaining low item (materialize the derived CID before scale) is a future optimization, not a defect.
