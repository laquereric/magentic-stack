# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Intent
    # P10.M6 — decorate effect commit with IntentTrace requirement.
    module TraceGate
      module_function

      # Call around domain note.create success path when groundingCid is present or required.
      def require_and_record!(effect_cid:, grounding_cid: nil, journey: nil)
        grounding = resolve_grounding(grounding_cid: grounding_cid, journey: journey)
        unless grounding && (grounding["status"].to_s == "ratified" || grounding["ledgerPlacement"] == "canonical")
          raise KnownRefusal.new(
            "intent_grounding_not_active",
            { "effectCid" => effect_cid, "groundingCid" => grounding_cid, "profile_id" => "osi-level-8/profile-10" }
          )
        end

        existing = GraphStore.find_by(type: "intent:IntentTrace", effect_cid: effect_cid, ledger: "cross_boundary")
        return existing.first if existing.any?

        now = Time.now.utc.iso8601
        payload = {
          "@type" => "intent:IntentTrace",
          "effectCid" => effect_cid,
          "groundingCid" => grounding["cid"],
          "traceStatus" => "committed",
          "tracedAt" => now,
          "missionCid" => grounding["missionCid"],
          "personaCid" => grounding["personaCid"],
          "goalCid" => grounding["goalCid"],
          "valuePropositionCid" => grounding["valuePropositionCid"],
          "ledgerPlacement" => "canonical",
          "profileId" => "osi-level-8/profile-10",
          "state" => "committed"
        }
        digest = Digest::SHA256.hexdigest(JSON.generate(payload))
        payload["digest"] = "sha256:#{digest}"
        payload["cid"] = "cid:sha256:#{Digest::SHA256.hexdigest("trace:#{effect_cid}:#{digest}")}"
        payload["@id"] = payload["cid"]

        result = Validator.validate(payload)
        raise KnownRefusal.new(result.reason, result.because) unless result.conforms?

        GraphStore.put!(payload)
      end

      def resolve_grounding(grounding_cid:, journey:)
        if grounding_cid.to_s != ""
          return GraphStore.get(grounding_cid)
        end
        return nil unless journey

        Grounding.for_journey(journey).first
      end
      private_class_method :resolve_grounding
    end
  end
end
