# Entity: Node

**Provided by:** `mmg-acia`  
**Class:** `Mmg::Acia::Node`  
**Path:** `app/models/mmg/acia/node.rb`  
**Graph-backed:** no  
**Generated:** 2026-08-03

## Description

Node -- the ACIA tree as an AR HIERARCHY (epic_65 core, moved verbatim from Mmg::Sal::AciaNode). Each node is a persisted ACIA node (kind/value/entity_iri/ semantic_role + Phase-B semantic_state); the tree is a materialized-path hierarchy. The GRAPH DECORATES each node with its component + styling so the TMUX / WEB / LLM hosts all drive the SAME node. This is the CORE tree primitive; presentation (unix_tree/dom) lives in mmg-sal, which depends on this gem.

## Associations

- `has_many :triples`

## Attributes

- (schema-defined)

## Reuse

Apps needing this concept REUSE `Mmg::Acia::Node` via a thin adapter (consume, do not fork).
