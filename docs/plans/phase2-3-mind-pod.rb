#!/usr/bin/env ruby
# frozen_string_literal: true
# Report-only driver for Phase 2 (effect-plane) and Phase 3 (SLO).
# Reads the committed Phase 1b digest artifact. Does not talk to Docker.
# Does not invent telemetry, receipts, barriers, or a Release Packet.

require "json"
require "pathname"

ROOT = Pathname.new(__dir__).parent.parent
$LOAD_PATH.unshift((ROOT / "runtimes/effect-plane/lib").to_s)
$LOAD_PATH.unshift((ROOT / "tooling/slo/lib").to_s)
require "mmg-effect-plane"
require "vv-slo"

DIGESTS = JSON.parse((ROOT / "docs/plans/phase1b-mind-pod-digests.json").read, symbolize_names: true)

def jsonable(obj)
  case obj
  when Hash then obj.to_h { |k, v| [jsonable(k), jsonable(v)] }
  when Array then obj.map { |v| jsonable(v) }
  when Symbol then obj.to_s
  else obj
  end
end

def write_json(name, payload)
  path = ROOT / "docs/plans" / name
  path.write(JSON.pretty_generate(jsonable(payload)) + "\n")
  path
end

images = DIGESTS.fetch(:builtImages)
parents = DIGESTS.fetch(:pinnedParents)
rails = images.find { |i| i[:tag] == "mind-pod:demo" }
mind  = images.find { |i| i[:tag] == "mind-pod-mind:demo" }
sw    = images.find { |i| i[:tag] == "mind-pod-switch:demo" }

P = Mmg::EffectPlane::Placement
C = Mmg::EffectPlane::Classifier
S = Mmg::EffectPlane::Snapshot

# --- Phase 2: placements against the committed image ids, plus the live volume ---
image_placements = images.map do |img|
  {
    tag: img[:tag],
    imageId: img[:imageId],
    as_oci_unverified: P.declare(
      effect_id: "mind-pod/#{img[:tag]}",
      target: "/",
      topology_evidence: { stage: :oci_image, digest: img[:imageId], image_paths: ["/"], release_verified: false },
      mount_inventory: []
    ),
    as_oci_counterfactual_verified: P.declare(
      effect_id: "mind-pod/#{img[:tag]}",
      target: "/",
      topology_evidence: { stage: :oci_image, digest: img[:imageId], image_paths: ["/"], release_verified: true },
      mount_inventory: []
    ),
    admissibility_bare: S.admissibility({ digest: img[:imageId] })
  }
end

# The load-bearing live store: named volume mind-data at /data (SQLite).
sqlite_as_image = P.declare(
  effect_id: "mind-pod/back/sqlite",
  target: "/data/mind_pod.sqlite3",
  topology_evidence: { stage: :oci_image, digest: rails[:imageId], image_paths: ["/"], release_verified: false },
  mount_inventory: [{ path: "/data", writable: true, disposition: nil }]
)

sqlite_as_volume = P.declare(
  effect_id: "mind-pod/back/sqlite",
  target: "/data/mind_pod.sqlite3",
  topology_evidence: { stage: :host_volume },
  mount_inventory: [{ path: "/data", writable: true, disposition: nil }]
)

sqlite_class_authoritative = C.classify(
  effect: "mind-pod/back/sqlite",
  placement: sqlite_as_volume,
  authority: { role: :authoritative, reconstructable_from: nil },
  external_effects: []
)

sqlite_class_no_role = C.classify(
  effect: "mind-pod/back/sqlite",
  placement: sqlite_as_volume,
  authority: {},
  external_effects: []
)

secrets_mount = P.declare(
  effect_id: "mind-pod/switch/secrets",
  target: "/state",
  topology_evidence: { stage: :oci_image, digest: sw[:imageId], image_paths: ["/"], release_verified: false },
  mount_inventory: [{ path: "/state", writable: true, disposition: nil }]
)

# Honest contract: what is true of the demo compose, not what would pass C1–C9.
honest_contract = {
  authority: { retained: false },
  stores: [{ name: "mind-data", role: :authoritative, reconstruction: nil }],
  barrier: nil,
  mounts: [
    { path: "/data", writable: true, disposition: nil },
    { path: "/state", writable: true, disposition: nil }
  ],
  provenance: { digest: rails[:imageId] },
  includes: [],
  external_effects: [
    { id: "front-cpcp-client", closure: nil },
    { id: "mind-cpcp-client", closure: nil },
    { id: "switch-llm", closure: nil }
  ],
  fork: nil,
  retention: nil
}

phase2 = {
  sourceCommit: "3669a67",
  input: "docs/plans/phase1b-mind-pod-digests.json",
  capturedAt: DIGESTS[:capturedAt],
  builtImages: images,
  pinnedParents: parents,
  note_floating_parents: "Phase 1b rebuild: all three pinned bases (ruby/python/node) needed pulling. " \
                         "The locally cached tags were no longer what those tags pointed at. " \
                         "That is the floating-tag risk from Phase 1, observed. " \
                         "Pre-pin image ids e62dee91 / 9b29d7ae / d052e417 were thrown away; " \
                         "this snapshot uses only the committed artifact.",
  placements: {
    images: image_placements,
    sqlite_claimed_as_oci_image: sqlite_as_image,
    sqlite_as_host_volume: sqlite_as_volume,
    switch_secrets_claimed_as_oci_image: secrets_mount
  },
  classifier: {
    sqlite_declared_authoritative: sqlite_class_authoritative,
    sqlite_unclassified: sqlite_class_no_role
  },
  snapshot_contract: S.validate_contract(contract: honest_contract),
  snapshot_admissibility: images.map { |img| { tag: img[:tag], result: S.admissibility({ digest: img[:imageId] }) } },
  verdict: {
    is_effect_plane_snapshot: false,
    because: "C1–C9 fail as a conjunction; a named-volume SQLite is the sole Plane B store and is not in the image; " \
             "local demo tags are not a verified Release Packet. Useful as an engineering record, not a rollback point."
  }
}

# --- Phase 3: one objective for mind-pod BACK. Queries name metrics that are NOT emitted. ---
objective = Vv::Slo::Objective.new(
  service: "mind-pod",
  target: 0.99,
  time_window: "1h",
  good_query:  'sum(mind_pod_probe_success{role="back",path="/up"})',
  total_query: 'sum(mind_pod_probe_total{role="back",path="/up"})'
)

contract = Vv::Slo::ObservabilityContract.new(
  service: "mind-pod",
  environment: "demo",
  owner: "runtimes/mind-pod",
  required_attributes: %w[role path probe_id status_class]
)

# What the demo actually emits: compose healthcheck does GET /up and keeps the HTTP code.
# No scrape, no labels, no probe_id. Checking that as a signal is the gap, not a pass.
actual_up_signal = contract.check_signal(name: "compose.healthcheck.back./up", attributes: {})

# No burn reading exists. Do not invent remaining=1.0.
gate_no_reading = Vv::Slo::BudgetGate.evaluate(remaining: nil, actor: :agent)

runbook = Vv::Slo::Runbook.new(name: "mind-pod-back-unready", rung: 1)
restart_hitl = Vv::Slo::Runbook.hitl_required?(irreversible: true, blast_radius: :negligible)
activate_hitl = Vv::Slo::Runbook.hitl_required?(irreversible: true, blast_radius: :service)

phase3 = {
  sourceCommit: "3669a67",
  objective: {
    service: objective.service,
    target: objective.target,
    timeWindow: objective.time_window,
    good_query: objective.good_query,
    total_query: objective.total_query,
    statement: "99% of BACK GET /up probes succeed in any 1h window (36s error budget).",
    validate: objective.validate,
    openslo: objective.to_openslo
  },
  observabilityContract: {
    spec: {
      service: contract.service, environment: contract.environment, owner: contract.owner,
      required_attributes: contract.required_attributes
    },
    validate: contract.validate,
    actual_signal: actual_up_signal,
    because: "demo compose healthcheck is an HTTP GET /up that records a process exit code. " \
             "There is no Prometheus (or other) time series, no role/path/probe_id/status_class labels, " \
             "no scrape target. /_cpcp/up is a JSON liveness document, not a ratio metric."
  },
  budgetGate: {
    remaining: nil,
    evaluate: gate_no_reading,
    because: "no observed error rate, so no burn, so no remaining fraction. " \
             "The gate cannot decide. Do not treat absence of paging as a healthy budget."
  },
  burnRate: {
    classify: nil,
    because: "BurnRate.classify needs windowed burn factors. Nothing produces them."
  },
  runbook: {
    validate: runbook.validate,
    rehearsable: runbook.rehearsable?,
    when_it_fires: "BACK /up is not 200. Do not docker commit. Do not reinstantiate an image onto the live mind-data volume and call it rollback.",
    restart_container: restart_hitl,
    activate_materialization: activate_hitl
  },
  blocked: true,
  because: "the Objective is a well-formed spec of a metric that is not emitted; " \
           "ObservabilityContract.check_signal on the actual healthcheck is required_attribute_missing; " \
           "BudgetGate.evaluate(remaining: nil) is remaining_invalid. Activation is blocked."
}

p2 = write_json("phase2-effect-plane-mind-pod.json", phase2)
p3 = write_json("phase3-slo-mind-pod.json", phase3)
warn "wrote #{p2}"
warn "wrote #{p3}"
warn "phase2 snapshot ok=#{phase2[:snapshot_contract][:ok]} reason=#{phase2[:snapshot_contract][:reason]}"
warn "phase3 objective ok=#{phase3[:objective][:validate][:ok]} signal=#{actual_up_signal[:reason]} gate=#{gate_no_reading[:reason]} blocked=#{phase3[:blocked]}"
