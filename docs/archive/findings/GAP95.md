# Gap 95: retract-only quoted-triple DELETE must not report GRAPH-down as success

`rdf_star_annotation_delete` swallowed every SPARQL envelope so emit
could continue past Oxigraph's RDF-star DELETE gap. GRAPH-down was
supposed to be caught by the next non-star execute.

That holds on emit (parent DELETE/INSERT follows). It does **not** hold
on a retract-only path: `sparql_delete` / `replace_predicate_set_via_update!`
with a quoted-triple subject and an empty insert returned `{ok:true}`.

LATENT: today's `retract_predicate!` callers pass a primary subject, not
a quoted term. The guard is so a future caller cannot resurrect gap 7(b).

Fix: the call site still swallows engine-limited parse refusals, but
returns a `:graph_unreachable` envelope. Immediate then `:error`s.
