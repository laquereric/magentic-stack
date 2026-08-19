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
        osi-l8/p4-durable-execution@1
        osi-l8/p5-biography-provenance@1
      ],
      request_shape: "P1::NoteCreateEffectShape",
      response_shape: "P1::NoteCreateContextShape"
    ) { |p, _c| Note.create!(title: p["title"], body: p["body"]).as_api }
end

RailsCpcp.project(model: "Reconciliation") do
  operation "reconciliation.latest", direction: :pull, summary: "Latest BACKJOB reconciliation",
    via: ->(_p, _c) { Reconciliation.order(created_at: :desc).first&.as_api || {} }
end

# Level 8 governance PULLs (Milestone 1). Always .cross_boundary — private_local never emitted.
RailsCpcp.project(model: "OsiLevel8") do
  operation "l8.context.list",
    direction: :pull, result: :collection, summary: "P1 Context timeline",
    via: ->(p, _c) { RailsOsiLevel8::Projections.context_list(p) }

  operation "l8.cyborg_channel.list",
    direction: :pull, result: :collection, summary: "P1 Cyborg/channel card",
    via: ->(p, _c) { RailsOsiLevel8::Projections.cyborg_channel_list(p) }

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
end
