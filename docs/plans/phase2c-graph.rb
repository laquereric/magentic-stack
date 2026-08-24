#!/usr/bin/env ruby
# frozen_string_literal: true
# Phase 2c — GRAPH is deployed (empty). Re-run Placement/Classifier against
# the real compose inventory. Do not invent a backfill. Do not stand up Storable.

require "json"
require "pathname"

ROOT = Pathname.new(__dir__).parent.parent
$LOAD_PATH.unshift((ROOT / "runtimes/effect-plane/lib").to_s)
require "mmg-effect-plane"

def jsonable(obj)
  case obj
  when Hash then obj.to_h { |k, v| [jsonable(k), jsonable(v)] }
  when Array then obj.map { |v| jsonable(v) }
  when Symbol then obj.to_s
  else obj
  end
end

P = Mmg::EffectPlane::Placement
C = Mmg::EffectPlane::Classifier

OXIGRAPH = "sha256:e68b3625743db4a4b18129a907ae36766f89bb6deeb8ab50d35685dbabe00b0e"

# Real compose inventory (extract/compose.yml and docker-compose.yml agree).
GRAPH_MOUNTS = [{ path: "/data", writable: true, disposition: :excluded }]
SQL_MOUNTS   = [{ path: "/data", writable: true, disposition: :excluded }]
SECRETS      = [{ path: "/state", writable: true, disposition: :excluded }]

def classify(target:, stage:, mounts:, authority:, digest: nil, release_verified: false)
  ev = { stage: stage }
  ev[:digest] = digest if digest
  ev[:image_paths] = ["/"] if stage == :oci_image || stage == :snapshot_image
  ev[:release_verified] = release_verified if stage == :oci_image
  placement = P.declare(
    effect_id: "mind-pod/#{target}",
    target: target,
    topology_evidence: ev,
    mount_inventory: mounts
  )
  classifier = C.classify(
    effect: "mind-pod/#{target}",
    placement: placement,
    authority: authority,
    external_effects: []
  )
  { placement: placement, classifier: classifier }
end

# Models inspected in this tree: no `triples do` on any of them.
NO_TRIPLES = %w[
  Note Journey Flow Mission Actor Persona Vision Reconciliation
]

graph_empty_inventory = classify(
  target: "/data", stage: :host_volume, mounts: [],
  authority: { role: :projection }
)
graph_real_inventory = classify(
  target: "/data", stage: :host_volume, mounts: GRAPH_MOUNTS,
  authority: { role: :projection }
)
# Honest: projection with NO executable reconstructable_from.
graph_honest = classify(
  target: "/data", stage: :host_volume, mounts: GRAPH_MOUNTS,
  authority: { role: :projection, reconstructable_from: nil }
)
# LIE: name a procedure that does not exist (whole-store Storable replay).
graph_lie_replay = classify(
  target: "/data", stage: :host_volume, mounts: GRAPH_MOUNTS,
  authority: { role: :projection, reconstructable_from: "Vv::Graph::Storable whole-store replay" }
)
graph_image = classify(
  target: "/", stage: :oci_image, mounts: GRAPH_MOUNTS,
  authority: { role: :projection },
  digest: OXIGRAPH, release_verified: false
)

sqlite = classify(
  target: "/data/mind_pod.sqlite3", stage: :host_volume, mounts: SQL_MOUNTS,
  authority: { role: :authoritative }
)
sqlite_clone = classify(
  target: "/data/mind_pod.sqlite3", stage: :host_volume, mounts: SQL_MOUNTS,
  authority: { role: :authoritative, clone_evidence: "volume-clone:mind-data" }
)

payload = {
  sourceCommit: "0f9d2b8",
  topology: %w[switch back backjob front mind graph],
  oxigraph_digest: OXIGRAPH,
  graph: {
    deployed: true,
    empty: true,
    volume: "graph-data",
    intended_role: "projection",
    placement_empty_inventory: graph_empty_inventory,
    placement_real_inventory: graph_real_inventory,
    honest_no_replay: graph_honest,
    lie_named_missing_replay: graph_lie_replay,
    oxigraph_image_unverified: graph_image
  },
  sqlite: {
    deployed: true,
    role: "authoritative",
    honest: sqlite,
    clone_evidence_exhibit: sqlite_clone
  },
  triples: {
    note: false, journey: false, flow: false, mission: false,
    actor: false, persona: false, vision: false, reconciliation: false,
    application_record: false,
    files: NO_TRIPLES
  },
  whole_store_replay: {
    exists: false,
    checked: [
      "gems/vv-graph/lib — no backfill/reproject/rebuild/project_all (reasoner full_rebuild is OWL, not AR replay)",
      "Publisher#drain_pending! drains ProjectionJob outbox of already-enqueued rows, not a table scan",
      "Storable is after_save per-row; mind-pod Gemfile does not depend on vv-graph",
      "runtimes/graph/README.md states there is no backfill"
    ]
  },
  class_or_instance_invariant: {
    enforced: false,
    merely_true: true,
    because: "Vv::Graph::Sparql.execute INSERT DATA is a public write surface. " \
             "Oxigraph is bound as a raw SPARQL server with no Storable proxy. " \
             "mind-pod has no Storable include. An INSERT DATA from anywhere is reconstructability-silent."
  },
  mounts_assigned: {
    "/data (mind-data)": "excluded — Plane B SQLite",
    "/data (graph-data)": "excluded — empty volume; not a reconstructable projection yet",
    "/state": "excluded — secrets"
  }
}

path = ROOT / "docs/plans/phase2c-graph.json"
path.write(JSON.pretty_generate(jsonable(payload)) + "\n")
warn "wrote #{path}"

def brief(label, h)
  c = h[:classifier]
  p = h[:placement]
  warn "#{label}: place_ok=#{p[:ok]} place_reason=#{p[:reason]} class_ok=#{c[:ok]} class=#{c[:classification]} role=#{c[:authority_role]} mat=#{c[:materialization]} rollback=#{c[:rollback]} reason=#{c[:reason]}"
end

brief("graph empty inv", graph_empty_inventory)
brief("graph real inv", graph_real_inventory)
brief("graph honest", graph_honest)
brief("graph LIE replay", graph_lie_replay)
brief("graph image", graph_image)
brief("sqlite auth", sqlite)
brief("sqlite clone", sqlite_clone)
