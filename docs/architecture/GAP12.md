# Gap 12: the language-rule exemption is written; the gate was not

Row 12 said graph's exemption from the language rule was assumed, not
written. **False.** ADR 0047 names it twice (migration table line 89,
image table line 166). Those cells are a classification, not a
condition a fourth container would have to meet.

## The rule

Python => `mind`. Rust => `switch`. Everything else Ruby in Rails form.

## Exemption (normative)

A container is exempt when **all** of these hold:

1. third-party
2. unforked
3. digest-pinned
4. we ship no source into it (no build context, no bind-mount of our tree)

`graph` (oxigraph) meets them. A new container does not inherit the
excuse by sitting next to graph in a table; it must meet the conditions.
The machine copy is `tooling/compose/language_rule.json` `exemptions`.

## Violation is not exemption

`switch` is Node today and the target is Rust. That is a **named
violation** (row 11, blocked on 15/18/19), not an exemption. Separate
list, each entry has `kind` and `reason`. Did not rewrite switch to Rust
to make the gate pass.

## Gate

`tooling/compose/check_language_rule.py`. Population: containers
examined AND source files examined. Plants: empty CHECK_ROOT, drop the
graph exemption, drop the switch violation.

0047 `enforced_by` now names this checker. The previous three still
enforce other clauses of 0047 (closure, ownership boundary, loopback
env); they never enforced the language rule.
