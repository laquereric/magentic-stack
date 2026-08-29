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
# SHACL shapes for OSI Level 8 - moved

The profile SHACL shapes and conformance suites now live in the consolidated
repo, vendored at [`../../../gems/osi-level-8-profiles`](../../../gems/osi-level-8-profiles)
(Profiles 1-8). Gate 2 validates that tree. osi-level-8 remains the spec prose.
