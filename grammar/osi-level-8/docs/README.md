# OSI Level 8 — base specification docs

This directory holds the **base** specification: the normative text the profiles
conform to.

**The per-profile documents are not here.** They live with the package that
carries their SHACL shapes and fixtures:

    gems/osi-level-8-profiles/docs/

Per ADR 0022, the profiles are a consumable package (shapes + fixtures +
validator) rather than normative text, so they sit under `gems/` with the other
owned packages. Profile docs 3 through 8 used to be duplicated here byte for
byte; two copies of one document is not a cross-reference, it is a fork waiting
to happen, so this directory now points instead of copying.

`tooling/boundary/check_closed.py` asserts the duplication does not come back.
