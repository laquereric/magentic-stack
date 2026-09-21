# frozen_string_literal: true

# The CPCP projection: BACK's /_cpcp is the only CPCP write seam. BACKJOB writes
# Reconciliation locally (ADR 0056); it does not mount this engine.
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
    via: ->(p, c) { RailsOsiLevel8::Profile9::Pulls.page_get(FRONT_ACTOR.call(p, c)) }

  operation "ux.inspect",
    direction: :pull, summary: "P9-BRD-02 inspect projection: new attested ACIA",
    via: ->(p, c) { RailsOsiLevel8::Profile9::Pulls.inspect(FRONT_ACTOR.call(p, c)) }

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
    via: ->(p, c) { RailsOsiLevel8::Profile9::Mutations.interaction_record(FRONT_ACTOR.call(p, c)) }

  operation "ui.catalog.get",
    direction: :pull, summary: "Presentation + S2 task catalogs",
    via: ->(p, _c) { RailsOsiLevel8::Ui::Catalog.get(p) }

  operation "ui.surface.put",
    direction: :push, summary: "Compile and store a task surface from an information model",
    via: ->(p, _c) { RailsOsiLevel8::Ui::Surface.put(p) }

  operation "ui.surface.get",
    direction: :pull, summary: "Fetch a compiled task surface",
    via: ->(p, _c) { RailsOsiLevel8::Ui::Surface.get(p) }

  operation "ui.action",
    direction: :push, summary: "Journal a human action on a task surface; never closes Effect",
    via: ->(p, c) { RailsOsiLevel8::Ui::Action.call(FRONT_ACTOR.call(p, c)) }
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



# ---------------------------------------------------------------------------
# bpmn.* -- BPMN 2.0 / BBO spec and run rows (plan_vv-bpmn-bbo.md).
#
# ON BACK, NOT A NEW CONTAINER. These rows are domain state in the pod's
# SQLite, and ADR 0056 makes BACK and BACKJOB the writers with the journal as
# admission truth (ADR 0052). A fifteenth container named `bpmn` would be a
# store we do not have -- the store is the database BACK already owns -- and it
# would have to mount that SQLite alongside BACK, which is two writers on one
# file. So these register here, in the projection the engine already serves,
# rather than drawing a route of their own.
#
# §18 of the plan lists "CPCP bpmn.*" as out of v1. The owner asked for it,
# which supersedes that line. What does NOT change is §14's rule, and it is the
# one the seam is built around: neither store is a place to mint identity;
# (definition_key, version, element_id) and integer PKs are. BpmnSeam refuses an
# IRI as a key and derives spec_iri on the way out.
#
# WRITES. bpmn.deploy stays refused (no XML importer). bpmn.run.start stays
# refused for every definition_key except sdlc: vv-sdlc is the token engine
# for that process (AiSDLC.md). Starting "orders" still writes nothing.
require "bpmn_seam"
require "perch_seam"

# The seam is framework-free on purpose -- it returns {status:, json:} so
# check_bpmn.py can drive it against an in-memory SQLite with no Rails boot.
# This adapter is the only place that knows about the engine: a refusal becomes
# the KnownRefusal the dispatcher already understands, so bpmn.* refusals travel
# the same path every other refusal on BACK does rather than inventing a second
# one.
# The bearer travels from the Authorization HEADER, never from the JSON-RPC
# params -- vault's rule (ADR 0046), for the reason that a caller-supplied
# identity is not an identity. `ctx` is the controller, which is exactly what
# rails-cpcp hands a handler so auth can live here rather than in the engine.
BPMN_BEARER = lambda do |ctx|
  header = ctx.respond_to?(:request) ? ctx.request.headers["Authorization"].to_s : ""
  header =~ /\ABearer\s+(.+)\z/i ? Regexp.last_match(1).strip : nil
end

# THE ACTOR COMES FROM THE BEARER, NOT FROM THE BODY.
#
# plan_proven_actor.md S1 stopped the substrate inventing an actor when the
# caller named none. It did not stop the caller naming ANY resolvable actor:
# require_cid! proves a CID is present and resolves, not that the caller is it.
# That was the remaining half of G13 and this closes it for this BACK.
#
# Same mechanism as bpmn.claim, deliberately. ActorBinding already answers
# "which Actor is this caller" the way vault does (ADR 0046): the bearer is a
# HEADER, the map is the operator's, and absent/empty/unparseable is a refusal
# rather than an anonymous caller. G13's move says do not invent a second
# identity plane, so this reuses that one rather than adding a FRONT-shaped
# twin. FRONT_ACTORS is {"<token>": {"actor_cid": "cid:actor:...", "label": ...}}.
#
# The bearer here is X-Front-Token, which is what front-base's proxy forwards;
# bpmn reads Authorization. Both are headers. Neither is a parameter.
#
# WHAT THIS IS NOT, stated because the word "proven" invites more than it earns:
# the pod still has no authentication (ADR 0040 says so in Session's own
# doctrine). Whoever holds a token IS that actor. What changes is that the
# OPERATOR decides which actor a token is, and the caller cannot name a
# different one -- the same standing vault's callers have.
FRONT_BEARER = lambda do |ctx|
  return nil unless ctx.respond_to?(:request)

  token = ctx.request.headers["X-Front-Token"].to_s.strip
  token.empty? ? nil : token
end

# Returns params with actorCid set from the binding, or raises the refusal.
FRONT_ACTOR = lambda do |params, ctx|
  params = params || {}
  binding = ActorBinding.from_env(ENV["FRONT_ACTORS"])
  bound = binding.resolve!(FRONT_BEARER.call(ctx))
  binding.reconcile_cid!(bound, params["actorCid"])
  params.merge("actorCid" => bound.actor_cid)
rescue ActorBinding::Error => e
  raise ::RailsOsiLevel8::KnownRefusal.new(e.reason, e.because)
end

BPMN_CALL = lambda do |method, params, ctx = nil|
  out = BpmnSeam.new(bearer: BPMN_BEARER.call(ctx)).call(method, params || {})
  body = out[:json]
  if body["ok"] == false
    raise ::RailsOsiLevel8::KnownRefusal.new(body["reason"], body["because"])
  end

  body["result"]
end

RailsCpcp.project(model: "BpmnDefinition") do
  operation "bpmn.definitions",
    direction: :pull, result: :collection,
    summary: "Packages and the versions under them",
    via: ->(p, c) { BPMN_CALL.call("bpmn.definitions", p, c) }

  operation "bpmn.definition",
    direction: :pull, params: %w[definition_key],
    summary: "One definition version and its flow nodes (latest when version is omitted)",
    via: ->(p, c) { BPMN_CALL.call("bpmn.definition", p, c) }

  operation "bpmn.node",
    direction: :pull, params: %w[definition_key element_id],
    summary: "One flow node by (definition_key, version, element_id)",
    via: ->(p, c) { BPMN_CALL.call("bpmn.node", p, c) }

  operation "bpmn.run.stat",
    direction: :pull,
    summary: "Run instance counts; absent version refuses, unrun version reports zero",
    via: ->(p, c) { BPMN_CALL.call("bpmn.run.stat", p, c) }

  operation "bpmn.jobs",
    direction: :pull,
    summary: "Open/claimed run jobs (optional process_instance_id)",
    via: ->(p, c) { BPMN_CALL.call("bpmn.jobs", p, c) }

  operation "bpmn.seed_sdlc",
    direction: :push, params: %w[operationId],
    summary: "Seed definition_key=sdlc AgentTask process (idempotent)",
    via: ->(p, c) { BPMN_CALL.call("bpmn.seed_sdlc", p, c) }

  operation "bpmn.claim",
    direction: :push, params: %w[operationId job_id actor_id],
    summary: "Claim HumanReview for a Vv::Base::Actor",
    via: ->(p, c) { BPMN_CALL.call("bpmn.claim", p, c) }

  operation "bpmn.complete",
    direction: :push, params: %w[operationId job_id],
    summary: "Complete the current job; user tasks must be claimed",
    via: ->(p, c) { BPMN_CALL.call("bpmn.complete", p, c) }

  operation "bpmn.deploy",
    direction: :push, params: %w[definition_key],
    summary: "REFUSED bpmn_write_undecided: v1 is schema-only, there is no XML importer",
    via: ->(p, c) { BPMN_CALL.call("bpmn.deploy", p, c) }

  operation "bpmn.run.start",
    direction: :push, params: %w[definition_key],
    summary: "Start a run. sdlc is the token engine; any other key refuses bpmn_write_undecided",
    via: ->(p, c) { BPMN_CALL.call("bpmn.run.start", p, c) }
end

PERCH_CALL = lambda do |method, params, ctx = nil|
  out = PerchSeam.new(bearer: BPMN_BEARER.call(ctx)).call(method, params || {})
  body = out[:json]
  if body["ok"] == false
    raise ::RailsOsiLevel8::KnownRefusal.new(body["reason"], body["because"])
  end

  body["result"]
end

RailsCpcp.project(model: "PerchSlice") do
  operation "perch.slice.size",
    direction: :pull, params: %w[uc_id],
    summary: "T1–T8 findings; floor failures refuse",
    via: ->(p, c) { PERCH_CALL.call("perch.slice.size", p, c) }

  operation "perch.slice.status",
    direction: :pull, params: %w[uc_id slice_key],
    summary: "Computed gate / group / signal triple; pending is not zero",
    via: ->(p, c) { PERCH_CALL.call("perch.slice.status", p, c) }

  operation "perch.slice.restate",
    direction: :push, params: %w[operationId uc_id slice_key aim receiver],
    summary: "T4: bound Actor restates Aim and Receiver",
    via: ->(p, c) { PERCH_CALL.call("perch.slice.restate", p, c) }

  operation "perch.freeze.cascade",
    direction: :pull, params: %w[freeze_id],
    summary: "Current cascade cost of a freeze; not the stored climb record",
    via: ->(p, c) { PERCH_CALL.call("perch.freeze.cascade", p, c) }

  operation "perch.orphan.open",
    direction: :pull,
    summary: "Open orphan-ledger entries and their parties",
    via: ->(p, c) { PERCH_CALL.call("perch.orphan.open", p, c) }

  operation "perch.signal.report",
    direction: :pull, params: %w[uc_id slice_key],
    summary: "Readings with maturity; pending is not a fail",
    via: ->(p, c) { PERCH_CALL.call("perch.signal.report", p, c) }

  operation "perch.release",
    direction: :push, params: %w[operationId group_key],
    summary: "ReleaseGroup#release! bound to ActorBinding",
    via: ->(p, c) { PERCH_CALL.call("perch.release", p, c) }
end

# ProcedureRepo / SelfLearn / Ornith / Canvas / Browser / CalCom. Gems
# auto-register via Railtie when loaded; this is the explicit BACK face
# if the Railtie is not in GEM_HOME yet.
Vv::CodeRepo::Cpcp.register! if defined?(Vv::CodeRepo::Cpcp)
Vv::SelfLearn::Cpcp.register! if defined?(Vv::SelfLearn::Cpcp)
Vv::Orinth::Cpcp.register! if defined?(Vv::Orinth::Cpcp)
Vv::Canvas::Cpcp.register! if defined?(Vv::Canvas::Cpcp)
Vv::Browser::Cpcp.register! if defined?(Vv::Browser::Cpcp)
Vv::CalCom::Cpcp.register! if defined?(Vv::CalCom::Cpcp)
Vv::PerSite::Cpcp.register! if defined?(Vv::PerSite::Cpcp)
