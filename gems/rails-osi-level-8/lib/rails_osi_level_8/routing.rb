# frozen_string_literal: true

module RailsOsiLevel8
  # P3 SwitchYard routing seam. Records a decision + hop evidence for effects that
  # declare a routeKey / asyncRoute; otherwise records a default local route.
  module Routing
    module_function

    def record_if_routed!(params:, request_cid:, op_req:)
      return unless defined?(RailsOsiLevel8::RoutingDecision)

      route_key = params["routeKey"].presence || params["asyncRoute"].presence || "local:note.create"
      decision = case params["routeDecision"].to_s
                 when "rejected" then "rejected"
                 when "deferred" then "deferred"
                 else "routed"
                 end
      reason = params["routeReason"].presence || (decision == "routed" ? "default_local" : decision)
      now = RailsOsiLevel8.config.clock.call
      target = params["routeTarget"].presence || "mind:pod/back"
      payload = {
        "route_key" => route_key,
        "operation_request_cid" => op_req.cid,
        "decision" => decision,
        "target" => target
      }
      decision_cid = Cid.for_payload(payload)
      RailsOsiLevel8::RoutingDecision.create!(
        cid: decision_cid,
        profile_id: "osi-l8/p3-switchyard-routing@1",
        ledger_placement: LedgerPolicy.placement_for!(operation: "note.create", evidence: :routing),
        provenance_json: { "operation_request_cid" => op_req.cid },
        payload_digest: Cid.digest_for(payload),
        recorded_at: now,
        route_key: route_key,
        operation_request_cid: op_req.cid,
        effect_cid: request_cid,
        chosen_target_iri: target,
        chosen_channel_cid: nil,
        policy_ref: "policy:switchyard/default@1",
        decision: decision,
        reason_code: reason,
        candidate_digest: Cid.digest_for([target])
      )

      hop_status = decision == "routed" ? "delivered" : (decision == "deferred" ? "attempted" : "failed")
      hop_payload = { "decision" => decision_cid, "hop" => 1, "status" => hop_status }
      RailsOsiLevel8::RoutingHop.create!(
        cid: Cid.for_payload(hop_payload),
        profile_id: "osi-l8/p3-switchyard-routing@1",
        ledger_placement: "canonical",
        provenance_json: { "routing_decision_cid" => decision_cid },
        payload_digest: Cid.digest_for(hop_payload),
        recorded_at: now,
        routing_decision_cid: decision_cid,
        hop_number: 1,
        from_iri: params["callerIri"].presence || "cyborg:front",
        to_iri: target,
        channel_cid: nil,
        hop_status: hop_status,
        started_at: now,
        ended_at: now,
        failure_code: decision == "rejected" ? reason : nil
      )

      # Append-only: a deferred/failed follow-up hop does not overwrite the decision.
      if params["routeHopFailure"].to_s == "true"
        fail_payload = { "decision" => decision_cid, "hop" => 2, "status" => "failed" }
        RailsOsiLevel8::RoutingHop.create!(
          cid: Cid.for_payload(fail_payload),
          profile_id: "osi-l8/p3-switchyard-routing@1",
          ledger_placement: "canonical",
          provenance_json: { "routing_decision_cid" => decision_cid },
          payload_digest: Cid.digest_for(fail_payload),
          recorded_at: now,
          routing_decision_cid: decision_cid,
          hop_number: 2,
          from_iri: target,
          to_iri: params["routeFailover"].presence || "mind:pod/backjob",
          hop_status: "failed",
          started_at: now,
          ended_at: now,
          failure_code: params["routeFailureCode"].presence || "downstream_unavailable"
        )
      end

      decision_cid
    end
  end
end
