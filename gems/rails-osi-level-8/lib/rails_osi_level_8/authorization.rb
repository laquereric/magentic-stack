# frozen_string_literal: true

module RailsOsiLevel8
  # Small P6 policy adapter. DEMO-ONLY trigger (gstack fix #3): keys off the note title
  # prefix "DENY:" / forceDeny so the deny path is demonstrable. A production policy engine
  # MUST NOT key authorization on user-supplied content; replace this with a real PDP.
  # Writes public-safe evidence + private evaluator detail; deny raises KnownRefusal
  # before the domain handler runs.
  module Authorization
    POLICY_REF = "policy:mind-pod/note-write@1"

    module_function

    def admit!(params:, request_cid:, op_req:)
      principal = params["callerIri"].presence || "cyborg:front"
      title = params["title"].to_s
      force = params["forceDeny"].to_s == "true" || params["forceDeny"] == true
      deny = force || title.start_with?("DENY:")

      decision = deny ? "deny" : "permit"
      now = RailsOsiLevel8.config.clock.call
      redacted = {
        "principal" => principal,
        "action" => "note.create",
        "policy_ref" => POLICY_REF,
        "decision" => decision
      }
      detail = {
        "matched_rule" => deny ? (force ? "forceDeny" : "title_prefix_DENY") : "default_permit",
        "title_preview" => title[0, 32],
        "evaluator" => "RailsOsiLevel8::Authorization"
      }
      digest = Cid.digest_for(redacted.merge("request_cid" => request_cid))

      # Public summary always canonical; evaluator detail stays private_local on same row
      # but is NEVER projected by l8.authorization.list.
      RailsOsiLevel8::AuthorizationEvidence.create!(
        cid: Cid.for_payload(redacted.merge("request_cid" => request_cid, "at" => now.iso8601)),
        profile_id: "osi-l8/p6-authorization-evidence@1",
        ledger_placement: deny ? "canonical" : LedgerPolicy.placement_for!(operation: "note.create", evidence: :authorization),
        provenance_json: { "operation_request_cid" => op_req.cid },
        payload_digest: digest,
        recorded_at: now,
        operation_request_cid: op_req.cid,
        principal_iri: principal,
        action: "note.create",
        resource_cid: request_cid,
        resource_iri: nil,
        policy_ref: POLICY_REF,
        decision: decision,
        decided_at: now,
        evidence_digest: digest,
        redacted_evidence_json: redacted,
        evaluator_detail_json: detail
      )

      if deny
        raise KnownRefusal.new(
          "authorization_denied",
          {
            "request_cid" => request_cid,
            "policy_ref" => POLICY_REF,
            "decision" => "deny",
            "evidence_digest" => digest,
            "profile_ids" => ["osi-l8/p6-authorization-evidence@1"]
          }
        )
      end

      decision
    end
  end
end
