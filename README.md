# mmg-graph

The ONE wrapper around MM's **Rust graph DB (Oxigraph)** HTTP SPARQL interface: `publish` (INSERT DATA to a
named graph), `query` (SELECT → rows), `update` (SPARQL UPDATE) — instead of every gem hand-rolling the same
Net::HTTP-to-`:7878` block.

grammar-in (`grammar.bnf`) → graph-out (the store itself). Self-registers `graphdb_query` / `graphdb_publish`
/ `graphdb_update`.

**Federation is anticipated, not implemented.** `Execute.federate` + `graphdb_federate` + the `Federation`
boundary concept fix the SHAPE of Manus's coming federated graph DB (multi-store / SPARQL SERVICE across
endpoints) so callers can be written now; the body lands when that work does. KISS until then.
