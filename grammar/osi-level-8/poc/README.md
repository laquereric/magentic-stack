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
# OSI Level 8 — runnable pods

The runnable proof-of-concept **pods** (FRONT + BACK OCI, `docker compose up --build`)
now ship inside their **CPCP** repos, each with Python + Go bindings and a PULL/PUSH
demo of the CID linkage:

- **Profile 1 (Cyborg Channel)** — https://github.com/laquereric/JSON-RPC-LD-PS1-P1
- **Profile 2 (reference-passing)** — https://github.com/laquereric/JSON-RPC-LD-PS1-P2

The CPCP standard (PubSubStandard_1 / JSON-RPC-LD-PS1):
https://github.com/laquereric/cyborg-pod-contract-package
