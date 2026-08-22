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
    via: ->(p, _c) {
      RailsOsiLevel8::Profile9::Request.closed!(p || {}, [])
      RailsOsiLevel8::Profile9::Contract.describe
    }

  operation "ux.contract.check",
    direction: :pull, summary: "P9 closed-shape predicate check",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Contract.check(p) }

  operation "ux.acia.validate",
    direction: :pull, summary: "P9.1 ACIA document closed validation",
    via: ->(p, _c) {
      doc = p["document"] || p["acia"] || p
      r = RailsOsiLevel8::Profile9::Acia.validate(doc)
      raise RailsOsiLevel8::KnownRefusal.new(r.reason, r.because) unless r.conforms?
      r.to_h
    }

  operation "ux.render",
    direction: :pull, summary: "P9.2 RenderBundle → semantic HTML + receipt",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Renderer.render(p["bundle"] || p) }

  operation "ux.journey.list",
    direction: :pull, result: :collection, summary: "P9.3 actor-authorized Journey summaries",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Pulls.journey_list(p) }

  operation "ux.journey.get",
    direction: :pull, summary: "P9.3 Journey with phases/touchpoints",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Pulls.journey_get(p) }

  operation "ux.flow.get",
    direction: :pull, summary: "P9.3 Flow step contract and Page CIDs",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Pulls.flow_get(p) }

  operation "ux.page.get",
    direction: :pull, summary: "P9.3 PageRenderBundle",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Pulls.page_get(p) }

  operation "ux.inspect",
    direction: :pull, summary: "P9-BRD-02 inspect projection: new attested ACIA",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Pulls.inspect(p) }

  operation "ux.token.get",
    direction: :pull, summary: "P9.4 accepted DesignTokenSet",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Pulls.token_get(p) }

  operation "ux.token.set",
    direction: :push, summary: "P9.4 propose token-set successor",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Mutations.token_set(p) }

  operation "ux.acia.mutate.propose",
    direction: :push, summary: "P9.4 propose ACIA successor",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Mutations.acia_mutate_propose(p) }

  operation "ux.interaction.record",
    direction: :push, summary: "P9.4 record InteractionEvent",
    via: ->(p, _c) { RailsOsiLevel8::Profile9::Mutations.interaction_record(p) }
end

RailsCpcp.project(model: "OsiLevel8Profile11") do
  operation "meaning.profile.describe",
    direction: :pull, summary: "P11 method/shape introspection",
    via: ->(_p, _c) { RailsOsiLevel8::Profile11::Contract.describe }

  operation "meaning.contract.check",
    direction: :pull, summary: "P11 closed-shape record check",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Contract.check(p) }

  operation "meaning.concept.put",
    direction: :push, summary: "P11 append Concept",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_concept!(p) }

  operation "meaning.revision.put",
    direction: :push, summary: "P11 append DefinitionRevision",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_revision!(p) }

  operation "meaning.attestation.put",
    direction: :push, summary: "P11 append SemanticAttestation",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_attestation!(p) }

  operation "meaning.binding.put",
    direction: :push, summary: "P11 append OperationBinding",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_binding!(p) }

  operation "meaning.activation.put",
    direction: :push, summary: "P11 append SemanticActivation",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_activation!(p) }

  operation "meaning.dispute.put",
    direction: :push, summary: "P11 append SemanticDispute",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_dispute!(p) }

  operation "meaning.resolution.put",
    direction: :push, summary: "P11 append DisputeResolution",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_resolution!(p) }

  operation "meaning.translation.put",
    direction: :push, summary: "P11 append StewardshipTranslation",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_translation!(p) }

  operation "meaning.review.put",
    direction: :push, summary: "P11 append TranslationReview",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_review!(p) }

  operation "meaning.alignment.put",
    direction: :push, summary: "P11 append SemanticAlignmentAssertion",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_alignment!(p) }

  operation "meaning.federation.put",
    direction: :push, summary: "P11 append FederationAgreement",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_federation!(p) }

  operation "meaning.verification.put",
    direction: :push, summary: "P11 append SemanticVerificationEvidence",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Store.put_verification!(p) }

  operation "meaning.evaluate",
    direction: :push, summary: "P11 actability evaluation + receipt",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Evaluator.evaluate(p) }

  operation "meaning.receipt.reproduce",
    direction: :pull, summary: "P11 recompute a receipt from pins",
    via: ->(p, _c) { RailsOsiLevel8::Profile11::Evaluator.reproduce(p) }
end



# Profile 10 — INTENT Context PULLs (M4). private_local never disclosed.
RailsCpcp.project(model: "OsiLevel8Intent") do
  operation "intent.mission.get",
    direction: :pull, summary: "P10 Mission projection",
    via: ->(p, _c) { RailsOsiLevel8::Intent::Pulls.mission_get(p) }

  operation "intent.vision.get",
    direction: :pull, summary: "P10 Vision projection",
    via: ->(p, _c) { RailsOsiLevel8::Intent::Pulls.vision_get(p) }

  operation "intent.persona.list",
    direction: :pull, result: :collection, summary: "P10 Persona list",
    via: ->(p, _c) { RailsOsiLevel8::Intent::Pulls.persona_list(p) }

  operation "intent.stakeholder.list",
    direction: :pull, result: :collection, summary: "P10 Stakeholder list",
    via: ->(p, _c) { RailsOsiLevel8::Intent::Pulls.stakeholder_list(p) }

  operation "intent.value_proposition.list",
    direction: :pull, result: :collection, summary: "P10 Value Proposition list",
    via: ->(p, _c) { RailsOsiLevel8::Intent::Pulls.value_proposition_list(p) }

  operation "intent.segment.list",
    direction: :pull, result: :collection, summary: "P10 Market/Segment list",
    via: ->(p, _c) { RailsOsiLevel8::Intent::Pulls.segment_list(p) }

  operation "intent.goal.list",
    direction: :pull, result: :collection, summary: "P10 Goal list",
    via: ->(p, _c) { RailsOsiLevel8::Intent::Pulls.goal_list(p) }

  operation "intent.trace.for_effect",
    direction: :pull, summary: "P10 IntentTrace for Effect",
    via: ->(p, _c) { RailsOsiLevel8::Intent::Pulls.trace_for_effect(p) }
end


