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
"@id": urn:mm:plan:PLAN_0_9_3
"@type": Plan
inEpic: urn:mm:epic:epic_03_graph_memory_cas
concepts:
- urn:mmg:curation:concept:epic:epic_03_graph_memory_cas
- urn:mmg:curation:concept:term:folder
- urn:mmg:curation:concept:term:urn
- urn:mmg:curation:concept:term:tripl
- urn:mmg:curation:concept:term:properti
- urn:mmg:curation:concept:term:product
---

# PLAN 0.9.3 — RDF Folders: URIs, Triples, and SHACL Queries

## Source

docs/research/SqliteRdf.md — SQLite as RDF triple store via Redland, rdf-to-sqlite, rdftab.rs. Two approaches: flexible triple-store table (Subject, Predicate, Object) vs relational mapping. MagenticMarket already uses JSON-LD serialization and SHACL validation for ContextRecords.

## Insight

PLAN 0.9.0 introduced search folders. PLAN 0.9.1 added a product knowledge graph with typed edges. These are the same thing viewed differently:

- A **folder** is a named collection with constraints → it's a **URI**
- A **relationship** between folders (links-to, narrows, pivots-from) → it's a **triple**
- A **query** against folders (find products matching constraints) → it's a **SHACL shape**

MagenticMarket already speaks RDF: ContextRecords are JSON-LD, SHACL shapes validate them, IRIs identify them. Folders should be first-class RDF resources, not a parallel data model.

## Design: Folders as RDF

### Every Folder is a URI

```
urn:mm:folder:category:printing
urn:mm:folder:category:scanning
urn:mm:folder:category:multifunction
urn:mm:folder:search:home-office-800ppm-color
urn:mm:folder:decision:cart-2026-04-25
```

Category folders are permanent URIs. Search folders are session-scoped URIs. Decision folders (cart) are user-scoped URIs.

### Every Relationship is a Triple

```turtle
# Category hierarchy
<urn:mm:folder:category:printers> mm:subFolderOf <urn:mm:folder:category:printing> .
<urn:mm:folder:category:scanners> mm:subFolderOf <urn:mm:folder:category:scanning> .

# Search folder sources
<urn:mm:folder:search:home-office-800ppm> mm:sourcedFrom <urn:mm:folder:category:printing> .
<urn:mm:folder:search:home-office-800ppm> mm:sourcedFrom <urn:mm:folder:category:scanning> .

# Pivot history
<urn:mm:folder:search:home-office-800ppm:v2> mm:pivotsFrom <urn:mm:folder:search:home-office-800ppm:v1> .
<urn:mm:folder:search:home-office-800ppm:v2> mm:pivotReason "cost per page too high on laser" .

# Product membership
<urn:mm:product:EPET4850> mm:inFolder <urn:mm:folder:category:multifunction> .
<urn:mm:product:EPET4850> mm:inFolder <urn:mm:folder:search:home-office-800ppm:v3> .
<urn:mm:product:EPET4850> mm:status "shortlisted" .

# Cross-folder links
<urn:mm:folder:search:home-office-800ppm:v4> mm:linkedFolder <urn:mm:folder:search:scanner-duplex> .
<urn:mm:folder:search:scanner-duplex> mm:complementsSearch <urn:mm:folder:search:home-office-800ppm:v4> .

# Decision
<urn:mm:folder:decision:cart-2026-04-25> mm:selectedFrom <urn:mm:folder:search:home-office-800ppm:v4> .
<urn:mm:product:EPET4850> mm:inFolder <urn:mm:folder:decision:cart-2026-04-25> .
<urn:mm:product:FUJIX1600> mm:inFolder <urn:mm:folder:decision:cart-2026-04-25> .
```

### Every Query is a SHACL Shape

Instead of SQL WHERE clauses or method-chain filters, folder queries are SHACL shapes — the same validation language MagenticMarket already uses for ContextRecords.

```turtle
# Shape: "Find ink-tank printers under $400 with ≥800ppm duty cycle"
mm:InkTankPrinterShape a sh:NodeShape ;
  sh:targetClass mm:Product ;
  sh:property [
    sh:path mm:category ;
    sh:hasValue "printer"
  ] ;
  sh:property [
    sh:path mm:priceCents ;
    sh:maxInclusive 40000
  ] ;
  sh:property [
    sh:path mm:inkSystem ;
    sh:hasValue "tank"
  ] ;
  sh:property [
    sh:path mm:dutyCycleMonthly ;
    sh:minInclusive 800
  ] .
```

A search folder's constraints **are** a SHACL shape. Narrowing the folder = adding `sh:property` constraints. Pivoting = creating a new shape that references the old one.

## Triple Store in SQLite

### Table: triples

```sql
CREATE TABLE triples (
  id INTEGER PRIMARY KEY,
  subject TEXT NOT NULL,
  predicate TEXT NOT NULL,
  object TEXT NOT NULL,
  object_type TEXT DEFAULT 'uri',  -- 'uri' | 'literal' | 'integer' | 'float'
  graph TEXT DEFAULT 'default',     -- named graph for quad support
  provenance TEXT DEFAULT 'EXTRACTED',
  confidence REAL DEFAULT 1.0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_triples_spo ON triples(subject, predicate, object);
CREATE INDEX idx_triples_pos ON triples(predicate, object, subject);
CREATE INDEX idx_triples_osp ON triples(object, subject, predicate);
CREATE INDEX idx_triples_graph ON triples(graph);
```

Three indexes (SPO, POS, OSP) cover all common triple-pattern queries. The `graph` column enables named graphs (quads) — each session can have its own graph.

### Why Triple Table, Not Relational Mapping

The research doc describes two approaches. We use the triple table because:

1. **Folders are dynamic.** Users create new folder types, new relationships, new constraints at runtime. A fixed schema can't accommodate this.
2. **SHACL already works on triples.** The ShaclValidator we have validates RDF graphs. If folders are triples, SHACL validates folder queries natively.
3. **JSON-LD round-trips.** ContextRecords are JSON-LD → triples → JSON-LD. Folders in the same triple store participate in the same serialization.
4. **Graph traversal is natural.** "Find all folders linked to this search" is a triple-pattern query, not a JOIN chain.

### Performance Mitigation

Triple stores are slow for complex traversals in pure SQL. Mitigations:

- **Materialized views** for hot paths (category membership, active search folders)
- **Graph cache** in SolidCache for frequently traversed subgraphs
- **Bounded traversal** — max depth 3 for any single query
- **Denormalized product table stays** — the triple store augments, doesn't replace, the Product model

## SHACL as Query Language

### Current: SHACL validates ContextRecords

```ruby
# Existing: ShaclValidator checks incoming ContextRecords
ShaclValidator.validate(context_record, shape: "context-record.ttl")
```

### New: SHACL defines folder queries

```ruby
# New: SHACL shapes define what products belong in a folder
class FolderQuery
  def self.execute(shape_ttl, graph: "default")
    # 1. Parse SHACL shape
    shape = SHACL.parse(shape_ttl)

    # 2. Load candidate triples from SQLite
    candidates = Triple.where(predicate: "rdf:type", object: "mm:Product")

    # 3. Validate each candidate against the shape
    candidates.select do |candidate|
      subgraph = Triple.where(subject: candidate.subject)
      shape.conforms?(subgraph)
    end
  end
end
```

### Constraint Operations Map to SHACL

| Folder Operation | SHACL Equivalent |
|-----------------|------------------|
| Add price constraint ≤ $400 | `sh:property [ sh:path mm:price ; sh:maxInclusive 400 ]` |
| Require feature "WiFi" | `sh:property [ sh:path mm:hasFeature ; sh:hasValue "WiFi" ]` |
| Exclude category "laser" | `sh:property [ sh:path mm:inkSystem ; sh:not [ sh:hasValue "toner" ] ]` |
| Minimum duty cycle 800 | `sh:property [ sh:path mm:dutyCycle ; sh:minInclusive 800 ]` |
| Product count ≥ 2 | `sh:property [ sh:path mm:inFolder ; sh:minCount 2 ]` |

### Building Shapes from Chat

The AI agent translates natural language constraints into SHACL:

```
User: "under $400, ink tank, at least 800 pages per month"

AI creates shape:
  sh:property [ sh:path mm:priceCents ; sh:maxInclusive 40000 ] ;
  sh:property [ sh:path mm:inkSystem ; sh:hasValue "tank" ] ;
  sh:property [ sh:path mm:dutyCycleMonthly ; sh:minInclusive 800 ] .

User: "actually, I also need scanning"

AI adds to shape:
  sh:property [ sh:path mm:category ; sh:hasValue "multifunction" ] .

→ Folder version incremented, shape extended, products re-queried
```

## Unification: ContextRecord + Folder + Product = One Graph

Currently three separate models:

| Model | Storage | Identity |
|-------|---------|----------|
| ContextRecord | `contexts` table | IRI (`urn:mm:context:...`) |
| SearchFolder | `search_folders` table | slug |
| Product | `products` table | SKU |

After this plan, all three live in the triple store as RDF resources:

```turtle
# A ContextRecord (already JSON-LD)
<urn:mm:context:abc123> a mm:ContextRecord ;
  mm:sessionId "bhphoto:browse" ;
  mm:action "create" ;
  mm:publisher "ai" .

# A folder (now also RDF)
<urn:mm:folder:search:home-office> a mm:SearchFolder ;
  mm:sessionId "bhphoto:browse" ;
  mm:status "open" ;
  mm:version 3 ;
  mm:shape <urn:mm:shape:ink-tank-under-400> .

# A product (now also RDF)
<urn:mm:product:EPET4850> a mm:Product ;
  mm:name "Epson EcoTank ET-4850" ;
  mm:priceCents 34900 ;
  mm:category "multifunction" ;
  mm:inkSystem "tank" .

# They connect via triples
<urn:mm:context:abc123> mm:createdFolder <urn:mm:folder:search:home-office> .
<urn:mm:product:EPET4850> mm:inFolder <urn:mm:folder:search:home-office> .
<urn:mm:folder:search:home-office> mm:sourcedFrom <urn:mm:folder:category:printing> .
```

The triple store is the unifying layer. The relational tables (contexts, products, search_folders) remain for fast indexed access. The triple store adds the graph relationships between them.

## Vocabulary: mm: Namespace

```turtle
@prefix mm: <https://magenticmarket.ai/vocab#> .

# Folder types
mm:SearchFolder    a rdfs:Class .
mm:CategoryFolder  a rdfs:Class .
mm:DecisionFolder  a rdfs:Class .

# Folder predicates
mm:subFolderOf     a rdf:Property .
mm:sourcedFrom     a rdf:Property .
mm:linkedFolder    a rdf:Property .
mm:pivotsFrom      a rdf:Property .
mm:pivotReason     a rdf:Property .
mm:complementsSearch a rdf:Property .
mm:selectedFrom    a rdf:Property .
mm:shape           a rdf:Property .  # links folder to its SHACL shape
mm:version         a rdf:Property .
mm:status          a rdf:Property .

# Product predicates
mm:inFolder        a rdf:Property .
mm:category        a rdf:Property .
mm:priceCents      a rdf:Property .
mm:inkSystem       a rdf:Property .
mm:dutyCycleMonthly a rdf:Property .
mm:hasFeature      a rdf:Property .
mm:competessWith   a rdf:Property .
mm:complements     a rdf:Property .
mm:tcoCheaperThan  a rdf:Property .
```

## Files

| File | Action |
|------|--------|
| `db/migrate/*_create_triples.rb` | NEW — triple store table |
| `packs/platform/app/models/triple.rb` | NEW — Triple model with SPO queries |
| `packs/partner_bhphoto/app/services/folder_graph.rb` | NEW — folder → triples |
| `packs/partner_bhphoto/app/services/product_tripler.rb` | NEW — product → triples |
| `packs/partner_bhphoto/app/services/folder_query.rb` | NEW — SHACL shape → product set |
| `config/shacl/folder_shape.ttl` | NEW — base SHACL shape for folder validation |
| `config/vocab/mm.ttl` | NEW — mm: vocabulary definition |
| `.well-known/shacl/folder.ttl` | NEW — published folder shape |

## Verification

1. Product inserted → triples created (category, specs, features)
2. Category folder → URI + membership triples for all products in category
3. User search → SHACL shape created from constraints → products matching shape returned
4. Folder narrowed → shape extended → fewer products match
5. Folder pivoted → new shape version → `mm:pivotsFrom` triple links to previous
6. Two folders linked → `mm:linkedFolder` triple → traversable
7. Cart decision → `mm:selectedFrom` triple traces back to search folder
8. SHACL validation of folder shape → confirms well-formed constraints
9. JSON-LD export of folder → includes all triples as linked data
10. ContextRecord + Folder + Product queryable in same triple store
