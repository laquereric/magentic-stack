# frozen_string_literal: true

module RailsOsiLevel8
  # Cross-profile evidence index (migration 15). Not a replacement for typed tables.
  module ProfileIndex
    module_function

    def record!(subject_cid:, evidence_type:, evidence_cid:, operation_name: nil, summary: {})
      return unless defined?(RailsOsiLevel8::ProfileEvidence)
      return if subject_cid.to_s.empty? || evidence_cid.to_s.empty?

      now = RailsOsiLevel8.config.clock.call
      payload = {
        "subject_cid" => subject_cid,
        "evidence_type" => evidence_type,
        "evidence_cid" => evidence_cid,
        "operation_name" => operation_name
      }
      RailsOsiLevel8::ProfileEvidence.create!(
        cid: Cid.for_payload(payload.merge("at" => now.to_f)),
        profile_id: "osi-l8/profile-index@1",
        ledger_placement: "canonical",
        provenance_json: {},
        payload_digest: Cid.digest_for(payload),
        recorded_at: now,
        subject_cid: subject_cid,
        evidence_type: evidence_type,
        evidence_cid: evidence_cid,
        operation_name: operation_name,
        summary_json: summary
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # unique [subject, type, evidence] — idempotent index
      nil
    end
  end
end
