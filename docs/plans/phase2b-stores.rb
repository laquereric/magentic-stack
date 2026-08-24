#!/usr/bin/env ruby
# frozen_string_literal: true
# Phase 2b — declare SQLite and Graph as stores. Does not extend mmg-effect-plane.
# Does not stand up a graph service. Calls Placement / Classifier / Snapshot.

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
S = Mmg::EffectPlane::Snapshot

DIGESTS = JSON.parse((ROOT / "docs/plans/phase1b-mind-pod-digests.json").read, symbolize_names: true)
RAILS_DIGEST = DIGESTS.fetch(:builtImages).find { |i| i[:tag] == "mind-pod:demo" }.fetch(:imageId)

def classify_volume(target:, mounts:, authority:)
  placement = P.declare(
    effect_id: "mind-pod/#{target}",
    target: target,
    topology_evidence: { stage: :host_volume },
    mount_inventory: mounts
  )
  {
    placement: placement,
    classifier: C.classify(
      effect: "mind-pod/#{target}",
      placement: placement,
      authority: authority,
      external_effects: []
    )
  }
end

def classify_snapshot_image(target:, digest:, authority:)
  placement = P.declare(
    effect_id: "mind-pod/#{target}",
    target: target,
    topology_evidence: { stage: :snapshot_image, digest: digest, image_paths: [target] },
    mount_inventory: []
  )
  {
    placement: placement,
    classifier: C.classify(
      effect: "mind-pod/#{target}",
      placement: placement,
      authority: authority,
      external_effects: []
    )
  }
end

sqlite_mounts_unresolved = [{ path: "/data", writable: true, disposition: nil }]
sqlite_mounts_excluded   = [{ path: "/data", writable: true, disposition: :excluded }]
sqlite_mounts_seeded     = [{ path: "/data", writable: true, disposition: :branch_seeded }]
secrets_unresolved       = [{ path: "/state", writable: true, disposition: nil }]
secrets_excluded         = [{ path: "/state", writable: true, disposition: :excluded }]

# --- SQLite: deployed, mixed file (append-only osi_l8_* AND mutable notes/journeys) ---
sqlite = {
  deployed: true,
  path: "/data/mind_pod.sqlite3",
  volume: "mind-data",
  honest_authority: {
    role: :authoritative,
    reconstructable_from: nil,
    clone_evidence: nil,
    because: "nothing else retains these rows. osi_l8_* journals live here; so do mutable notes/journeys. " \
             "There is no event log outside this file and no graph service in compose."
  },
  as_host_volume: {
    unresolved: classify_volume(
      target: "/data/mind_pod.sqlite3",
      mounts: sqlite_mounts_unresolved,
      authority: { role: :authoritative }
    ),
    excluded_authoritative: classify_volume(
      target: "/data/mind_pod.sqlite3",
      mounts: sqlite_mounts_excluded,
      authority: { role: :authoritative }
    ),
    branch_seeded_authoritative: classify_volume(
      target: "/data/mind_pod.sqlite3",
      mounts: sqlite_mounts_seeded,
      authority: { role: :authoritative, clone_evidence: "volume-clone:mind-data" }
    ),
    # LIE exhibit: declaring a projection of a graph that is not deployed makes
    # Classifier go green. That is the false rollback point.
    lie_projection_of_absent_graph: classify_volume(
      target: "/data/mind_pod.sqlite3",
      mounts: sqlite_mounts_excluded,
      authority: { role: :projection, reconstructable_from: "oxigraph:named-graph:mind-pod" }
    )
  },
  as_snapshot_image: {
    honest_authoritative: classify_snapshot_image(
      target: "/data/mind_pod.sqlite3",
      digest: RAILS_DIGEST,
      authority: { role: :authoritative, reconstructable_from: "n/a" }
    ),
    lie_projection: classify_snapshot_image(
      target: "/data/mind_pod.sqlite3",
      digest: RAILS_DIGEST,
      authority: { role: :projection, reconstructable_from: "oxigraph:named-graph:mind-pod" }
    )
  }
}

# --- Graph: NOT deployed. Placement should fail inventory. Design-only claim. ---
graph = {
  deployed: false,
  design_only: true,
  intended_path: "/data/oxigraph",
  intended_authority: {
    role: :authoritative,
    reconstructable_from: nil,
    clone_evidence: nil,
    because: "runtimes/graph/README.md: Oxigraph is the RDF truth store; other surfaces project from it. " \
             "Classifier refuses :authoritative as a Plane C materialization. If GRAPH existed, it would be Plane B."
  },
  as_host_volume_not_in_compose: classify_volume(
    target: "/data/oxigraph",
    mounts: [],
    authority: { role: :authoritative }
  ),
  as_snapshot_image_no_digest: classify_snapshot_image(
    target: "/data/oxigraph",
    digest: nil,
    authority: { role: :authoritative, reconstructable_from: "n/a" }
  ),
  what_would_have_to_be_true: [
    "a graph service in extract/compose.yml with a durable volume",
    "BACK writing RDF as the append-only truth, not only jsonld columns inside SQLite",
    "notes/journeys/missions either projected into the graph or declared a separate Plane B",
    "a reconstructable_from cursor (named graph + txn id) SQLite osi_l8_* could replay from",
    "then SQLite could be role: :projection — and only then is it a materialization"
  ]
}

# Mount dispositions we actually assign (honest, deployed).
mounts_assigned = {
  "/data" => {
    volume: "mind-data",
    disposition: :excluded,
    because: "writable Plane B. An image fork must not claim to roll it back. " \
             "branch_seeded would be a volume clone of the authority, which is compensable restore, " \
             "not a Plane C materialization. immutable_input is false — BACK writes it."
  },
  "/state" => {
    volume: "bind:.agent/secrets",
    disposition: :excluded,
    because: "FORBIDDEN_CONTENT includes secrets. Must never enter a snapshot payload."
  },
  "ollama-models" => {
    volume: "ollama-models",
    disposition: :excluded,
    because: "model cache; reconstructable from the ollama image/registry. Not asked; named so it is not silent."
  }
}

# C6: does /state alone refuse? Only if we declare the content class.
c6_secrets = {
  mount_excluded_includes_empty: S.validate_contract(contract: {
    authority: { retained: true, cursor: "n/a" },
    stores: [{ name: "mind-data", role: :authoritative, reconstruction: "n/a" }],
    barrier: { id: "none", fenced: false, writers: ["back"], acknowledgements: [], receipts: {} },
    mounts: sqlite_mounts_excluded + secrets_excluded,
    provenance: { digest: RAILS_DIGEST },
    includes: [],
    external_effects: [],
    fork: nil,
    retention: nil
  }),
  mount_unresolved_includes_empty: S.validate_contract(contract: {
    authority: { retained: true, cursor: "n/a" },
    stores: [{ name: "mind-data", role: :authoritative, reconstruction: "n/a" }],
    barrier: { id: "none", fenced: false, writers: ["back"], acknowledgements: [], receipts: {} },
    mounts: sqlite_mounts_unresolved + secrets_unresolved,
    provenance: { digest: RAILS_DIGEST },
    includes: [],
    external_effects: [],
    fork: nil,
    retention: nil
  }),
  includes_secrets: S.validate_contract(contract: {
    authority: { retained: true, cursor: "n/a" },
    stores: [{ name: "mind-data", role: :authoritative, reconstruction: "n/a" }],
    barrier: { id: "none", fenced: false, writers: ["back"], acknowledgements: [], receipts: {} },
    mounts: sqlite_mounts_excluded + secrets_excluded,
    provenance: { digest: RAILS_DIGEST },
    includes: [:secrets],
    external_effects: [],
    fork: nil,
    retention: nil
  })
}

# Full honest contract: both stores declared. Graph is design-only — including it
# as a real store in a live snapshot would be a lie. We still run it so the
# refusal is from the gem.
honest_both = S.validate_contract(contract: {
  authority: { retained: false },
  stores: [
    { name: "mind-data", role: :authoritative, reconstruction: nil },
    { name: "graph", role: :authoritative, reconstruction: nil }
  ],
  barrier: nil,
  mounts: sqlite_mounts_excluded + secrets_excluded,
  provenance: { digest: RAILS_DIGEST },
  includes: [],
  external_effects: [
    { id: "front-cpcp-client", closure: nil },
    { id: "mind-cpcp-client", closure: nil },
    { id: "switch-llm", closure: nil }
  ],
  fork: nil,
  retention: nil
})

# Counterfactual: GRAPH exists as Plane B, SQLite is a projection. MARKED.
# Still not true of notes/journeys. This is the future joint, not a verdict.
counterfactual_graph_as_b = S.validate_contract(contract: {
  authority: { retained: true, cursor: "oxigraph:named-graph:mind-pod@txn-not-real" },
  stores: [
    { name: "mind-data", role: :projection, reconstruction: "replay from oxigraph named graph" },
    { name: "graph", role: :materialization, reconstruction: "oxigraph data files are the RDF materialization of Plane B" }
  ],
  barrier: { id: "b-fake", fenced: true, writers: %w[back oxigraph],
             acknowledgements: %w[back oxigraph],
             receipts: { "mind-data" => "rcpt-sql", "graph" => "rcpt-ox" } },
  mounts: [
    { path: "/data", writable: true, disposition: :branch_seeded },
    { path: "/state", writable: true, disposition: :excluded }
  ],
  provenance: { path: :rebuilt_release, release_packet_verified: true, binds_to_digest: RAILS_DIGEST },
  includes: [:materialized_state],
  excludes: [:secrets],
  external_effects: [{ id: "front-cpcp-client", closure: :absent }],
  fork: { activation_event_ref: "evt-not-real", branch: "branch:demo" },
  retention: { owner: "runtimes/mind-pod", retention_class: :checkpoint, expiry: "P7D" }
})

payload = {
  sourceCommit: "c304315",
  gem: "runtimes/effect-plane — not extended",
  sqlite: sqlite,
  graph: graph,
  mounts_assigned: mounts_assigned,
  c6_secrets: {
    results: c6_secrets,
    finding: "the /state bind does NOT automatically refuse. C6 only looks at contract[:includes]. " \
             "Unresolved /state fails C4 first. includes:[:secrets] fails C6 (correct). " \
             "excluded /state + empty includes lets C6 pass — so exclusion is load-bearing, not implied."
  },
  snapshot_honest_both: honest_both,
  snapshot_counterfactual_graph_as_plane_b: {
    design_only: true,
    result: counterfactual_graph_as_b,
    because: "even this counterfactual still lies about notes/journeys, which have no graph mapping. " \
             "If result[:ok] is true, that proves a well-formed contract can hide an unmapped Plane B table."
  },
  one_sentence_authority: "SQLite (mind-data) is the sole deployed authority; GRAPH is not deployed, " \
                          "and Classifier will never accept an authoritative store as a Plane C materialization."
}

path = ROOT / "docs/plans/phase2b-stores.json"
path.write(JSON.pretty_generate(jsonable(payload)) + "\n")
warn "wrote #{path}"

sql_h = sqlite[:as_host_volume][:excluded_authoritative][:classifier]
sql_lie = sqlite[:as_host_volume][:lie_projection_of_absent_graph][:classifier]
sql_snap = sqlite[:as_snapshot_image][:honest_authoritative][:classifier]
g_place = graph[:as_host_volume_not_in_compose][:placement]
warn "sqlite host_volume authoritative: ok=#{sql_h[:ok]} class=#{sql_h[:classification]} rollback=#{sql_h[:rollback]} reason=#{sql_h[:reason]}"
warn "sqlite LIE projection: ok=#{sql_lie[:ok]} class=#{sql_lie[:classification]} rollback=#{sql_lie[:rollback]}"
warn "sqlite snapshot_image authoritative: ok=#{sql_snap[:ok]} reason=#{sql_snap[:reason]}"
warn "graph placement: ok=#{g_place[:ok]} reason=#{g_place[:reason]}"
warn "c6 includes_secrets: #{c6_secrets[:includes_secrets][:reason]}"
warn "c6 excluded empty includes first fail: #{c6_secrets[:mount_excluded_includes_empty][:reason]}"
warn "honest both: #{honest_both[:reason]} failed=#{Array(honest_both[:failed]).map { |f| f[:condition] }.join(',')}"
warn "counterfactual ok=#{counterfactual_graph_as_b[:ok]} reason=#{counterfactual_graph_as_b[:reason]}"
