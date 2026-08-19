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
