<!--
STATUS: frozen / superseded in place
effective: 2026-08-29
superseded-by: docs/adr/0041-two-shape-gems-role-not-namespace.md
governing-decision: ADR 0041 (two shape gems, role not namespace)
also: ADR 0042 (close the Ruby to the TTL; not this freeze), ADR 0043 (retain unreachable shapes)
This document is retained as historical and normative prose.
New protocol requirements are not added here.
New shape development: gems/osi-level-8-profiles (current SHACL package) and
gems/shapes-level-8, gems/shapes-application (packaging homes).
Do not delete. Do not move into a gem.
-->
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
