# frozen_string_literal: true

module RailsOsiLevel8
  # P7 / durable-completion commands invoked as CPCP PUSHes (not new routes).
  module P7Commands
    module_function

    # REFUSES RATHER THAN FILLS IN.
    #
    # Observation validates presence of observation_kind, measured_at,
    # observer_iri and value_json -- and this method used to default every one of
    # them, so the validation could never fire and the operation had no refusal
    # path at all. A caller sending observationKind "" got "metric" recorded; one
    # sending observerIri "" was attributed to mind:backjob; one sending a
    # non-Hash quality had it silently replaced with {}. Each of those is a
    # fabricated value stored as evidence.
    #
    # Absent stays defaulted -- execution_complete! omits measuredAt on purpose,
    # and the CPCP seam already requires observationKind from external callers.
    # What is refused is SUPPLIED-BUT-EMPTY and SUPPLIED-BUT-UNUSABLE, because
    # those are a caller saying something, and answering with something else.
    # Time.parse raises ArgumentError on junk, which the seam reports as a generic
    # handler error rather than a refusal -- an unparseable timestamp is the
    # caller's mistake and should read as one.
    def parse_measured_at(raw, fallback)
      return fallback if raw.nil? || raw.to_s.strip.empty?

      Time.parse(raw.to_s)
    rescue ArgumentError, TypeError
      raise KnownRefusal.new("invalid_params",
                             { "invalid" => "measuredAt", "expected" => "a parseable timestamp" })
    end

    def observation_record!(params)
      now = RailsOsiLevel8.config.clock.call

      SuppliedInput.blank!(params, "observationKind", "observerIri")
      SuppliedInput.object!(params, "quality")
      raise KnownRefusal.new("missing_params", { "missing" => "value" }) if params["value"].nil?
      measured_at = parse_measured_at(params["measuredAt"], now)

      kind = params["observationKind"].presence || "metric"
      value = params["value"].is_a?(Hash) ? params["value"] : { "raw" => params["value"] }
      payload = {
        "kind" => kind,
        "measured_at" => (params["measuredAt"] || now.iso8601),
        "observer" => params["observerIri"].presence || "mind:backjob",
        "value" => value
      }
      row = Observation.create!(
        cid: Cid.for_payload(payload),
        profile_id: "osi-l8/p7-observation-outcome@1",
        ledger_placement: "canonical",
        provenance_json: {},
        payload_digest: Cid.digest_for(payload),
        recorded_at: now,
        observed_subject_cid: params["observedSubjectCid"],
        observed_subject_iri: params["observedSubjectIri"],
        observation_kind: kind,
        measured_at: measured_at,
        observer_iri: params["observerIri"].presence || "mind:backjob",
        value_json: value,
        unit_iri: params["unitIri"],
        source_context_cid: params["sourceContextCid"],
        quality_json: params["quality"].is_a?(Hash) ? params["quality"] : {}
      )
      ProfileIndex.record!(subject_cid: row.observed_subject_cid || row.cid, evidence_type: "observation",
                           evidence_cid: row.cid, operation_name: "l8.observation.record")
      public_observation(row)
    end

    def outcome_record!(params)
      now = RailsOsiLevel8.config.clock.call
      effect = params["effectCid"].to_s
      raise KnownRefusal.new("missing_params", { "missing" => "effectCid" }) if effect.empty?

      # status is the finding. "" became "achieved", and a non-object outcome
      # became {"ok" => true} -- a claim of success the caller never made, past a
      # model that validates status against Outcome::STATUSES and would have
      # caught it had it ever seen the value.
      SuppliedInput.blank!(params, "outcomeKind", "status", "determinerIri")
      SuppliedInput.object!(params, "outcome")

      payload = {
        "effect" => effect,
        "kind" => params["outcomeKind"].presence || "execution",
        "status" => params["status"].presence || "achieved"
      }
      row = Outcome.create!(
        cid: Cid.for_payload(payload.merge("at" => now.iso8601)),
        profile_id: "osi-l8/p7-observation-outcome@1",
        ledger_placement: "canonical",
        provenance_json: {},
        payload_digest: Cid.digest_for(payload),
        recorded_at: now,
        effect_cid: effect,
        operation_request_cid: params["operationRequestCid"],
        outcome_kind: params["outcomeKind"].presence || "execution",
        status: params["status"].presence || "achieved",
        determined_at: now,
        determiner_iri: params["determinerIri"].presence || "mind:backjob",
        outcome_json: params["outcome"].is_a?(Hash) ? params["outcome"] : { "ok" => true },
        basis_observation_cids: Array(params["basisObservationCids"]),
        supersedes_cid: params["supersedesCid"]
      )
      ProfileIndex.record!(subject_cid: effect, evidence_type: "outcome", evidence_cid: row.cid,
                           operation_name: "l8.outcome.record")
      public_outcome(row)
    end

    def execution_complete!(params)
      # "" became "succeeded" -- the most favourable reading of an empty field, on
      # the record that says whether an operation worked.
      SuppliedInput.blank!(params, "status", "callerIri", "idempotencyKey")

      op_cid = params["operationRequestCid"].to_s
      raise KnownRefusal.new("missing_params", { "missing" => "operationRequestCid" }) if op_cid.empty?

      op_req = OperationRequest.find_by(cid: op_cid)
      raise KnownRefusal.new("unknown_operation_request", { "operationRequestCid" => op_cid }) unless op_req

      scope = "complete"
      key = params["idempotencyKey"].presence || "complete:#{op_cid}"
      if (prior = OperationRequest.find_by(operation_name: "l8.execution.complete", idempotency_scope: scope, idempotency_key: key))
        return {
          "replayed" => true,
          "operation_request_cid" => prior.cid,
          "receipt_cid" => prior.receipt&.cid,
          "outcome_cid" => Outcome.cross_boundary.where(operation_request_cid: op_cid).order(determined_at: :desc).first&.cid
        }
      end

      now = RailsOsiLevel8.config.clock.call
      complete_req = OperationRequest.create!(
        cid: Cid.for_payload("complete" => op_cid, "key" => key),
        profile_id: "osi-l8/p4-durable-execution@1",
        ledger_placement: "sync_intent",
        provenance_json: { "parent" => op_cid },
        payload_digest: Cid.digest_for(params),
        recorded_at: now,
        operation_name: "l8.execution.complete",
        direction: "push",
        idempotency_scope: scope,
        idempotency_key: key,
        request_context_cid: op_cid,
        effect_cid: op_req.effect_cid,
        request_digest: Cid.digest_for(params),
        caller_iri: params["callerIri"].presence || "mind:backjob",
        admission_status: "admitted"
      )

      seq = (op_req.journal_entries.maximum(:sequence) || 0) + 1
      journal_cid = Cid.for_payload("op" => op_cid, "seq" => seq, "event" => "completed")
      OperationJournalEntry.create!(
        cid: journal_cid,
        profile_id: "osi-l8/p4-durable-execution@1",
        ledger_placement: "canonical",
        provenance_json: {},
        payload_digest: Cid.digest_for("complete" => true),
        recorded_at: now,
        operation_request_cid: op_cid,
        sequence: seq,
        event_kind: "completed",
        event_at: now,
        detail_json: { "via" => "l8.execution.complete" }
      )

      status = params["status"].presence || "succeeded"
      receipt_payload = { "complete_for" => op_cid, "status" => status, "key" => key }
      receipt = ExecutionReceipt.create!(
        cid: Cid.for_payload(receipt_payload),
        profile_id: "osi-l8/p4-durable-execution@1",
        ledger_placement: "canonical",
        provenance_json: { "parent_request" => op_cid },
        payload_digest: Cid.digest_for(receipt_payload),
        recorded_at: now,
        operation_request_cid: complete_req.cid,
        effect_cid: op_req.effect_cid,
        execution_key: "l8.execution.complete:#{scope}:#{key}",
        status: status,
        result_digest: Cid.digest_for(params),
        completed_at: now,
        failure_reason: params["failureReason"]
      )

      obs = observation_record!(
        "observationKind" => "execution_complete",
        "observedSubjectCid" => op_cid,
        "observerIri" => params["callerIri"].presence || "mind:backjob",
        "value" => { "status" => status }
      )
      outcome = outcome_record!(
        "effectCid" => op_req.effect_cid || op_cid,
        "operationRequestCid" => op_cid,
        "outcomeKind" => "execution_complete",
        "status" => status == "succeeded" ? "achieved" : "not_achieved",
        "determinerIri" => params["callerIri"].presence || "mind:backjob",
        "basisObservationCids" => [obs["cid"]],
        "outcome" => { "receipt_cid" => receipt.cid }
      )

      {
        "operation_request_cid" => op_cid,
        "completion_request_cid" => complete_req.cid,
        "receipt_cid" => receipt.cid,
        "observation_cid" => obs["cid"],
        "outcome_cid" => outcome["cid"],
        "status" => status
      }
    end

    def public_observation(row)
      {
        "cid" => row.cid,
        "observed_subject_cid" => row.observed_subject_cid,
        "observed_subject_iri" => row.observed_subject_iri,
        "observation_kind" => row.observation_kind,
        "measured_at" => row.measured_at&.iso8601,
        "observer_iri" => row.observer_iri,
        "value_json" => row.value_json,
        "unit_iri" => row.unit_iri,
        "source_context_cid" => row.source_context_cid,
        "quality_json" => row.quality_json
      }
    end

    def public_outcome(row)
      {
        "cid" => row.cid,
        "effect_cid" => row.effect_cid,
        "operation_request_cid" => row.operation_request_cid,
        "outcome_kind" => row.outcome_kind,
        "status" => row.status,
        "determined_at" => row.determined_at&.iso8601,
        "determiner_iri" => row.determiner_iri,
        "outcome_json" => row.outcome_json,
        "basis_observation_cids" => row.basis_observation_cids,
        "supersedes_cid" => row.supersedes_cid
      }
    end
  end
end
