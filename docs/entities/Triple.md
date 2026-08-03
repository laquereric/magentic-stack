# Entity: Triple

**Provided by:** `mmg-acia`  
**Class:** `Mmg::Acia::Triple`  
**Path:** `app/models/mmg/acia/triple.rb`  
**Graph-backed:** no  
**Generated:** 2026-08-03

## Description

Triple -- one PROPOSED graph triple OWNED by an ACIA Node until McbApply commits it (epic_65 Fmcb/McbApply). An Fmcb writes Triples to the ACIA tree (transaction-aware AR); McbApply adds the ACIA-stored triples to the graph on ACCEPT. `object_iri` distinguishes an IRI object (<...>) from a literal ("..."). Never-effects-state on its own: it is a staged proposal until McbApply commits.

## Associations

- `belongs_to :node`

## Attributes

- (schema-defined)

## Reuse

Apps needing this concept REUSE `Mmg::Acia::Triple` via a thin adapter (consume, do not fork).
