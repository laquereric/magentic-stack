# frozen_string_literal: true

module RailsOsiLevel8
  # BACK read repositories. Every query starts with .cross_boundary so private_local
  # never crosses a CPCP PULL — filter lives here, not in FRONT.
  module Projections
    module_function

    def context_list(filters = {})
      rel = Context.cross_boundary.order(recorded_at: :desc)
      rel = rel.where(subject_iri: filters["subject_iri"]) if present?(filters["subject_iri"])
      rel = rel.where(context_kind: filters["context_kind"]) if present?(filters["context_kind"])
      rel.limit(limit_of(filters)).map { |r|
        r.slice(
          "cid", "profile_id", "ledger_placement", "subject_iri", "context_kind",
          "graph_iri", "shape_id", "shape_digest", "admitted_at", "provenance_cid", "payload_digest"
        )
      }
    end

    def cyborg_channel_list(filters = {})
      rel = CyborgChannel.cross_boundary.order(recorded_at: :desc)
      rel = rel.where(cyborg_iri: filters["cyborg_iri"]) if present?(filters["cyborg_iri"])
      rel = rel.where(channel_key: filters["channel_key"]) if present?(filters["channel_key"])
      rel.limit(limit_of(filters)).map { |r|
        r.slice(
          "cid", "cyborg_iri", "channel_key", "counterparty_iri", "direction",
          "transport", "channel_status", "capabilities_json", "contract_context_cid"
        )
      }
    end

    def operation_journal(filters = {})
      rel = OperationJournalEntry.cross_boundary.order(event_at: :desc)
      rel = rel.where(operation_request_cid: filters["operation_request_cid"]) if present?(filters["operation_request_cid"])
      if present?(filters["operation_name"])
        cids = OperationRequest.cross_boundary.where(operation_name: filters["operation_name"]).pluck(:cid)
        rel = rel.where(operation_request_cid: cids)
      end
      rel.limit(limit_of(filters)).map { |r|
        req = OperationRequest.find_by(cid: r.operation_request_cid)
        {
          "operation_request_cid" => r.operation_request_cid,
          "operation_name" => req&.operation_name,
          "idempotency_key_fingerprint" => req ? Digest::SHA256.hexdigest(req.idempotency_key)[0, 12] : nil,
          "caller_iri" => req&.caller_iri,
          "sequence" => r.sequence,
          "event_kind" => r.event_kind,
          "event_at" => r.event_at&.iso8601,
          "detail_json" => public_detail(r.detail_json),
          "receipt_cid" => r.receipt_cid,
          "cid" => r.cid
        }
      }
    end

    def execution_receipt_list(filters = {})
      rel = ExecutionReceipt.cross_boundary.order(completed_at: :desc)
      rel = rel.where(operation_request_cid: filters["operation_request_cid"]) if present?(filters["operation_request_cid"])
      rel = rel.where(execution_key: filters["execution_key"]) if present?(filters["execution_key"])
      rel.limit(limit_of(filters)).map { |r|
        r.slice(
          "cid", "operation_request_cid", "effect_cid", "execution_key", "status",
          "result_context_cid", "completed_at", "failure_reason", "replayed_from_receipt_cid"
        )
      }
    end

    def biography_get(filters = {})
      subject = filters["subject_iri"].to_s
      raise KnownRefusal.new("missing_params", { "missing" => "subject_iri" }) if subject.empty?

      BiographyEvent.cross_boundary
        .where(subject_iri: subject)
        .order(recorded_at: :desc)
        .limit(limit_of(filters))
        .map { |r|
          {
            "cid" => r.cid,
            "subject_iri" => r.subject_iri,
            "event_kind" => r.event_kind,
            "asserted_by_iri" => r.asserted_by_iri,
            "valid_from" => r.valid_from&.iso8601,
            "valid_to" => r.valid_to&.iso8601,
            "statement_json" => r.statement_json,
            "recorded_at" => r.recorded_at&.iso8601
          }
        }
    end

    def provenance_list(filters = {})
      rel = ProvenanceEdge.cross_boundary.order(asserted_at: :desc)
      rel = rel.where(from_cid: filters["from_cid"]) if present?(filters["from_cid"])
      rel = rel.where(to_cid: filters["to_cid"]) if present?(filters["to_cid"])
      rel = rel.where(agent_iri: filters["agent_iri"]) if present?(filters["agent_iri"])
      rel.limit(limit_of(filters)).map { |r|
        {
          "cid" => r.cid,
          "from_cid" => r.from_cid,
          "predicate" => r.predicate,
          "to_cid" => r.to_cid,
          "to_iri" => r.to_iri,
          "agent_iri" => r.agent_iri,
          "activity_cid" => r.activity_cid,
          "asserted_at" => r.asserted_at&.iso8601
        }
      }
    end

    def authorization_list(filters = {})
      rel = AuthorizationEvidence.cross_boundary.order(decided_at: :desc)
      rel = rel.where(operation_request_cid: filters["operation_request_cid"]) if present?(filters["operation_request_cid"])
      rel = rel.where(principal_iri: filters["principal_iri"]) if present?(filters["principal_iri"])
      rel = rel.where(decision: filters["decision"]) if present?(filters["decision"])
      rel.limit(limit_of(filters)).map { |r|
        {
          "cid" => r.cid,
          "operation_request_cid" => r.operation_request_cid,
          "principal_iri" => r.principal_iri,
          "action" => r.action,
          "resource_cid" => r.resource_cid,
          "resource_iri" => r.resource_iri,
          "policy_ref" => r.policy_ref,
          "decision" => r.decision,
          "decided_at" => r.decided_at&.iso8601,
          "evidence_digest" => r.evidence_digest,
          "redacted_evidence_json" => r.redacted_evidence_json
          # evaluator_detail_json intentionally omitted — private_local never crosses
        }
      }
    end

    def reference_list(filters = {})
      rel = ReferencePass.cross_boundary.order(recorded_at: :desc)
      rel = rel.where(reference_id: filters["reference_id"]) if present?(filters["reference_id"])
      rel = rel.where(target_cid: filters["target_cid"]) if present?(filters["target_cid"])
      rel = rel.where(holder_iri: filters["holder_iri"]) if present?(filters["holder_iri"])
      rel.limit(limit_of(filters)).map { |r|
        {
          "cid" => r.cid,
          "reference_id" => r.reference_id,
          "event_kind" => r.event_kind,
          "reference_uri" => r.reference_uri,
          "target_cid" => r.target_cid,
          "target_uri" => r.target_uri,
          "integrity_digest" => r.integrity_digest,
          "issuer_iri" => r.issuer_iri,
          "holder_iri" => r.holder_iri,
          "recipient_iri" => r.recipient_iri,
          "expires_at" => r.expires_at&.iso8601,
          "recorded_at" => r.recorded_at&.iso8601
          # access_descriptor_json omitted — may contain private descriptors
        }
      }
    end

    def routing_list(filters = {})
      decisions = RoutingDecision.cross_boundary.order(recorded_at: :desc)
      decisions = decisions.where(operation_request_cid: filters["operation_request_cid"]) if present?(filters["operation_request_cid"])
      decisions = decisions.where(route_key: filters["route_key"]) if present?(filters["route_key"])
      decisions.limit(limit_of(filters)).flat_map { |d|
        hops = RoutingHop.cross_boundary.where(routing_decision_cid: d.cid).order(:hop_number)
        [{
          "kind" => "decision",
          "cid" => d.cid,
          "route_key" => d.route_key,
          "chosen_target_iri" => d.chosen_target_iri,
          "chosen_channel_cid" => d.chosen_channel_cid,
          "decision" => d.decision,
          "reason_code" => d.reason_code,
          "recorded_at" => d.recorded_at&.iso8601,
          "operation_request_cid" => d.operation_request_cid
        }] + hops.map { |h|
          {
            "kind" => "hop",
            "cid" => h.cid,
            "routing_decision_cid" => h.routing_decision_cid,
            "hop_number" => h.hop_number,
            "from_iri" => h.from_iri,
            "to_iri" => h.to_iri,
            "hop_status" => h.hop_status,
            "ended_at" => h.ended_at&.iso8601,
            "failure_code" => h.failure_code
          }
        }
      }
    end

    def observation_list(filters = {})
      rel = Observation.cross_boundary.order(measured_at: :desc)
      rel = rel.where(observed_subject_cid: filters["observed_subject_cid"]) if present?(filters["observed_subject_cid"])
      rel = rel.where(observation_kind: filters["observation_kind"]) if present?(filters["observation_kind"])
      rel.limit(limit_of(filters)).map { |r| P7Commands.public_observation(r) }
    end

    def outcome_list(filters = {})
      rel = Outcome.cross_boundary.order(determined_at: :desc)
      rel = rel.where(effect_cid: filters["effect_cid"]) if present?(filters["effect_cid"])
      rel = rel.where(status: filters["status"]) if present?(filters["status"])
      rel.limit(limit_of(filters)).map { |r| P7Commands.public_outcome(r) }
    end

    def learning_list(filters = {})
      rel = LearningEvent.cross_boundary.order(recorded_at: :desc)
      rel = rel.where(learning_cycle_id: filters["learning_cycle_id"]) if present?(filters["learning_cycle_id"])
      rel = rel.where(status: filters["status"]) if present?(filters["status"])
      rel.limit(limit_of(filters)).map { |r| learning_fields(r) }
    end

    def drift_list(filters = {})
      rel = LearningEvent.cross_boundary.where(event_kind: "drift_detected").order(recorded_at: :desc)
      rel = rel.where(severity: filters["severity"]) if present?(filters["severity"])
      rel = rel.where(status: filters["status"]) if present?(filters["status"])
      rel.limit(limit_of(filters)).map { |r| learning_fields(r) }
    end

    def profile_evidence_list(filters = {})
      rel = ProfileEvidence.cross_boundary.order(recorded_at: :desc)
      rel = rel.where(subject_cid: filters["subject_cid"]) if present?(filters["subject_cid"])
      rel = rel.where(profile_id: filters["profile_id"]) if present?(filters["profile_id"])
      rel = rel.where(evidence_type: filters["evidence_type"]) if present?(filters["evidence_type"])
      rel.limit(limit_of(filters)).map { |r|
        {
          "cid" => r.cid,
          "profile_id" => r.profile_id,
          "subject_cid" => r.subject_cid,
          "evidence_type" => r.evidence_type,
          "evidence_cid" => r.evidence_cid,
          "operation_name" => r.operation_name,
          "summary_json" => r.summary_json,
          "recorded_at" => r.recorded_at&.iso8601
        }
      }
    end

    def learning_fields(r)
      {
        "cid" => r.cid,
        "learning_cycle_id" => r.learning_cycle_id,
        "event_kind" => r.event_kind,
        "baseline_ref" => r.baseline_ref,
        "observed_ref" => r.observed_ref,
        "severity" => r.severity,
        "status" => r.status,
        "subject_cid" => r.subject_cid,
        "evidence_cids" => r.evidence_cids,
        "proposal_json" => r.proposal_json,
        "decided_by_iri" => r.decided_by_iri,
        "recorded_at" => r.recorded_at&.iso8601
      }
    end

    def limit_of(filters)
      [[(filters["limit"] || 50).to_i, 1].max, 200].min
    end

    def present?(v)
      !(v.nil? || (v.respond_to?(:empty?) && v.empty?))
    end

    def public_detail(json)
      return {} unless json.is_a?(Hash)

      json.except("evaluator_detail", "secret", "token", "password")
    end
  end
end
