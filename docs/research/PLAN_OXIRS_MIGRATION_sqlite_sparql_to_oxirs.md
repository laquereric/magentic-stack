---
"@context":
  "@vocab": urn:mm:vocab/
  mm: 'urn:mm:'
  epic: 'urn:mm:epic:'
  plan: 'urn:mm:plan:'
  inEpic:
    "@id": urn:mm:vocab/inEpic
    "@type": "@id"
  concepts:
    "@id": urn:mmg:curation/mentions
    "@type": "@id"
    "@container": "@set"
"@id": urn:mm:plan:PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs
"@type": Plan
inEpic: urn:mm:epic:epic_17_oxirs_graph_engine
concepts:
- urn:mmg:curation:concept:epic:epic_17_oxirs_graph_engine
---

<!-- mm:md_chunks
{
  "PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs#plan-oxirs-migration-sqlite-sparql-sqlite-oxirs-graph-engine-swap": {
    "line": 1,
    "level": 1,
    "heading": "PLAN_OXIRS_MIGRATION - sqlite-sparql -> sqlite + OxiRS (graph engine swap)"
  },
  "PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs#why": {
    "line": 6,
    "level": 2,
    "heading": "Why"
  },
  "PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs#primary-driver-rdf-star-graph-attribution": {
    "line": 17,
    "level": 2,
    "heading": "Primary driver: RDF-star = graph attribution"
  },
  "PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs#slices-briefs-under-docs-orchestration-briefs-oxirs-migration": {
    "line": 20,
    "level": 2,
    "heading": "Slices (briefs under docs/orchestration/briefs/oxirs_migration/)"
  }
}
-->
<!-- mm:md_embedding_nomic_768
{
  "doc": null,
  "PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs#plan-oxirs-migration-sqlite-sparql-sqlite-oxirs-graph-engine-swap": null,
  "PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs#why": null,
  "PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs#primary-driver-rdf-star-graph-attribution": null,
  "PLAN_OXIRS_MIGRATION_sqlite_sparql_to_oxirs#slices-briefs-under-docs-orchestration-briefs-oxirs-migration": null
}
-->
<!-- mm:md_triples_embedding_nomic_768
{
  "doc": null
}
-->
# PLAN_OXIRS_MIGRATION - sqlite-sparql -> sqlite + OxiRS (graph engine swap)

Author: SUPERDEV/Claude. Created 2026-06-22. Epic: epic_17_oxirs_graph_engine.
status: active

## Why
The graph/SPARQL layer is the custom Rust `vendor/sqlite-sparql` extension
(rdf_*, sparql_*, rdf_dred, rdf_owl_rl, rdf_shacl_core, rdf_triples vtab,
mm_context_query). Migrate to **OxiRS** (cool-japan; consume-don't-fork, CR-pin)
as a SPARQL-HTTP sidecar (Oxigraph now, oxirs-fuseki later) with SQLite staying
relational. Add SHACL (ruby `shacl` gem + OxiRS) + RDF* per-triple provenance.
Reuse existing Rails RDF gems (rdf, rdf-turtle, json-ld, shacl, sparql) and the
vv-* gems (vv-graph, vv-memory). See memories: oxirs-consume-sparql-http-sidecar,
slice-embeds-oxirs-for-sparql-federation, event-stream-provenance-rdf-star-future,
gem-rust-coexist-continuous-parity, cool-japan-oxirs-upstream.

## Primary driver: RDF-star = graph attribution
RDF-star (RDF 1.2 / SPARQL-star) is next-generation W3C semantic tech: it makes triples first-class subjects so ATTRIBUTION (asserted_by / source / turn_id / confidence) attaches to facts natively. OxiRS gives us standards-track RDF-star that sqlite-sparql does not — this is the strategic reason for the migration, not just a slice.

## Slices (briefs under docs/orchestration/briefs/oxirs_migration/)
S1 surface inventory + parity matrix (sqlite-sparql fn -> OxiRS/Rails-RDF); coexist-vs-cutover
S2 OxiRS/Oxigraph SPARQL-HTTP sidecar (supervised)
S3 vv-graph OxiRS backend behind the Storable/Loader/Sparql interface + dual-run byte-parity
S4 SHACL validation via `shacl` gem + OxiRS (dev_info shapes; replace rdf_shacl_core)
S5 RDF* (RDF-star) per-triple provenance (turn_id/trace_id/source)
S6 vv-memory graph projection on OxiRS
S7 cutover: flip Vv::Graph default to OxiRS once parity green; coexist-flag/retire sqlite-sparql; Delta-Bus federation






