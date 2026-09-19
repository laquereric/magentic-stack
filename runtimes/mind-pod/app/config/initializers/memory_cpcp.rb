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
#
# Deferred to after_initialize on purpose: config/initializers/osi_level_8.rb
# ASSIGNS a fresh default catalog, and initializers run alphabetically, so a
# top-level registration here would land in an object that is replaced before
# the first request. After all initializers, the catalog is final.
Rails.application.config.after_initialize do
  RailsOsiLevel8::Grounding.register_twin("Memory::LandEffectShape") do |graph|
    MemoryLand.request_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::LandContextShape") do |graph|
    MemoryLand.response_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::ConformEffectShape") do |graph|
    MemoryConform.request_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::ConformContextShape") do |graph|
    MemoryConform.response_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::PromoteEffectShape") do |graph|
    MemoryPromote.request_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::PromoteContextShape") do |graph|
    MemoryPromote.response_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::ReadPullShape") do |graph|
    MemoryRead.request_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::ReadContextShape") do |graph|
    MemoryRead.response_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::ForgetEffectShape") do |graph|
    MemoryForget.request_violations(graph)
  end

  RailsOsiLevel8::Grounding.register_twin("Memory::ForgetContextShape") do |graph|
    MemoryForget.response_violations(graph)
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
  RailsOsiLevel8.config.profile_catalog.register(
    "Memory::ConformEffectShape",
    path: memory_shapes,
    shape_iri: "https://w3id.org/cpcp/memory#MemoryConformEffectShape",
    profile_id: "osi-l8/p4-durable-execution@1"
  )
  RailsOsiLevel8.config.profile_catalog.register(
    "Memory::ConformContextShape",
    path: memory_shapes,
    shape_iri: "https://w3id.org/cpcp/memory#MemoryConformContextShape",
    profile_id: "osi-l8/p4-durable-execution@1"
  )
  RailsOsiLevel8.config.profile_catalog.register(
    "Memory::PromoteEffectShape",
    path: memory_shapes,
    shape_iri: "https://w3id.org/cpcp/memory#MemoryPromoteEffectShape",
    profile_id: "osi-l8/p4-durable-execution@1"
  )
  RailsOsiLevel8.config.profile_catalog.register(
    "Memory::PromoteContextShape",
    path: memory_shapes,
    shape_iri: "https://w3id.org/cpcp/memory#MemoryPromoteContextShape",
    profile_id: "osi-l8/p4-durable-execution@1"
  )
  RailsOsiLevel8.config.profile_catalog.register(
    "Memory::ReadPullShape",
    path: memory_shapes,
    shape_iri: "https://w3id.org/cpcp/memory#MemoryReadPullShape",
    profile_id: "osi-l8/p4-durable-execution@1"
  )
  RailsOsiLevel8.config.profile_catalog.register(
    "Memory::ReadContextShape",
    path: memory_shapes,
    shape_iri: "https://w3id.org/cpcp/memory#MemoryReadContextShape",
    profile_id: "osi-l8/p4-durable-execution@1"
  )
  RailsOsiLevel8.config.profile_catalog.register(
    "Memory::ForgetEffectShape",
    path: memory_shapes,
    shape_iri: "https://w3id.org/cpcp/memory#MemoryForgetEffectShape",
    profile_id: "osi-l8/p4-durable-execution@1"
  )
  RailsOsiLevel8.config.profile_catalog.register(
    "Memory::ForgetContextShape",
    path: memory_shapes,
    shape_iri: "https://w3id.org/cpcp/memory#MemoryForgetContextShape",
    profile_id: "osi-l8/p4-durable-execution@1"
  )

  RailsOsiLevel8::LedgerPolicy.register(
    "memory.land",
    request: :sync_intent,
    receipt: :canonical,
    context: :canonical
  )

  RailsOsiLevel8::LedgerPolicy.register(
    "memory.conform",
    request: :sync_intent,
    receipt: :canonical,
    context: :canonical
  )

  RailsOsiLevel8::LedgerPolicy.register(
    "memory.promote",
    request: :sync_intent,
    receipt: :canonical,
    context: :canonical
  )

  RailsOsiLevel8::LedgerPolicy.register(
    "memory.forget",
    request: :sync_intent,
    receipt: :canonical,
    context: :canonical
  )

  # No placement for memory.read: pulls journal no receipt and consult no
  # placement (the journal hangs off an OperationRequest that only push
  # creates). Registering some would imply a read lands evidence.

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

    operation "memory.conform",
      direction: :push,
      params: %w[journal_ref],
      summary: "Conform a landed Bronze episode to Silver: resolve entities, close/open temporal facts",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "memory.conform",
        direction: :push,
        profiles: ["osi-l8/p4-durable-execution@1"],
        request_shape: "Memory::ConformEffectShape",
        response_shape: "Memory::ConformContextShape"
      ) { |p, _c| MemoryConform.call(p) }

    operation "memory.promote",
      direction: :push,
      params: %w[subject_iri],
      summary: "Promote a Silver subject to the Gold persona profile under model and contract",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "memory.promote",
        direction: :push,
        profiles: ["osi-l8/p4-durable-execution@1"],
        request_shape: "Memory::PromoteEffectShape",
        response_shape: "Memory::PromoteContextShape"
      ) { |p, _c| MemoryPromote.call(p) }

    operation "memory.read",
      direction: :pull,
      params: %w[frame budget_tokens],
      summary: "Serve a budgeted pack: frame activations plus memory recall, never a generation",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "memory.read",
        direction: :pull,
        profiles: ["osi-l8/p4-durable-execution@1"],
        request_shape: "Memory::ReadPullShape",
        response_shape: "Memory::ReadContextShape"
      ) { |p, _c| MemoryRead.call(p) }

    operation "memory.forget",
      direction: :push,
      params: %w[episode_iri retention_basis decided_by],
      summary: "Tombstone a Bronze episode and cascade Silver facts and Gold profiles",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "memory.forget",
        direction: :push,
        profiles: ["osi-l8/p4-durable-execution@1"],
        request_shape: "Memory::ForgetEffectShape",
        response_shape: "Memory::ForgetContextShape"
      ) { |p, _c| MemoryForget.call(p) }
  end
end
