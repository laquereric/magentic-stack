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
"@id": urn:mm:plan:PLAN_OXIRS_MAC_SERVICE
"@type": Plan
inEpic: urn:mm:epic:epic_17_oxirs_graph_engine
concepts:
- urn:mmg:curation:concept:epic:epic_17_oxirs_graph_engine
- urn:mmg:curation:concept:term:oxigraph
- urn:mmg:curation:concept:term:reason
- urn:mmg:curation:concept:term:sparql
- urn:mmg:curation:concept:term:mlx
- urn:mmg:curation:concept:term:graph
---

# PLAN_OXIRS_MAC_SERVICE — OxiRS/OxiGraph on-device service + epic-tree graph + MLX SPARQL reasoning

Epic: epic_17_oxirs_graph_engine. AR-first. 2026-06-22.

## Vision (operator)
The epic-tree MD mirror (bin/recover_epics) can ALSO populate an on-device **OxiGraph**
(OxiRS) Mac service; **MLX** then uses **SPARQL** (through MCB) to reason about system
state + backlog. Closes the loop: AR <-> MD mirror -> OxiGraph -> MLX SPARQL reasoning.
Builds on [[slice-embeds-oxirs-for-sparql-federation]], [[slice-health-is-a-graph-sparql-observability]],
[[oxirs-consume-sparql-http-sidecar]], and bin/recover_epics (62beb37d).

## Slices
- **S1 OxiRS/OxiGraph WORKS AS A MAC SERVICE** — launchd-supervised on-device SPARQL
  endpoint (:7878) so `sparql_query` (currently DOWN) works. Build/run
  vv-sparql-endpoints-rust (or Oxigraph) + plist + mm-sparql-endpoints-supervisor;
  RunAtLoad/KeepAlive; survives reboot. [the "works as mac service" ask]
- **S2 epic-tree -> OxiGraph loader** — project the Epic->Arc->Plan->Brief tree to triples
  (extend bin/recover_epics / a triple exporter) and load into OxiGraph named graph
  urn:mm:devinfo; keep synced on export. The MD mirror and the graph share one source.
- **S3 MLX reasons over SPARQL** — mac_llm MCB action (vv-mac-llm S4) + a pipeline where
  MLX issues/consumes SPARQL against OxiGraph to reason about state + backlog
  (stuck work, priorities, dependencies, what-next). On-device, free.
- **S4 backlog/state reasoning surface** — expose MLX's SPARQL-grounded answers (CLI/page):
  "what should the fleet do next?", "what's blocked?", "why is X stuck?".

## Notes
- Telemetry health graph (epic_20) federates with this: same OxiGraph service hosts
  HostHealth + PaneHealth + the devinfo (epic-tree) graph -> unified SPARQL reasoning.
- Deploy: substrate does not hot-reload; each slice needs restart + [[verify-deploy-ui-and-mcb]] SOP.
