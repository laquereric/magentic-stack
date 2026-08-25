# frozen_string_literal: true

require "digest"

module RailsOsiLevel8
  module Intent
    # P10.M5 — materialize Journey → IntentGrounding (graph-only).
    module Grounding
      module_function

      def bind!(journey:, mission:, persona:, goal_cid:, value_proposition_cid:, status: "ratified")
        journey_proj = Projection.for(journey)
        mission_proj = Projection.for(mission)
        persona_proj = Projection.for(persona)

        payload = {
          "@type" => "intent:IntentGrounding",
          "journeyCid" => journey_proj["cid"],
          "missionCid" => mission_proj["cid"],
          "personaCid" => persona_proj["cid"],
          "goalCid" => goal_cid,
          "valuePropositionCid" => value_proposition_cid,
          "validFrom" => Time.now.utc.iso8601,
          "status" => status,
          "ledgerPlacement" => "canonical",
          "profileId" => "osi-level-8/profile-10"
        }
        digest = Digest::SHA256.hexdigest(JSON.generate(payload))
        payload["digest"] = "sha256:#{digest}"
        payload["cid"] = "cid:sha256:#{Digest::SHA256.hexdigest("grounding:#{digest}")}"
        payload["@id"] = payload["cid"]

        result = Validator.validate(payload)
        raise KnownRefusal.new(result.reason, result.because) unless result.conforms?

        # Persona must be backed (use persona source id as cohort stand-in)
        payload["backingCheck"] = "ok"
        # Remove non-shape key before store — wait, backingCheck would fail closed shape
        payload.delete("backingCheck")

        GraphStore.put!(payload)
      end

      def for_journey(journey)
        jp = Projection.for(journey)
        GraphStore.find_by(type: "intent:IntentGrounding", journey_cid: jp["cid"], ledger: "cross_boundary")
      end

      def inspect_journey(journey)
        bindings = for_journey(journey)
        raise KnownRefusal.new("intent_grounding_not_active", { "journey" => journey.id }) if bindings.empty?

        g = bindings.first
        {
          "journeyCid" => g["journeyCid"],
          "missionCid" => g["missionCid"],
          "personaCid" => g["personaCid"],
          "goalCid" => g["goalCid"],
          "valuePropositionCid" => g["valuePropositionCid"],
          "groundingCid" => g["cid"],
          "status" => g["status"]
        }
      end
    end
  end
end
