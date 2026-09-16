---
title: "Semantic Medallion for MM: Concrete Next Step and First Arc"
topic: semantic_medallion_next_step
group: medallion
source: manus
manus_task_url: https://manus.im/app/ecz6e4QjrXyqDUuWuen4eG
note: Authored by the Manus cloud agent; facts reflect its web research and are not independently verified.
---

# Semantic Medallion for MM: Concrete Next Step and First Arc

Status: This document outlines the concrete next-step for MM’s Semantic Medallion given the current baseline, without redesigning the existing medallion architecture. It focuses on migrating to a triple-native Bronze/Silver/Gold layering over RDF triples and on the explicit migration and deprecation path for vv-medallion to mmg-medallion, including interactions with GraphMemory, Curation, and SHACL.

## Scope and evidence boundary

MM’s baseline inventory includes vv-medallion and components under Vv::Medallion (Flow, Conformer, Curator), audit!, Mm::GraphMemory (MemoryRecord + CAS), Mmg::Curation, and a separate vv-memory store. All recommendations here are constrained to the supplied baseline and standard RDF/SHACL/SPARQL references; no redesign of the medallion architecture is proposed. The core contractual substrate remains: RDF data as graphs and named graphs, with SPARQL Update for graph-level mutations and SHACL for validation. See the RDF data model and named-graph concepts, plus SPARQL/SHACL references. [1] [4] [3]

- RDF data model and named graphs: RDF datasets contain a default graph and zero or more named graphs; named graphs are identified by graph names but graph names do not by themselves convey lifecycle or truth status. This underpins the semantic constraint that Bronze/Silver/Gold are lifecycle contracts over named graphs, not RDF-native semantics. “The graph name is not required to denote the graph. It is merely syntactically paired with the graph.” [1]

> Quoted from RDF 1.2 Concepts: “The graph name is not required to denote the graph. It is merely syntactically paired with the graph.” [1]

- The baseline acknowledges that RDF 1.2 Concepts was at the Candidate Recommendation stage as of 7 April 2026, while SPARQL 1.2 Update and SHACL 1.2 Core were Working Drafts. The operational approach uses SPARQL Update and SHACL as mutability/validation primitives on top of RDF graphs, not as guarantees of truth across layers. See RDF 1.2 Concepts and SPARQL SHACL status notes. [1] [4] [5]

## The single next step (the constrained semantic migration)

Make each existing Flow declare an RDF layer contract and route the existing Conformer and Curator outputs to explicitly identified Bronze, Silver, and Gold named graphs. This preserves the current architecture, storage, and orchestration while adding semantic, triple-native governance on top of RDF graphs. No new projection plane or storage layer is introduced; the change is about explicit graph-layer contracts and names, provenance, and audit linkage.

- Flow contracts: define source graph(s), target graph, layer role, run/revision identity, shape-set/version, promotion policy, and audit/provenance record. The exact IRI scheme is an MM implementation choice (illustrative form: …/flow/{flow}/silver/{revision}).
- Bronze/Silver/Gold meanings (concrete triple-native semantics):
  - Bronze: raw RDF triples admitted from a source; retain source identity and run identity; no normalization or curation implied. Flow determines Bronze graph. Gate: parse/load and source/audit capture. [1] [4]
  - Silver: triples produced by Conformer after extraction, quality metrics, and strategy selection; conformed claims traceable to Bronze input and flow/revision. Conformer stages remain; triple_proposal becomes the Silver change-set; writer writes to a Silver named graph. Gate: SHACL conformance policy and quality threshold. [4] [3]
  - Gold: triples selected by Curator from Silver; auditable curation decision; links to Mmg::Curation records. Gate: SHACL/policy pass and curated acceptance. [3]

- Validation and governance: SHACL shapes graphs validate the Bronze/Silver/Gold data graphs; SHACL reports are persisted and linked to the relevant audit. SHACL is a gate/reporting mechanism, not a transformation engine. [3]

- Central implications: this is a triple-native projection contract (Bronze → Silver → Gold) layered atop RDF named graphs via SPARQL Update operations; SHACL provides validation gates and reports, not data transformation, and RDF datasets provide the storage substrate. [1] [4] [3]

## How the existing pieces compose (minimal semantic wiring)

- Vv::Medallion::Flow: retain flow: name constructs; extend with explicit inputs/outputs, layer role, shape-set/version, and audit hooks. Do not replace the DSL/registry. [4]
- Conformer: continues Bronze→Silver projection; emit Silver triples as candidate changes; apply quality checks and strategy; write only accepted Silver into a Silver graph. SHACL gates apply to the Silver output as part of the conformance policy. [4] [3]
- Curator + Mmg::Curation: Gold is populated only from accepted Silver and linked to primary/related curation context. Do not auto-assert non-curated material into Gold. [3]
- Mm::GraphMemory (MemoryRecord + CAS): preserve as audit/version guard; CAS is used as a promotion-pointer with retry semantics rather than silent overwrites. Gold’s provenance links to MemoryRecord/cas outcomes. [1] (memory concepts are MM-specific; RDF SHACL/SPARQL references provide the substrate) 
- audit!: extend audit payload to include source/target graph IDs, flow/version, input revision, shape-set/version, validation-report ID, and CAS outcome. Note: a named graph alone is not audit evidence. [1]
- SHACL: shapes graphs validate the appropriate data graphs and yield validation reports; use as conformance gate rather than a transformation engine. [3]

## Migration and deprecation path (mmg-medallion, with deprecation shim)

- Canonicalize: ship mmg-medallion with Mmg::Medallion::{Flow, Conformer, Curator} as the canonical API; legacy paths remain compatible via a deprecation shim. [4]
- Deprecation registry: vv-medallion and Vv::Medallion entries are registered as deprecated, delegating to the canonical mmg-medallion, with telemetry and removal policy surfaced in MM release notes. [1]
- Preserve identities: flow IDs, RDF graph IDs, and MemoryRecord identities remain stable during the initial semantic activation; avoid migrating vv-memory or rewriting history in this arc. [1]
- Enroll first flow: enable the layer contract for a representative Bronze→Silver flow using the new namespace; inputs produce a Silver graph, audit, SHACL report, and CAS-protected result. [4]
- Retire legacy after evidence: retire the shim only when registry telemetry shows no active vv-medallion usage. Timing is MM release-dependent. [4]

## Prioritized first arc (P0–P3)

- P0 — namespace safety: establish canonical mmg-medallion namespace with a vv-medallion compatibility shim and deprecation registry entries. This ensures backward-compatible operation while enabling semantic layering. [4]
- P1 — one semantic projection: enable a minimal layer contract on one existing Flow; Conformer writes to a revised Silver named graph derived from a Bronze input. Gate by SHACL conformance. [3] [4]
- P2 — promotion evidence: bind MemoryRecord CAS to the promotion record; enforce CAS retry semantics and non-silent progression when conflicts occur. SHACL validation must be collected and accessible in audit. [3] [1]
- P3 — curated Gold slice: Curator writes accepted Silver to Gold and links to Mmg::Curation context; ensure Gold contains only curated selections with lineage to Silver and audit. [3]

Explicit non-goals for this arc: creating a new medallion engine, introducing a new storage plane, bulk rewriting of history, automatic broad promotion of all curation material, or reliance on RDF 1.2 triple-terms/RDF-star features beyond the stated baseline. These are outside scope for the first arc and would constitute a redesign beyond the requested step.

## References

1. W3C, RDF 1.2 Concepts and Abstract Data Model, https://www.w3.org/TR/rdf12-concepts/ 
2. W3C, SPARQL 1.1 Update, https://www.w3.org/TR/sparql11-update/ 
3. W3C, Shapes Constraint Language (SHACL), https://www.w3.org/TR/shacl/ 
4. W3C, SPARQL 1.2 Update, https://www.w3.org/TR/sparql12-update/ 
5. W3C, SHACL 1.2 Core, https://www.w3.org/TR/shacl12-core/

## Sources

- https://www.w3.org/TR/rdf12-concepts/
- https://www.w3.org/TR/sparql11-update/
- https://www.w3.org/TR/shacl/
- https://www.w3.org/TR/sparql12-update/
- https://www.w3.org/TR/shacl12-core/
