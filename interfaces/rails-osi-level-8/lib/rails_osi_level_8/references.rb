# frozen_string_literal: true

module RailsOsiLevel8
  # P2 reference-passing: extract declared references from an admitted Effect and
  # record append-only lifecycle events. access_descriptor_json may hold private
  # descriptors but is NEVER emitted by l8.reference.list.
  module References
    module_function

    def record_from_effect!(params:, request_cid:, domain:, op_req:)
      return unless defined?(RailsOsiLevel8::ReferencePass)

      refs = Array(params["references"])
      if refs.empty? && domain.is_a?(Hash) && domain["@id"]
        refs = [{
          "referenceId" => "ref:note:#{domain["id"] || domain["@id"]}",
          "eventKind" => "passed",
          "targetCid" => domain["@id"],
          "targetUri" => domain["@id"],
          "integrityDigest" => Cid.digest_for(domain),
          "issuerIri" => params["callerIri"].presence || "cyborg:front",
          "holderIri" => "mind:pod/back",
          "recipientIri" => "cyborg:front"
        }]
      end

      now = RailsOsiLevel8.config.clock.call
      refs.each do |raw|
        r = stringify(raw)
        next if r["referenceId"].to_s.empty?

        payload = r.merge("operation_request_cid" => op_req.cid)
        RailsOsiLevel8::ReferencePass.create!(
          cid: Cid.for_payload(payload),
          profile_id: "osi-l8/p2/reference-passing@1",
          ledger_placement: LedgerPolicy.placement_for!(operation: "note.create", evidence: :reference),
          provenance_json: { "operation_request_cid" => op_req.cid },
          payload_digest: Cid.digest_for(payload),
          recorded_at: now,
          reference_id: r["referenceId"],
          event_kind: r["eventKind"].presence || "passed",
          reference_uri: r["referenceUri"],
          target_cid: r["targetCid"] || request_cid,
          target_uri: r["targetUri"],
          integrity_digest: r["integrityDigest"] || Cid.digest_for(r),
          issuer_iri: r["issuerIri"] || params["callerIri"] || "cyborg:front",
          holder_iri: r["holderIri"],
          recipient_iri: r["recipientIri"],
          expires_at: r["expiresAt"] ? Time.parse(r["expiresAt"].to_s) : nil,
          access_descriptor_json: r["accessDescriptor"] || { "private" => true }
        )
      end
    end

    def stringify(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
      when Array then obj.map { |v| stringify(v) }
      else obj
      end
    end
    private_class_method :stringify
  end
end
