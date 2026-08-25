# frozen_string_literal: true

module RailsOsiLevel8
  # P8 architectural learning loop. Records drift/hypothesis/decision events.
  # Invariant: cannot autonomously change a profile/shape — profile_change_accepted
  # is recorded as evidence only; shapes remain operator-controlled.
  module Learning
    ALLOWED_KINDS = %w[
      drift_detected hypothesis_recorded experiment_started decision_recorded
      profile_change_proposed profile_change_accepted profile_change_rejected
    ].freeze

    module_function

    def record!(params)
      params = params.transform_keys(&:to_s)
      kind = params["eventKind"].to_s
      raise KnownRefusal.new("invalid_learning_event", { "eventKind" => kind }) unless ALLOWED_KINDS.include?(kind)

      # No autonomous shape mutation — even "accepted" only appends evidence.
      if kind == "profile_change_accepted"
        proposal = (params["proposal"].is_a?(Hash) ? params["proposal"] : {}).merge(
          "applied" => false, "reason" => "no_autonomous_shape_change"
        )
        params = params.merge("proposal" => proposal)
      end

      now = RailsOsiLevel8.config.clock.call
      cycle = params["learningCycleId"].presence || "cycle:default"
      evidence_cids = Array(params["evidenceCids"])
      proposal = params["proposal"].is_a?(Hash) ? params["proposal"] : {}
      payload = {
        "cycle" => cycle,
        "kind" => kind,
        "status" => params["status"].presence || default_status(kind),
        "evidence" => evidence_cids
      }
      row = RailsOsiLevel8::LearningEvent.create!(
        cid: Cid.for_payload(payload.merge("at" => now.iso8601)),
        profile_id: "osi-l8/p8-architectural-learning@1",
        ledger_placement: "canonical",
        provenance_json: { "decided_by_iri" => params["decidedByIri"] },
        payload_digest: Cid.digest_for(payload),
        recorded_at: now,
        learning_cycle_id: cycle,
        event_kind: kind,
        baseline_ref: params["baselineRef"],
        observed_ref: params["observedRef"],
        severity: params["severity"],
        status: params["status"].presence || default_status(kind),
        subject_cid: params["subjectCid"],
        evidence_cids: evidence_cids,
        proposal_json: proposal,
        decided_by_iri: params["decidedByIri"]
      )
      ProfileIndex.record!(
        subject_cid: row.subject_cid || row.cid,
        evidence_type: "learning",
        evidence_cid: row.cid,
        operation_name: "l8.learning.record",
        summary: { "event_kind" => kind, "status" => row.status }
      )
      {
        "cid" => row.cid,
        "learning_cycle_id" => row.learning_cycle_id,
        "event_kind" => row.event_kind,
        "status" => row.status,
        "evidence_cids" => row.evidence_cids,
        "autonomous_shape_change" => false
      }
    end

    def default_status(kind)
      case kind
      when "drift_detected", "hypothesis_recorded", "experiment_started", "profile_change_proposed" then "open"
      when "profile_change_accepted", "decision_recorded" then "accepted"
      when "profile_change_rejected" then "rejected"
      else "open"
      end
    end
    private_class_method :default_status
  end
end
