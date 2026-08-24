# mmg-graph

The ONE wrapper around MM's **Rust graph DB (Oxigraph)** HTTP SPARQL interface: `publish` (INSERT DATA to a
named graph), `query` (SELECT → rows), `update` (SPARQL UPDATE) — instead of every gem hand-rolling the same
Net::HTTP-to-`:7878` block.

grammar-in (`grammar.bnf`) → graph-out (the store itself). Self-registers `graphdb_query` / `graphdb_publish`
/ `graphdb_update`.

**Federation is anticipated, not implemented.** `Execute.federate` + `graphdb_federate` + the `Federation`
boundary concept fix the SHAPE of Manus's coming federated graph DB (multi-store / SPARQL SERVICE across
endpoints) so callers can be written now; the body lands when that work does. KISS until then.

## Ad-hoc graph storage is grounded by a model

Every node in this graph references a Rails model — a class or an instance — and
node identity is `(model class, primary key)`. That is what makes the graph a
**projection** of the relational store rather than a second authority.

Ad-hoc triples had nothing to reference. `publish` took raw triples and a
named-graph string defaulting to `urn:mmg:graph:default`, which resolves to no
record: anything could write nodes no model could reproduce, and nothing would
catch it. The invariant held by discipline, which is to say it did not hold.

`Mmg::Graph::Entry` is that missing record.

```ruby
entry = Mmg::Graph::Entry.create!(
  date: "2026-08-24",
  name: "harbour board minutes",
  description: "assertions derived from the 14 Aug meeting"
)

Execute.publish(triples, entry: entry)
# => { ok: true, graph: "urn:mmg:graph:entry:12", ref: "Mmg::Graph::Entry:12" }
```

**date, name and description are required.** The triples say what was asserted;
they never say why it is here, and the why is what a later reader needs. A store
of unattributed assertions cannot be audited, and the cost of asking is one line.

**The graph name is derived, never supplied.** A caller that could name its own
graph could write into someone else's, or into one that resolves to no record at
all. Passing a bare `graph:` string is refused as `ungrounded_graph` rather than
honoured.

So an ungrounded node is not discouraged here — it is inexpressible. That is a
stronger guarantee than asking callers not to write one.
