# frozen_string_literal: true

# S1: memory.land on BACK. All four registrations live here so the memory
# seam is one reviewable file:
#
#   1. runtime twins (the enforcement; the TTL in contracts/ is the spec)
#   2. profile-catalog entries (lookup; digests computed from the file)
#   3. ledger placements (mirrors note.create: the request is proposed,
#      everything BACK derives is canonical)
#   4. the RailsCpcp project (the wire method)
#
# Nothing here touches the substrate: no Grounding case, no RULES entry,
# no catalog constant. ADR 0063.
RailsOsiLevel8::Grounding.register_twin("Memory::LandEffectShape") do |graph|
  MemoryLand.request_violations(graph)
end

RailsOsiLevel8::Grounding.register_twin("Memory::LandContextShape") do |graph|
  MemoryLand.response_violations(graph)
end

memory_shapes = Rails.root.join("contracts/memory-operations.shacl.ttl").to_s
RailsOsiLevel8.config.profile_catalog.register(
  "Memory::LandEffectShape",
  path: memory_shapes,
  shape_iri: "https://w3id.org/cpcp/memory#MemoryLandEffectShape",
  profile_id: "osi-l8/p4-durable-execution@1"
)
RailsOsiLevel8.config.profile_catalog.register(
  "Memory::LandContextShape",
  path: memory_shapes,
  shape_iri: "https://w3id.org/cpcp/memory#MemoryLandContextShape",
  profile_id: "osi-l8/p4-durable-execution@1"
)

RailsOsiLevel8::LedgerPolicy.register(
  "memory.land",
  request: :sync_intent,
  receipt: :canonical,
  context: :canonical
)

RailsCpcp.project(model: "Memory") do
  operation "memory.land",
    direction: :push,
    params: %w[bytes session actor observed_at modality source_system kind],
    summary: "Land a Bronze memory episode: bytes to blob, episode to Bronze graph",
    via: RailsOsiLevel8::CpcpAdapter.wrap(
      operation: "memory.land",
      direction: :push,
      profiles: ["osi-l8/p4-durable-execution@1"],
      request_shape: "Memory::LandEffectShape",
      response_shape: "Memory::LandContextShape"
    ) { |p, _c| MemoryLand.call(p) }
end
