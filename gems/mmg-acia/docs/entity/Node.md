---
type: MM Entity
title: Node
class: Mmg::Acia::Node
table: mmg_sal_acia_nodes
resource: app/models/mmg/acia/node.rb
generated:
  by: mmg-optimize/okf-entity/0.1.0
---
## Role
Node -- the ACIA tree as an AR HIERARCHY (epic_65 core, moved verbatim from Mmg::Sal::AciaNode). Each node is a persisted ACIA node (kind/value/entity_iri/ semantic_role + Phase-B semantic_state); the tree is a materialized-path hierarchy. The GRAPH DECORATES each node with its component + styling so the TMUX / WEB / LLM hosts all drive the SAME node. This is the CORE tree primitive; presentation (unix_tree/dom) lives in mmg-sal, which depends on this gem. Table + iri + vocab kept as mmg_sal_acia_nodes / urn:mmg:sal:acia:<id> / urn:mm:*sal# for ZERO-DATA-RISK continuity (plan open-Q1); the acia# rename is a later isolated migration. isolate_namespace would prefix mmg_acia_ -- overridden below. Graph: TripleModel statements (AR-grounded). publish! still routes N-Triples through Mmg::Acia::Graph (SAL public graph facade). to_triples = statements.map(&:to_nt).

## Attributes
(schema not found in db/migrate)

## Relationships
- has_many [Triple](./Triple.md)
