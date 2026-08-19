---
title: "Build Brief: Governed rails-osi-level-8 Integration for mind-pod"
source: manus
manus_task_url: https://manus.im/app/CZWYyQbVS2nrnhJhg2W6G4
note: Authored by the Manus cloud agent; implementation guidance, not independently verified.
---

# Build Brief: Governed `rails-osi-level-8` Integration for mind-pod

**Author:** Manus AI  
**Target:** the existing Rails 8 mind-pod, deployed as `ROLE=BACK`, `ROLE=FRONT`, and `ROLE=BACKJOB` from one image  
**Decision:** make Level 8 an additive, namespaced persistence-and-decoration layer inside BACK. Its only network surface remains the existing `POST /_cpcp/rpc` CPCP dispatcher. FRONT reads only materialized governance projections through CPCP PULLs; it has no database configuration, model use, Graph access, or write path.

> Non-negotiable invariant: no record whose `ledger_placement = "private_local"` is serialized by a CPCP PULL. The filter lives in BACK’s projection repository, not in the FRONT client, so a caller cannot bypass it with parameters.

The design uses `OsiLevel8` as the engine namespace and `osi_l8_` as the table prefix. If the scaffold already names its Ruby namespace differently, perform a mechanical rename only; retain the table names, protocol names, profile identifiers, and behavior below. A Rails engine is appropriately used as a host-app enhancement with isolated model names and migrations, rather than a second application or an extra HTTP API.[1]

## 1. Installation and role boundary

Add the engine to the existing image and install its migrations into the one SQLite database used by BACK. Do not mount a Level 8 controller and do not add any Level 8 route. `rails-cpcp` continues to own the only dispatcher route.

```ruby
# Gemfile
 gem "rails-cpcp"
 gem "rails-osi-level-8", path: "engines/rails-osi-level-8" # or the pinned git ref
```

```ruby
# config/initializers/osi_level_8.rb
OsiLevel8.configure do |config|
  config.role = ENV.fetch("ROLE")
  config.cpcp_path = "/_cpcp/rpc"
  config.shape_root = Rails.root.join("engines/rails-osi-level-8/data/osi-level-8")
  config.profile_catalog = OsiLevel8::ProfileCatalog.default
  config.public_ledgers = %w[canonical sync_intent].freeze
  config.private_ledger = "private_local"
  config.clock = -> { Time.current }
end

Rails.application.config.to_prepare do
  # Register the decorator only in the HTTP writer. FRONT receives no AR repository.
  OsiLevel8::CpcpAdapter.install!(RailsCpcp) if ENV.fetch("ROLE") == "BACK"
end
```

| Process | May use Active Record? | May write Level 8 data? | Required behavior |
|---|---:|---:|---|
| `BACK` | Yes | Yes | Owns all authoritative Level 8 admission, ledger assignment, domain mutations, receipts, and PULL projection. |
| `FRONT` | **No** | **No** | Uses a small HTTP CPCP client only. It does not load `OsiLevel8` models, connect to SQLite, or contact GRAPH. |
| `BACKJOB` | Only queue infrastructure, if already required | **No authoritative L8 writes** | Executes a durable work item and submits `l8.execution.complete` as a CPCP PUSH to BACK. It never calls an L8 model directly. |
| `MIND` | No | No | Proposes shaped Effects to BACK through the same CPCP endpoint. |
| `GRAPH` | Not from FRONT | No | May be used by BACK while forming a validation data graph; it is not the source of the governance read model. |

This interpretation preserves “BACK is the sole writer” literally: `BACKJOB` can share the volume for its existing queue implementation, but it must not write a governing record or the domain database directly. Its completion reaches BACK through the already-approved seam and is admitted by the same wrapper.

## 2. Profile IDs, ledger policy, and shared record contract

Use the following stable profile IDs. The profile ID is versioned separately from the source file digest, so a shape correction can be demonstrated without silently changing the meaning of past evidence.

| Profile | `profile_id` | Shape source | Default placement | Purpose |
|---|---|---|---|---|
| 1. Cyborg Channel | `osi-l8/p1/cyborg-channel@1` | `profile-1-cyborg-channel.ttl` | `canonical` | A named Cyborg, its channel, and the Context it can read. |
| 2. Reference-Passing | `osi-l8/p2/reference-passing@1` | `profile-2-reference-passing.ttl` | `sync_intent` | A non-secret, integrity-bound reference passed in an Effect. |
| 3. SwitchYard Routing | `osi-l8/p3-switchyard-routing@1` | `profile-3-switchyard-routing.ttl` | `canonical` | Route decision and hop evidence. |
| 4. Durable Cyborg Execution | `osi-l8/p4-durable-execution@1` | `profile-4-durable-execution.ttl` | `sync_intent` for an admitted request; `canonical` for final receipt | Idempotency, state transition, and completion receipt. |
| 5. Biography & Provenance | `osi-l8/p5-biography-provenance@1` | `profile-5-biography-provenance.ttl` | `canonical` | Actor biography events and derivation/attribution edges. |
| 6. Enterprise Authorization Evidence | `osi-l8/p6-authorization-evidence@1` | `profile-6-authorization-evidence.ttl` | `canonical` redacted evidence; `private_local` evaluator detail | Decision evidence without credentials or unredacted policy inputs. |
| 7. Observation & Outcome | `osi-l8/p7-observation-outcome@1` | `profile-7-observation-outcome.ttl` | `canonical` | Measured observation and the outcome attributed to an Effect. |
| 8. Architectural Learning Loop | `osi-l8/p8-architectural-learning@1` | `profile-8-architectural-learning.ttl` | `canonical` | Drift finding, hypothesis, and recorded learning decision. |

Every Level 8 evidence row has these fields, enforced by the model concern and migration helper:

```ruby
# app/models/osi_level_8/concerns/governed_record.rb
module OsiLevel8::GovernedRecord
  extend ActiveSupport::Concern

  PLACEMENTS = %w[canonical sync_intent private_local].freeze

  included do
    validates :cid, :profile_id, :ledger_placement, :payload_digest, :recorded_at, presence: true
    validates :ledger_placement, inclusion: { in: PLACEMENTS }
    validates :cid, uniqueness: true
    validate :provenance_is_an_object
    before_update  { errors.add(:base, "append-only"); throw(:abort) }
    before_destroy { errors.add(:base, "append-only"); throw(:abort) }
  end

  private

  def provenance_is_an_object
    errors.add(:provenance_json, "must be an object") unless provenance_json.is_a?(Hash)
  end
end
```

The `cid` is a globally unique content identifier for the semantic record as admitted. `payload_digest` is the SHA-256 digest of the canonical JSON-LD serialization used to produce that CID. `provenance_cid` points to the immediately prior evidence/context CID when one exists. `provenance_json` contains a compact, non-secret envelope such as `{ "agent_iri" => "mind:processor/1", "received_from" => "cyborg:mind", "received_at" => "..." }`; raw bearer tokens, policy source text, and secrets are prohibited.

`LedgerPolicy` assigns placement from the registered operation and evidence class; it **never accepts a client-supplied placement**. The only permitted input is an optional requested public sharing class, which can only narrow visibility. Unknown fields, wrong profile, or a request to export `private_local` causes a refusal.

```ruby
# app/services/osi_level_8/ledger_policy.rb
class OsiLevel8::LedgerPolicy
  RULES = {
    "note.create"           => { request: :sync_intent, receipt: :canonical },
    "l8.execution.complete" => { receipt: :canonical, outcome: :canonical },
    "l8.observation.record" => { observation: :canonical },
    "l8.learning.record"    => { learning: :canonical },
    "authorization.trace"   => { detail: :private_local, summary: :canonical }
  }.freeze

  def self.placement_for!(operation:, evidence:)
    RULES.fetch(operation).fetch(evidence).to_s
  end
end
```

## 3. Active Record schema

### 3.1 Migration list

Use timestamped migrations in the engine and copy/run them only against BACK’s database. The exact timestamp is not material; the ordering is.

| Order | Migration file | Creates | Why it is first/next |
|---:|---|---|---|
| 01 | `20260819090001_create_osi_l8_contexts.rb` | `osi_l8_contexts` | The Context CID is the root of most later evidence. |
| 02 | `20260819090002_create_osi_l8_cyborg_channels.rb` | `osi_l8_cyborg_channels` | Profile 1 channel identity. |
| 03 | `20260819090003_create_osi_l8_reference_passes.rb` | `osi_l8_reference_passes` | Profile 2 append-only reference events. |
| 04 | `20260819090004_create_osi_l8_routing_decisions.rb` | `osi_l8_routing_decisions` | Profile 3 routing decision evidence. |
| 05 | `20260819090005_create_osi_l8_routing_hops.rb` | `osi_l8_routing_hops` | Profile 3 hop-level evidence. |
| 06 | `20260819090006_create_osi_l8_operation_requests.rb` | `osi_l8_operation_requests` | Profile 4 idempotency anchor. |
| 07 | `20260819090007_create_osi_l8_operation_journal_entries.rb` | `osi_l8_operation_journal_entries` | Profile 4 immutable lifecycle journal. |
| 08 | `20260819090008_create_osi_l8_execution_receipts.rb` | `osi_l8_execution_receipts` | Profile 4 final durable receipt. |
| 09 | `20260819090009_create_osi_l8_biography_events.rb` | `osi_l8_biography_events` | Profile 5 actor timeline. |
| 10 | `20260819090010_create_osi_l8_provenance_edges.rb` | `osi_l8_provenance_edges` | Profile 5 relationship/derivation evidence. |
| 11 | `20260819090011_create_osi_l8_authorization_evidences.rb` | `osi_l8_authorization_evidences` | Profile 6 evaluator and decision evidence. |
| 12 | `20260819090012_create_osi_l8_observations.rb` | `osi_l8_observations` | Profile 7 measured facts. |
| 13 | `20260819090013_create_osi_l8_outcomes.rb` | `osi_l8_outcomes` | Profile 7 attributable results. |
| 14 | `20260819090014_create_osi_l8_learning_events.rb` | `osi_l8_learning_events` | Profile 8 learning-loop events and drift findings. |
| 15 | `20260819090015_create_osi_l8_profile_evidences.rb` | `osi_l8_profile_evidences` | A typed cross-profile evidence index, not a replacement for the profile tables. |
| 16 | `20260819090016_create_osi_l8_admission_attempts.rb` | `osi_l8_admission_attempts` | Private-local, append-only refusal/audit record. |
| 17 | `20260819090017_add_osi_l8_append_only_triggers.rb` | SQLite triggers | Defense in depth against updates/deletes outside Rails. |

### 3.2 Common migration helpers

The migrations use `json` as Rails’ logical JSON type; under SQLite it is stored as text. All JSON is canonicalized before hashing. This is deliberate: SQLite is the existing store, not a reason to make unstructured blobs the public read contract.

```ruby
# db/migrate/concerns/osi_l8_migration_helpers.rb
module OsiL8MigrationHelpers
  def governed_columns(t)
    t.string   :cid,              null: false
    t.string   :profile_id,       null: false
    t.string   :ledger_placement, null: false
    t.string   :provenance_cid
    t.json     :provenance_json,  null: false, default: {}
    t.string   :payload_digest,   null: false
    t.datetime :recorded_at,      null: false
    t.timestamps null: false
  end

  def governed_indexes(table)
    add_index table, :cid, unique: true
    add_index table, [:profile_id, :ledger_placement, :recorded_at], name: "idx_#{table}_profile_ledger_time"
    add_index table, :provenance_cid
    add_check_constraint table,
      "ledger_placement IN ('canonical','sync_intent','private_local')",
      name: "chk_#{table}_ledger_placement"
  end
end
```

Each creation migration includes this module, calls `governed_columns(t)`, adds the table-specific fields below, and then calls `governed_indexes(:table_name)`. The last migration creates a `BEFORE UPDATE` and `BEFORE DELETE` SQLite trigger for every table marked **append-only**. The Rails concern provides normal-path protection; the triggers are the database backstop. All adapter persistence uses non-bang `save`/`create` and translates a failure into a never-raise envelope.

### 3.3 Exact tables, columns, and indexes

All tables in this matrix include the shared governed fields shown above. “Append-only” means create only: revisions are new CIDs with an explicit `supersedes_cid`, never updates.

| Table / model | Profile | Table-specific columns | Indexes beyond shared indexes | Append-only |
|---|---|---|---|---:|
| `osi_l8_contexts` / `OsiLevel8::Context` | P1 | `subject_iri:string` (not null), `context_kind:string` (not null; `request`, `response`, `state`, `projection`), `jsonld:json` (not null), `graph_iri:string`, `shape_id:string` (not null), `shape_digest:string` (not null), `admitted_at:datetime` (not null), `supersedes_cid:string` | unique `payload_digest`; `[:subject_iri, :context_kind, :admitted_at]`; `supersedes_cid` | Yes |
| `osi_l8_cyborg_channels` / `OsiLevel8::CyborgChannel` | P1 | `cyborg_iri:string` (not null), `channel_key:string` (not null), `counterparty_iri:string`, `direction:string` (not null; `inbound`, `outbound`, `bidirectional`), `transport:string` (not null; `cpcp`), `channel_status:string` (not null), `contract_context_cid:string`, `capabilities_json:json` (not null, default `{}`) | unique `[:cyborg_iri, :channel_key, :payload_digest]`; `[:cyborg_iri, :recorded_at]`; `contract_context_cid` | Yes |
| `osi_l8_reference_passes` / `OsiLevel8::ReferencePass` | P2 | `reference_id:string` (not null), `event_kind:string` (not null; `issued`, `passed`, `accepted`, `revoked`, `expired`), `reference_uri:string`, `target_cid:string`, `target_uri:string`, `integrity_digest:string`, `issuer_iri:string`, `holder_iri:string`, `recipient_iri:string`, `expires_at:datetime`, `access_descriptor_json:json` (not null, default `{}`) | `[:reference_id, :recorded_at]`; `target_cid`; `recipient_iri`; `expires_at` | Yes |
| `osi_l8_routing_decisions` / `OsiLevel8::RoutingDecision` | P3 | `route_key:string` (not null), `operation_request_cid:string` (not null), `effect_cid:string`, `chosen_target_iri:string` (not null), `chosen_channel_cid:string`, `policy_ref:string`, `decision:string` (not null; `routed`, `rejected`, `deferred`), `reason_code:string` (not null), `candidate_digest:string` | `[:operation_request_cid, :recorded_at]`; `route_key`; `chosen_target_iri` | Yes |
| `osi_l8_routing_hops` / `OsiLevel8::RoutingHop` | P3 | `routing_decision_cid:string` (not null), `hop_number:integer` (not null), `from_iri:string` (not null), `to_iri:string` (not null), `channel_cid:string`, `hop_status:string` (not null; `attempted`, `delivered`, `failed`), `started_at:datetime`, `ended_at:datetime`, `failure_code:string` | unique `[:routing_decision_cid, :hop_number]`; `channel_cid`; `to_iri` | Yes |
| `osi_l8_operation_requests` / `OsiLevel8::OperationRequest` | P4 | `operation_name:string` (not null), `direction:string` (not null; `push`), `idempotency_scope:string` (not null), `idempotency_key:string` (not null), `request_context_cid:string` (not null), `effect_cid:string`, `request_digest:string` (not null), `caller_iri:string`, `admission_status:string` (not null; `admitted` or `refused`) | unique `[:operation_name, :idempotency_scope, :idempotency_key]`; `effect_cid`; `request_context_cid` | Yes |
| `osi_l8_operation_journal_entries` / `OsiLevel8::OperationJournalEntry` | P4 | `operation_request_cid:string` (not null), `sequence:integer` (not null), `event_kind:string` (not null; `received`, `grounded`, `authorized`, `routed`, `dispatched`, `completed`, `refused`), `event_at:datetime` (not null), `detail_json:json` (not null, default `{}`), `receipt_cid:string` | unique `[:operation_request_cid, :sequence]`; `[:operation_request_cid, :event_at]`; `event_kind` | Yes |
| `osi_l8_execution_receipts` / `OsiLevel8::ExecutionReceipt` | P4 | `operation_request_cid:string` (not null), `effect_cid:string`, `execution_key:string` (not null), `status:string` (not null; `succeeded`, `failed`, `refused`), `result_context_cid:string`, `result_digest:string`, `completed_at:datetime` (not null), `failure_reason:string`, `replayed_from_receipt_cid:string` | unique `operation_request_cid`; unique `execution_key`; `effect_cid`; `completed_at` | Yes |
| `osi_l8_biography_events` / `OsiLevel8::BiographyEvent` | P5 | `subject_iri:string` (not null), `event_kind:string` (not null; `declared`, `role_asserted`, `capability_asserted`, `affiliation_asserted`, `retired`), `asserted_by_iri:string` (not null), `valid_from:datetime`, `valid_to:datetime`, `statement_json:json` (not null) | `[:subject_iri, :recorded_at]`; `asserted_by_iri`; `event_kind` | Yes |
| `osi_l8_provenance_edges` / `OsiLevel8::ProvenanceEdge` | P5 | `from_cid:string` (not null), `predicate:string` (not null; e.g. `prov:wasDerivedFrom`), `to_cid:string`, `to_iri:string`, `agent_iri:string`, `activity_cid:string`, `asserted_at:datetime` (not null) | `[:from_cid, :predicate]`; `to_cid`; `activity_cid` | Yes |
| `osi_l8_authorization_evidences` / `OsiLevel8::AuthorizationEvidence` | P6 | `operation_request_cid:string`, `principal_iri:string` (not null), `action:string` (not null), `resource_cid:string`, `resource_iri:string`, `policy_ref:string` (not null), `decision:string` (not null; `permit`, `deny`, `not_applicable`), `decided_at:datetime` (not null), `evidence_digest:string` (not null), `redacted_evidence_json:json` (not null, default `{}`), `evaluator_detail_json:json` (not null, default `{}`) | `[:principal_iri, :action, :decided_at]`; `operation_request_cid`; `policy_ref`; `decision` | Yes |
| `osi_l8_observations` / `OsiLevel8::Observation` | P7 | `observed_subject_cid:string`, `observed_subject_iri:string`, `observation_kind:string` (not null), `measured_at:datetime` (not null), `observer_iri:string` (not null), `value_json:json` (not null), `unit_iri:string`, `source_context_cid:string`, `quality_json:json` (not null, default `{}`) | `[:observed_subject_cid, :measured_at]`; `[:observation_kind, :measured_at]`; `source_context_cid` | Yes |
| `osi_l8_outcomes` / `OsiLevel8::Outcome` | P7 | `effect_cid:string` (not null), `operation_request_cid:string`, `outcome_kind:string` (not null), `status:string` (not null; `achieved`, `not_achieved`, `unknown`), `determined_at:datetime` (not null), `determiner_iri:string` (not null), `outcome_json:json` (not null), `basis_observation_cids:json` (not null, default `[]`), `supersedes_cid:string` | `[:effect_cid, :determined_at]`; `operation_request_cid`; `status`; `supersedes_cid` | Yes |
| `osi_l8_learning_events` / `OsiLevel8::LearningEvent` | P8 | `learning_cycle_id:string` (not null), `event_kind:string` (not null; `drift_detected`, `hypothesis_recorded`, `experiment_started`, `decision_recorded`, `profile_change_proposed`, `profile_change_accepted`, `profile_change_rejected`), `baseline_ref:string`, `observed_ref:string`, `severity:string`, `status:string` (not null; `open`, `accepted`, `rejected`, `superseded`), `subject_cid:string`, `evidence_cids:json` (not null, default `[]`), `proposal_json:json` (not null, default `{}`), `decided_by_iri:string` | `[:learning_cycle_id, :recorded_at]`; `[:event_kind, :status]`; `subject_cid`; `baseline_ref` | Yes |
| `osi_l8_profile_evidences` / `OsiLevel8::ProfileEvidence` | All | `subject_cid:string` (not null), `evidence_type:string` (not null), `evidence_cid:string` (not null), `operation_name:string`, `summary_json:json` (not null, default `{}`) | unique `[:subject_cid, :evidence_type, :evidence_cid]`; `evidence_cid`; `operation_name` | Yes |
| `osi_l8_admission_attempts` / `OsiLevel8::AdmissionAttempt` | Gateway audit | `operation_name:string` (not null), `direction:string` (not null), `request_cid:string`, `request_digest:string` (not null), `caller_iri:string`, `conforms:boolean` (not null), `refusal_reason:string`, `shape_id:string`, `shape_digest:string`, `report_json:json` (not null, default `{}`) | `[:operation_name, :recorded_at]`; `request_cid`; `conforms` | Yes, always `private_local` |

**Model list:** `Context`, `CyborgChannel`, `ReferencePass`, `RoutingDecision`, `RoutingHop`, `OperationRequest`, `OperationJournalEntry`, `ExecutionReceipt`, `BiographyEvent`, `ProvenanceEdge`, `AuthorizationEvidence`, `Observation`, `Outcome`, `LearningEvent`, `ProfileEvidence`, and `AdmissionAttempt`, all under `OsiLevel8`. Every one includes `GovernedRecord` except that `AdmissionAttempt` adds a validation forcing `ledger_placement == "private_local"`.

### 3.4 Associations and public projection scope

Use CID associations explicitly; do not manufacture integer foreign keys for externally meaningful CIDs.

```ruby
class OsiLevel8::OperationRequest < OsiLevel8::Record
  include OsiLevel8::GovernedRecord
  has_many :journal_entries, class_name: "OsiLevel8::OperationJournalEntry",
           primary_key: :cid, foreign_key: :operation_request_cid
  has_one :receipt, class_name: "OsiLevel8::ExecutionReceipt",
          primary_key: :cid, foreign_key: :operation_request_cid
end

class OsiLevel8::Record < ApplicationRecord
  self.abstract_class = true
  scope :cross_boundary, -> { where(ledger_placement: %w[canonical sync_intent]) }
  scope :for_profile, ->(id) { where(profile_id: id) }
end
```

All BACK read repositories begin with `.cross_boundary`. There is no `include_private`, `all_records`, or caller-controlled ledger filter in a CPCP PULL. Internal operational diagnostics use a separate admin-only Ruby service and never the CPCP public read surface.

## 4. CPCP decorator: one interception point, no new endpoint

### 4.1 Registration contract

Keep the existing projection DSL. The engine changes only the handler supplied to the CPCP operation declaration. The following is the concrete adapter contract to implement in the scaffold. If the current `RailsCpcp.project` uses a different handler keyword, map the proc to its existing callback slot; do **not** change the route, dispatcher, or envelope grammar.

```ruby
# app/services/osi_level_8/cpcp_adapter.rb
class OsiLevel8::CpcpAdapter
  def self.wrap(operation:, direction:, profiles:, request_shape:, response_shape:, &handler)
    new(operation:, direction:, profiles:, request_shape:, response_shape:, handler:).to_proc
  end

  def initialize(operation:, direction:, profiles:, request_shape:, response_shape:, handler:)
    @operation, @direction, @profiles = operation, direction.to_sym, profiles
    @request_shape, @response_shape, @handler = request_shape, response_shape, handler
  end

  def to_proc
    ->(cpcp_call) { call(cpcp_call) }
  end

  def call(cpcp_call)
    request = OsiLevel8::CpcpEnvelope.from(cpcp_call, operation: @operation, direction: @direction)
    return refuse("invalid_cpcp_envelope", request) unless request.valid?

    # Validates the inbound Context/Effect for BOTH PULL and PUSH.
    inbound = OsiLevel8::Grounding.validate(request.jsonld_graph, profile: @request_shape)
    return refuse_grounding(inbound, request) unless inbound.conforms?

    if @direction == :push
      OsiLevel8::Record.transaction do
        admission = admit_push!(request, inbound) # writes admission, request, journal, P5/P6/P2/P3 evidence
        return succeed_replay(request, admission.receipt) if admission.replay?

        domain_result = @handler.call(request) # existing Note/Reconciliation write
        return finalize_push!(request, domain_result)
      end
    else
      # A PULL is read-only. No journal, access log, or database mutation is created here.
      result = @handler.call(request)
      outbound = OsiLevel8::Grounding.validate(
        OsiLevel8::JsonLd.context_graph(result, cid: request.response_cid), profile: @response_shape
      )
      return refuse_grounding(outbound, request) unless outbound.conforms?
      succeed_collection_or_item(request, result, outbound)
    end
  rescue OsiLevel8::KnownRefusal => e
    refuse(e.reason, request, e.because)
  rescue StandardError => e
    Rails.logger.error(event: "osi_l8.adapter_error", operation: @operation,
                       cid: request&.cid, exception: e.class.name)
    refuse("processing_failed", request, { operation: @operation })
  end

  private

  def admit_push!(request, inbound)
    OsiLevel8::Admission.record_attempt!(request:, validation: inbound)
    replay = OsiLevel8::Idempotency.lookup(request)
    return OsiLevel8::Admission::Result.replay(replay) if replay

    OsiLevel8::Authorization.admit!(request) # P6; may raise KnownRefusal only
    OsiLevel8::EvidenceRecorder.record_inbound!(request:, validation: inbound)
    OsiLevel8::Routing.record_if_routed!(request) # P3 where a target route is present
    OsiLevel8::Admission::Result.admitted
  end

  def finalize_push!(request, domain_result)
    result_context = OsiLevel8::ContextFactory.response_for(request:, result: domain_result)
    validated = OsiLevel8::Grounding.validate(result_context.graph, profile: @response_shape)
    raise OsiLevel8::KnownRefusal.new("response_not_grounded", validated.safe_report) unless validated.conforms?

    receipt = OsiLevel8::EvidenceRecorder.record_completion!(
      request:, result_context:, validation: validated
    )
    succeed_item(request, domain_result, receipt:)
  end

  def refuse_grounding(validation, request)
    OsiLevel8::Admission.record_refusal!(request:, validation:) if @direction == :push
    refuse("grounding_refused", request, validation.safe_report)
  end

  def succeed_item(request, item, receipt: nil)
    { ok: true, result: { item:, governance: metadata(request, receipt:) } }
  end

  def succeed_collection_or_item(request, result, validation)
    payload = result.is_a?(Array) ? { items: result } : { item: result }
    { ok: true, result: payload.merge(governance: metadata(request, validation:)) }
  end

  def metadata(request, receipt: nil, validation: nil)
    { request_cid: request.cid, profile_ids: @profiles,
      receipt_cid: receipt&.cid, shape_digest: validation&.shape_digest }
  end

  def refuse(reason, request, because = {})
    { ok: false, error: { reason:, because: because.merge(request_cid: request&.cid, profile_ids: @profiles).compact } }
  end
end
```

The code treats errors as data at the CPCP boundary. Transaction errors, serialization errors, shape errors, and duplicate idempotency keys are caught and become `{ ok: false, error: { reason:, because: } }`; exception classes and stack traces go only to BACK logs. Do not use `raise` past the decorator.

### 4.2 PUSH sequence

For every PUSH, `CpcpAdapter.wrap` does the following in order.

1. It decodes the current CID-grounded JSON-RPC-LD request and derives the request CID/digest itself.
2. It selects the declared P1/P4/etc. request shape from the operation registry and validates the inbound graph.
3. It writes a `private_local` `AdmissionAttempt`. A failed validation writes only this compact, redacted audit event and returns a refusal. It does **not** write Context, Effect, provenance, authorization, or outcome evidence.
4. It derives ledger placement from `LedgerPolicy`; it does not copy `ledgerPlacement` from the caller.
5. It checks P4 idempotency by the unique `operation_name + idempotency_scope + idempotency_key`. A prior completed request returns its stored receipt as success and writes no duplicate domain fact.
6. It evaluates P6 authorization, writing a private evaluator detail and a public-safe permit/deny summary only when the summary itself is allowed to cross the boundary.
7. It creates the P1 Context, P4 `OperationRequest` and `OperationJournalEntry(received/grounded/authorized)`, then creates P2 references, P3 routing evidence, P5 biography/provenance edges, and `ProfileEvidence` index rows derived from the admitted Effect.
8. It calls the original CPCP operation handler inside the same BACK transaction. Only this handler mutates `Note`, `Reconciliation`, or another host model.
9. It shapes and validates the response Context, then writes the canonical P4 receipt and completion journal entry. An effect that carries measurements/declared outcomes also writes P7 rows. P8 is written only by its explicit learning command or a configured evaluator, not invented from incidental traffic.
10. It returns the original result plus governance CIDs and profile identities.

A routed async effect stops after durable admission and returns an admitted P4 receipt. `BACKJOB` eventually invokes the decorated `l8.execution.complete` CPCP PUSH, which appends `completed`/`failed` events, a new final P4 receipt, and P7 observation/outcome evidence. It still does not write the database itself.

### 4.3 Worked existing operations

`note.create` becomes a P1/P4/P5/P6-decorated PUSH, with P2/P3/P7 activated only if shaped fields are present. `note.list` becomes a P1 response-context PULL; it does not become a writer merely because the wrapper is present.

```ruby
# config/initializers/cpcp_projects.rb — BACK only
RailsCpcp.project(model: Note) do
  operation "note.create",
    direction: :push,
    result: :one,
    handler: OsiLevel8::CpcpAdapter.wrap(
      operation: "note.create",
      direction: :push,
      profiles: %w[
        osi-l8/p1/cyborg-channel@1 osi-l8/p4-durable-execution@1
        osi-l8/p5-biography-provenance@1 osi-l8/p6-authorization-evidence@1
      ],
      request_shape: "P1::NoteCreateEffectShape",
      response_shape: "P1::NoteCreateContextShape"
    ) do |call|
      note = Note.create!(body: call.params.fetch("body"))
      { cid: OsiLevel8::Cid.for(note), id: note.id, body: note.body, created_at: note.created_at.iso8601 }
    end

  operation "note.list",
    direction: :pull,
    result: :collection,
    handler: OsiLevel8::CpcpAdapter.wrap(
      operation: "note.list",
      direction: :pull,
      profiles: ["osi-l8/p1/cyborg-channel@1"],
      request_shape: "P1::NoteListPullShape",
      response_shape: "P1::NoteListContextShape"
    ) do |_call|
      Note.order(created_at: :desc).map { |note| { cid: OsiLevel8::Cid.for(note), id: note.id, body: note.body, created_at: note.created_at.iso8601 } }
    end
end
```

The exact DSL keyword used by the existing CPCP release for `handler:` is the only compatibility point. The wrapper’s input and output are intentionally ordinary `{ ok:, result: }` Ruby hashes, so it can be passed to a block/yield/proc callback without changing the dispatcher.

### 4.4 Required internal L8 PUSH commands

These are **operations on the existing CPCP endpoint**, not endpoints. They are necessary because P7 and P8 must have a legitimate producer and BACKJOB must report a durable completion through BACK.

| Operation | Producer | Profiles written | Purpose |
|---|---|---|---|
| `l8.execution.complete` | BACKJOB, MIND, or BACK | P4, P5, P7 | Report a shaped completion/failure for a previously admitted `operation_request_cid`. |
| `l8.observation.record` | MIND or BACK | P1, P5, P6, P7 | Admit a shaped observation, with authorization and provenance. |
| `l8.outcome.record` | MIND or BACK | P1, P5, P6, P7 | Attach a shaped attributable outcome to an effect. |
| `l8.learning.record` | BACK governance evaluator only | P5, P6, P8 | Record a drift finding, hypothesis, or learning decision. |

Each command is a normal decorated PUSH with a profile-specific Effect shape and a P4 idempotency key. FRONT does not call any of them in the POC.

## 5. BACK CPCP PULL projection catalogue

Every operation below is declared `direction: :pull, result: :collection`; `*.get` remains a collection to make an empty biography and a multi-event biography structurally consistent. Every repository applies `.cross_boundary` before filters and serializes a whitelist of fields, never `attributes`.

| CPCP PULL operation | Source models | Required filter parameters | Response item fields | FRONT use |
|---|---|---|---|---|
| `l8.context.list` | `Context` | `subject_iri?`, `context_kind?`, `since?`, `limit?` | `cid`, `profile_id`, `ledger_placement`, `subject_iri`, `context_kind`, `graph_iri`, `shape_id`, `shape_digest`, `admitted_at`, `provenance_cid`, `payload_digest` | P1 Context timeline. |
| `l8.cyborg_channel.list` | `CyborgChannel` | `cyborg_iri?`, `channel_key?` | `cid`, `cyborg_iri`, `channel_key`, `counterparty_iri`, `direction`, `transport`, `channel_status`, `capabilities_json`, `contract_context_cid` | P1 Cyborg/channel card. |
| `l8.reference.list` | `ReferencePass` | `reference_id?`, `target_cid?`, `holder_iri?` | `cid`, `reference_id`, `event_kind`, `reference_uri`, `target_cid`, `target_uri`, `integrity_digest`, `issuer_iri`, `holder_iri`, `recipient_iri`, `expires_at`, `recorded_at` | P2 reference-passing panel. `access_descriptor_json` is intentionally omitted. |
| `l8.routing.list` | `RoutingDecision`, `RoutingHop` | `operation_request_cid?`, `route_key?` | decision: `cid`, `route_key`, `chosen_target_iri`, `chosen_channel_cid`, `decision`, `reason_code`, `recorded_at`; hops: `routing_decision_cid`, `hop_number`, `from_iri`, `to_iri`, `hop_status`, `ended_at`, `failure_code` | P3 SwitchYard trace. |
| `l8.operation.journal` | `OperationRequest`, `OperationJournalEntry` | `operation_request_cid?`, `operation_name?`, `since?` | request CID, operation name, idempotency key **fingerprint only**, caller IRI, journal sequence/event/time, public detail, receipt CID | P4 effect journal. |
| `l8.execution.receipt.list` | `ExecutionReceipt` | `operation_request_cid?`, `execution_key?`, `since?` | `cid`, `operation_request_cid`, `effect_cid`, `execution_key`, `status`, `result_context_cid`, `completed_at`, `failure_reason`, `replayed_from_receipt_cid` | P4 durable-execution receipts. |
| `l8.biography.get` | `BiographyEvent` | `subject_iri` (required) | `cid`, `subject_iri`, `event_kind`, `asserted_by_iri`, `valid_from`, `valid_to`, `statement_json`, `recorded_at` | P5 biography timeline. |
| `l8.provenance.list` | `ProvenanceEdge` | `from_cid?`, `to_cid?`, `agent_iri?` | `cid`, `from_cid`, `predicate`, `to_cid`, `to_iri`, `agent_iri`, `activity_cid`, `asserted_at` | P5 provenance graph list. |
| `l8.authorization.list` | `AuthorizationEvidence` | `operation_request_cid?`, `principal_iri?`, `decision?` | `cid`, `operation_request_cid`, `principal_iri`, `action`, `resource_cid`, `resource_iri`, `policy_ref`, `decision`, `decided_at`, `evidence_digest`, `redacted_evidence_json` | P6 evidence panel. Never emits `evaluator_detail_json`. |
| `l8.observation.list` | `Observation` | `observed_subject_cid?`, `observation_kind?`, `since?` | `cid`, `observed_subject_cid`, `observed_subject_iri`, `observation_kind`, `measured_at`, `observer_iri`, `value_json`, `unit_iri`, `source_context_cid`, `quality_json` | P7 dashboard. |
| `l8.outcome.list` | `Outcome` | `effect_cid?`, `status?`, `since?` | `cid`, `effect_cid`, `operation_request_cid`, `outcome_kind`, `status`, `determined_at`, `determiner_iri`, `outcome_json`, `basis_observation_cids`, `supersedes_cid` | P7 dashboard. |
| `l8.learning.list` | `LearningEvent` | `learning_cycle_id?`, `status?`, `since?` | `cid`, `learning_cycle_id`, `event_kind`, `baseline_ref`, `observed_ref`, `severity`, `status`, `subject_cid`, `evidence_cids`, `proposal_json`, `decided_by_iri`, `recorded_at` | P8 learning loop. |
| `l8.drift.list` | `LearningEvent` where `event_kind = drift_detected` | `severity?`, `status?` | same public learning fields, sorted by `recorded_at DESC` | P8 drift log. |
| `l8.profile_evidence.list` | `ProfileEvidence` | `subject_cid?`, `profile_id?`, `evidence_type?` | `cid`, `profile_id`, `subject_cid`, `evidence_type`, `evidence_cid`, `operation_name`, `summary_json`, `recorded_at` | Detail drawer linking panels without DB access. |

A repository should be boring and explicit:

```ruby
# app/queries/osi_level_8/context_projection.rb
class OsiLevel8::ContextProjection
  FIELDS = %i[cid profile_id ledger_placement subject_iri context_kind graph_iri shape_id
              shape_digest admitted_at provenance_cid payload_digest].freeze

  def self.list(filters)
    rel = OsiLevel8::Context.cross_boundary.order(recorded_at: :desc)
    rel = rel.where(subject_iri: filters["subject_iri"]) if filters["subject_iri"].present?
    rel = rel.where(context_kind: filters["context_kind"]) if filters["context_kind"].present?
    rel.limit([filters.fetch("limit", 50).to_i, 200].min).map { |r| r.slice(*FIELDS) }
  end
end
```

The PULL wrapper validates the PULL request Context and the serialized response Context but does not create a read audit record. This preserves the CPCP meaning of PULL as a read and prevents a dashboard refresh from appearing as a business Effect.

## 6. FRONT: DBless ERB projection consumer

Implement one `GovernanceController` in FRONT plus partials. It is a server-rendered HTTP client; it does not require Active Record.

```ruby
# app/services/back_cpcp_client.rb — loaded in FRONT only
class BackCpcpClient
  def pull(operation, params = {})
    response = Net::HTTP.post(
      URI.join(ENV.fetch("BACK_CPCP_URL"), "/_cpcp/rpc"),
      JSON.generate(jsonrpc: "2.0", method: operation,
                    params: params.merge("direction" => "pull"), id: SecureRandom.uuid),
      "Content-Type" => "application/ld+json"
    )
    body = JSON.parse(response.body)
    return body if body["ok"] == true
    { "ok" => false, "error" => body.fetch("error") }
  rescue StandardError
    { "ok" => false, "error" => { "reason" => "back_unavailable", "because" => {} } }
  end
end
```

```ruby
# app/controllers/governance_controller.rb — FRONT
class GovernanceController < ApplicationController
  def show
    cpcp = BackCpcpClient.new
    @channels     = cpcp.pull("l8.cyborg_channel.list", { "cyborg_iri" => params[:cyborg_iri] })
    @contexts     = cpcp.pull("l8.context.list", { "subject_iri" => params[:cyborg_iri], "limit" => 25 })
    @references   = cpcp.pull("l8.reference.list", {})
    @routing      = cpcp.pull("l8.routing.list", {})
    @journal      = cpcp.pull("l8.operation.journal", { "limit" => 50 })
    @receipts     = cpcp.pull("l8.execution.receipt.list", { "limit" => 50 })
    @biography    = cpcp.pull("l8.biography.get", { "subject_iri" => params[:cyborg_iri] })
    @provenance   = cpcp.pull("l8.provenance.list", {})
    @authorization = cpcp.pull("l8.authorization.list", {})
    @observations = cpcp.pull("l8.observation.list", { "limit" => 50 })
    @outcomes     = cpcp.pull("l8.outcome.list", { "limit" => 50 })
    @learning     = cpcp.pull("l8.learning.list", { "limit" => 50 })
    @drift        = cpcp.pull("l8.drift.list", { "limit" => 50 })
  end
end
```

The UI must render an “unavailable/refused” state when an envelope has `ok: false`; it must never infer missing facts, retry a write, or silently substitute direct data access.

| ERB panel | Profile(s) | CPCP PULL(s) | Required visible fields | Demo-visible behavior |
|---|---|---|---|---|
| **1. Cyborg & Context** | P1 | `l8.cyborg_channel.list`, `l8.context.list` | Cyborg IRI, channel key, direction, status, capabilities; Context CID, kind, shape/digest, ledger placement, admitted time, provenance CID | Click a Context CID to show the public metadata, not raw private JSON-LD. |
| **2. Reference Passing** | P2 | `l8.reference.list` | Reference ID, lifecycle event, target CID/URI, integrity digest, issuer, holder, recipient, expiry | Shows that a reference was passed without showing a bearer secret or opaque private descriptor. |
| **3. SwitchYard Route** | P3 | `l8.routing.list` | Route key, decision, target, channel CID, reason code, ordered hops, hop status/failure code | Timeline makes a routed vs deferred/refused Effect visible. |
| **4. Durable Effect Journal** | P4 | `l8.operation.journal`, `l8.execution.receipt.list` | Operation, request CID, idempotency-key fingerprint, event sequence/timestamp, receipt CID, status, replay link | A repeated `note.create` visibly resolves to the same durable receipt rather than another note. |
| **5. Biography & Provenance** | P5 | `l8.biography.get`, `l8.provenance.list` | Subject IRI, assertion/event, asserting agent, validity window; `from → predicate → to`, activity CID | Timeline and adjacency list connect a Note/Effect to agent claims and source CIDs. |
| **6. Authorization Evidence** | P6 | `l8.authorization.list` | Principal, action, resource CID/IRI, policy ref, permit/deny, time, evidence digest, redacted evidence | It shows why the public decision exists, never evaluator trace, credentials, or policy values marked local. |
| **7. Observation & Outcome** | P7 | `l8.observation.list`, `l8.outcome.list` | Measurement kind/value/unit/time/observer/quality; Effect CID, outcome status/kind/time, basis observation CIDs | A small status summary groups achieved/not-achieved/unknown; table retains source CIDs. |
| **8. Architectural Learning & Drift** | P8 | `l8.learning.list`, `l8.drift.list` | Cycle ID, drift/hypothesis/decision event, baseline, observed reference, severity, state, evidence CIDs, decision actor | An open-drift count and chronological log demonstrate the learning loop without pretending it changed a shape automatically. |

A single `app/views/governance/show.html.erb` can compose the eight partials. Each partial receives the raw never-raise envelope and calls a shared `governance_items(envelope)` helper that returns `[]` unless `envelope["ok"]` is true. That design forces FRONT to remain a projection consumer.

## 7. Grounding and SHACL wiring

### 7.1 File layout and catalog

```text
engines/rails-osi-level-8/
  data/osi-level-8/
    profile-1-cyborg-channel.ttl
    profile-2-reference-passing.ttl
    profile-3-switchyard-routing.ttl
    profile-4-durable-execution.ttl
    profile-5-biography-provenance.ttl
    profile-6-authorization-evidence.ttl
    profile-7-observation-outcome.ttl
    profile-8-architectural-learning.ttl
  app/services/osi_level_8/
    profile_catalog.rb
    grounding.rb
    mm_shacl_validator.rb
```

```ruby
# app/services/osi_level_8/profile_catalog.rb
class OsiLevel8::ProfileCatalog
  Entry = Data.define(:id, :path, :shape_iri, :sha256)

  def self.default
    root = OsiLevel8.config.shape_root
    new({
      "P1::NoteCreateEffectShape"  => ["osi-l8/p1/cyborg-channel@1", root.join("profile-1-cyborg-channel.ttl"), "https://osi.example/shapes/P1NoteCreateEffectShape"],
      "P1::NoteCreateContextShape" => ["osi-l8/p1/cyborg-channel@1", root.join("profile-1-cyborg-channel.ttl"), "https://osi.example/shapes/P1NoteCreateContextShape"],
      "P1::NoteListPullShape"      => ["osi-l8/p1/cyborg-channel@1", root.join("profile-1-cyborg-channel.ttl"), "https://osi.example/shapes/P1NoteListPullShape"],
      "P1::NoteListContextShape"   => ["osi-l8/p1/cyborg-channel@1", root.join("profile-1-cyborg-channel.ttl"), "https://osi.example/shapes/P1NoteListContextShape"],
      # Add one explicit request/response entry for every registered l8.* operation.
    }.transform_values { |id, path, iri| Entry.new(id, path, iri, Digest::SHA256.file(path).hexdigest) })
  end

  def initialize(entries) = @entries = entries
  def fetch(key) = @entries.fetch(key)
end
```

### 7.2 Stable Grounding API

Keep the unverified `mm-shacl-reader` public API behind a ten-line adapter. The rest of the engine consumes only `Grounding::Result`; if the reader API differs, only `MmShaclValidator#validate` changes. Do not substitute a different validator without an explicit product decision.

```ruby
# app/services/osi_level_8/grounding.rb
class OsiLevel8::Grounding
  Result = Data.define(:conforms?, :profile_id, :shape_id, :shape_digest, :violations) do
    def safe_report
      {
        profile_id:, shape_id:, shape_digest:,
        violations: violations.first(20).map { |v|
          v.slice(:focus_node, :path, :constraint, :message)
        }
      }
    end
  end

  def self.validate(graph, profile:)
    entry = OsiLevel8.config.profile_catalog.fetch(profile)
    raw = OsiLevel8::MmShaclValidator.new.validate(
      graph: graph, shapes_path: entry.path, focus_shape_iri: entry.shape_iri
    )
    Result.new(raw.conforms?, entry.id, entry.shape_iri, entry.sha256, raw.violations)
  rescue OsiLevel8::MmShaclValidator::Unavailable => e
    Result.new(false, entry&.id || "unknown", entry&.shape_iri || "unknown", entry&.sha256,
               [{ focus_node: nil, path: nil, constraint: "validator", message: "profile validator unavailable" }])
  end
end
```

The profile Turtle uses SHACL shapes to enforce closed contexts on admission and validates the JSON-LD payloads against the active profile. SHACL validation returns a conformance flag and a structured report, which the adapter translates into a refusal envelope when non-conforming, ensuring the FRONT never receives non-admitted governance data.[2]

For `note.create`, P1’s Effect shape should require a CID subject, actor identity, `cpcp:operationName = "note.create"`, idempotency key, and body/reference terms declared by the POC. P4’s durable-execution shape should require the effect/request CID and idempotency material. P6 requires principal/action/resource/policy reference; P7 requires observed time/value/observer; P8 requires evidence CIDs and a learning event kind. Reference, routing, provenance, and outcome shapes must all include a `profile_id` identity and permitted `ledger_placement` values, even though BACK—not the caller—derives the final placement.

### 7.3 Refusal envelope

An invalid Effect gets no domain mutation and no cross-boundary record. The following response is representative and remains JSON-RPC-LD inside the existing CPCP response wrapper:

```json
{
  "ok": false,
  "error": {
    "reason": "grounding_refused",
    "because": {
      "request_cid": "cid:sha256:8cf...",
      "profile_ids": ["osi-l8/p1/cyborg-channel@1", "osi-l8/p4-durable-execution@1"],
      "profile_id": "osi-l8/p4-durable-execution@1",
      "shape_id": "https://osi.example/shapes/P4NoteCreateEffectShape",
      "shape_digest": "d8c...",
      "violations": [
        {
          "focus_node": "cid:sha256:8cf...",
          "path": "cpcp:idempotencyKey",
          "constraint": "sh:MinCountConstraintComponent",
          "message": "must have at least one idempotency key"
        }
      ]
    }
  }
}
```

The private `AdmissionAttempt` retains the same safe report plus request digest for operator diagnosis. It does not preserve the untrusted raw submission, passwords, tokens, or unredacted JSON-LD merely to explain a refusal.

## 8. Tests and acceptance assertions

Use request tests against BACK’s CPCP route and integration/system tests against FRONT. Do not test a FRONT model because none exists.

| Test | Assertion |
|---|---|
| Valid `note.create` | Receives `ok: true`; creates one Note, P1 Context, P4 request/journal/receipt, P5 provenance, P6 authorization evidence, and profile index records in the assigned ledgers. |
| Repeated `note.create` with same idempotency scope/key | Creates no second Note or P4 request; returns original receipt CID and `replayed_from_receipt_cid` as appropriate. |
| Invalid P4 Effect | Receives `grounding_refused`; creates no Note, Context, request, receipt, or public evidence; creates one private `AdmissionAttempt`. |
| Authorization denial | Receives never-raise refusal; no domain write; public-safe deny evidence appears only if policy permits it, and private evaluator detail cannot be PULLed. |
| Private-local containment | Seed one `private_local` row of every model class; every `l8.*` PULL excludes it regardless of caller-supplied filters. |
| PULL purity | Calling `note.list` and each `l8.*` PULL changes no Level 8 table count. |
| BACKJOB completion | Job makes `l8.execution.complete` CPCP PUSH; BACK appends completion/receipt/outcome; job process has no direct L8 model persistence call. |
| FRONT isolation | Boot FRONT with an invalid/missing SQLite URL; `/governance` renders mocked CPCP data and contains no SQL queries. |
| Shape drift | Edit a shape’s allowed predicate set in test; an Effect with the removed predicate refuses and returns the new shape digest. |

## 9. KISS build sequence: one repository task per milestone

Each milestone is a single mergeable repository task. It leaves a demo-visible FRONT panel rather than deferring all visibility to the end.

| Milestone | Single repo task | BACK deliverable | FRONT demo outcome | Exit criterion |
|---:|---|---|---|---|
| 0 | **`chore/l8-engine-wiring`** | Add engine dependency, initializer, role guard, migration loading policy, profile catalog skeleton; no route added. | A Governance page shell reports BACK availability via existing `note.list` PULL. | FRONT has no DB configuration; BACK still serves `/_cpcp/rpc`. |
| 1 | **`feat/l8-p1-context-and-p4-receipts`** | Migrations 01, 02, 06–08, 16–17; `Grounding`, `LedgerPolicy`, adapter; wrap `note.create` and `note.list`; P1/P4 shapes and PULLs. | Panels 1 and 4 display Context CIDs, journal events, receipt status, and idempotent replay. | Valid push succeeds; invalid idempotency shape refuses; replay makes no second Note. |
| 2 | **`feat/l8-p5-biography-and-provenance`** | Migrations 09–10; record default actor biography and derivation edges from admitted request → Note → response. | Panel 5 shows actor timeline and provenance adjacency for a created Note. | A Note’s response CID can be traced to request CID and acting Cyborg. |
| 3 | **`feat/l8-p6-authorization-evidence`** | Migration 11; small policy adapter; public-safe evidence serializer; denial behavior. | Panel 6 shows a permit/deny with policy ref and digest, never evaluator detail. | A deny prevents Note creation and private trace never appears through any PULL. |
| 4 | **`feat/l8-p7-observation-and-outcome`** | Migrations 12–13; decorated `l8.observation.record`, `l8.outcome.record`, and `l8.execution.complete`. | Panel 7 shows a measured observation and an outcome linked to its effect. | BACKJOB completion produces an idempotent final receipt and P7 outcome. |
| 5 | **`feat/l8-p2-reference-passing`** | Migration 03; P2 shape; extract declared references from an admitted Effect and record lifecycle events. | Panel 2 shows a passed, integrity-bound reference without a secret descriptor. | Reference target CID, issuer, holder, and recipient trace are visible only when public. |
| 6 | **`feat/l8-p3-switchyard-routing`** | Migrations 04–05; routing policy seam; create decision/hop evidence for routed async effects. | Panel 3 renders target choice and ordered hop statuses. | A deferred/failed hop appends evidence and does not overwrite the original decision. |
| 7 | **`feat/l8-p8-learning-loop`** | Migration 14; `l8.learning.record`; drift PULL and no-autonomous-shape-change policy. | Panel 8 shows open drift, hypothesis, evidence, and accepted/rejected decision. | A learning event is traceable to evidence CIDs and cannot change a profile automatically. |
| 8 | **`test/l8-boundary-and-demo-fixtures`** | Migration 15 if not already added; fixture graph generator; full boundary, never-raise, role-isolation, and CLOSED-shape suite. | All eight panels populate from one seeded narrative, with a visible refusal/replay example. | CI proves private-local non-export, no new route, FRONT DBleness, and all 8 profiles represented. |

## 10. Final implementation decisions

The POC should **not** create a generic event store, a Graph-backed UI, an admin API, or a second identity/authentication system. The tables above are deliberately typed because each visible Level 8 profile has a durable, queryable read model and because the policy “private local never crosses” is enforceable at the repository level.

The only thing the FRONT receives is a CPCP success/refusal envelope and public field whitelist. The only process that admits evidence and changes the authoritative database is BACK. The adapter is the sole cross-cutting enforcement point for grounding, ledger placement, provenance, authorization evidence, durable execution, and response metadata. This keeps the POC narrow while making every Level 8 part both demonstrable and testable.

## References

[1] [Rails Guides, *Getting Started with Engines*](https://guides.rubyonrails.org/engines.html)

[2] [W3C, *Shapes Constraint Language (SHACL)*](https://www.w3.org/TR/shacl/)

## Sources

- https://guides.rubyonrails.org/engines.html
- https://www.w3.org/TR/shacl/
