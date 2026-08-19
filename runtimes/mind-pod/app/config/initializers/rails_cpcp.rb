# frozen_string_literal: true

# The CPCP projection: BACK's /_cpcp seam is the ONLY write path (sole writer).
RailsCpcp.base_iri = ENV.fetch("BASE_IRI", "https://mind-pod.local")

RailsCpcp.project(model: "Note") do
  operation "note.list",
    direction: :pull,
    result: :collection,
    summary: "List notes",
    via: RailsOsiLevel8::CpcpAdapter.wrap(
      operation: "note.list",
      direction: :pull,
      profiles: ["osi-l8/p1/cyborg-channel@1"],
      request_shape: "P1::NoteListPullShape",
      response_shape: "P1::NoteListContextShape"
    ) { |_p, _c| Note.order(created_at: :desc).limit(50).map(&:as_api) }

  operation "note.get", direction: :pull, params: %w[id], summary: "Get one note",
    via: ->(p, _c) { Note.find(p["id"]).as_api }

  operation "note.create",
    direction: :push,
    params: %w[title body],
    summary: "Create a note",
    via: RailsOsiLevel8::CpcpAdapter.wrap(
      operation: "note.create",
      direction: :push,
      profiles: %w[
        osi-l8/p1/cyborg-channel@1
        osi-l8/p2/reference-passing@1
        osi-l8/p3-switchyard-routing@1
        osi-l8/p4-durable-execution@1
        osi-l8/p5-biography-provenance@1
        osi-l8/p6-authorization-evidence@1
      ],
      request_shape: "P1::NoteCreateEffectShape",
      response_shape: "P1::NoteCreateContextShape"
    ) { |p, _c| Note.create!(title: p["title"], body: p["body"]).as_api }
end

RailsCpcp.project(model: "Reconciliation") do
  operation "reconciliation.latest", direction: :pull, summary: "Latest BACKJOB reconciliation",
    via: ->(_p, _c) { Reconciliation.order(created_at: :desc).first&.as_api || {} }
end

# Level 8 governance PULLs + P7/P8 commands. Always .cross_boundary on reads.
RailsCpcp.project(model: "OsiLevel8") do
  operation "l8.context.list",
    direction: :pull, result: :collection, summary: "P1 Context timeline",
    via: ->(p, _c) { RailsOsiLevel8::Projections.context_list(p) }

  operation "l8.cyborg_channel.list",
    direction: :pull, result: :collection, summary: "P1 Cyborg/channel card",
    via: ->(p, _c) { RailsOsiLevel8::Projections.cyborg_channel_list(p) }

  operation "l8.reference.list",
    direction: :pull, result: :collection, summary: "P2 reference-passing",
    via: ->(p, _c) { RailsOsiLevel8::Projections.reference_list(p) }

  operation "l8.routing.list",
    direction: :pull, result: :collection, summary: "P3 SwitchYard route",
    via: ->(p, _c) { RailsOsiLevel8::Projections.routing_list(p) }

  operation "l8.operation.journal",
    direction: :pull, result: :collection, summary: "P4 effect journal",
    via: ->(p, _c) { RailsOsiLevel8::Projections.operation_journal(p) }

  operation "l8.execution.receipt.list",
    direction: :pull, result: :collection, summary: "P4 durable-execution receipts",
    via: ->(p, _c) { RailsOsiLevel8::Projections.execution_receipt_list(p) }

  operation "l8.biography.get",
    direction: :pull, result: :collection, params: %w[subject_iri],
    summary: "P5 biography timeline",
    via: ->(p, _c) { RailsOsiLevel8::Projections.biography_get(p) }

  operation "l8.provenance.list",
    direction: :pull, result: :collection, summary: "P5 provenance adjacency",
    via: ->(p, _c) { RailsOsiLevel8::Projections.provenance_list(p) }

  operation "l8.authorization.list",
    direction: :pull, result: :collection, summary: "P6 authorization evidence",
    via: ->(p, _c) { RailsOsiLevel8::Projections.authorization_list(p) }

  operation "l8.observation.list",
    direction: :pull, result: :collection, summary: "P7 observations",
    via: ->(p, _c) { RailsOsiLevel8::Projections.observation_list(p) }

  operation "l8.outcome.list",
    direction: :pull, result: :collection, summary: "P7 outcomes",
    via: ->(p, _c) { RailsOsiLevel8::Projections.outcome_list(p) }

  operation "l8.learning.list",
    direction: :pull, result: :collection, summary: "P8 learning loop",
    via: ->(p, _c) { RailsOsiLevel8::Projections.learning_list(p) }

  operation "l8.drift.list",
    direction: :pull, result: :collection, summary: "P8 drift log",
    via: ->(p, _c) { RailsOsiLevel8::Projections.drift_list(p) }

  operation "l8.profile_evidence.list",
    direction: :pull, result: :collection, summary: "Cross-profile evidence index",
    via: ->(p, _c) { RailsOsiLevel8::Projections.profile_evidence_list(p) }

  operation "l8.observation.record",
    direction: :push, params: %w[observationKind], summary: "P7 record observation",
    via: ->(p, _c) { RailsOsiLevel8::P7Commands.observation_record!(p) }

  operation "l8.outcome.record",
    direction: :push, params: %w[effectCid], summary: "P7 record outcome",
    via: ->(p, _c) { RailsOsiLevel8::P7Commands.outcome_record!(p) }

  operation "l8.execution.complete",
    direction: :push, params: %w[operationRequestCid], summary: "P4/P7 durable completion",
    via: ->(p, _c) { RailsOsiLevel8::P7Commands.execution_complete!(p) }

  operation "l8.learning.record",
    direction: :push, params: %w[eventKind], summary: "P8 learning/drift event",
    via: ->(p, _c) { RailsOsiLevel8::Learning.record!(p) }
end

# Profile 9 — GHIS contract (M0): introspection + closed-predicate check. No new route.
RailsCpcp.project(model: "OsiLevel8Profile9") do
  operation "ux.profile.describe",
    direction: :pull, summary: "P9 method/shape introspection",
    via: ->(_p, _c) { RailsOsiLevel8::Profile9::Contract.describe }

  operation "ux.contract.check",
    direction: :pull, summary: "P9 closed-shape predicate check",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Contract.check(p) }
end

