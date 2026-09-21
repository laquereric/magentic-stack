# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # J1 — Assure an effect is authorized. One vertical through
    # Actor → Journey → Flow → FlowStep → Page cites.
    #
    # When vv-base tables exist, the Journey/Flow CIDs are
    # Intent::Projection.for of real rows. When they do not (gem specs),
    # Graph keeps the memory fixture CIDs so P9 stays seedable without AR.
    module J1
      ROLE_KEY = "governance-steward"
      JOURNEY_TITLE = "Assure an effect is authorized"
      FLOW_TITLE = "Review and decide authorization"
      STEP_KEY = "decide"
      # ADR 0074. Identity is the natural key, not the title. JOURNEY_TITLE and
      # FLOW_TITLE are kept because callers and specs still display them, but
      # nothing looks a row up by them any more.
      BUNDLE_KEY = "mind-pod"
      JOURNEY_KEY = "assure-an-effect-is-authorized"
      FLOW_KEY = "review-and-decide-authorization"
      SEED_ROOT = ::File.expand_path("../../../db/seed/profile9", __dir__)
      ROUTE_KEY = "authorization-review"
      MODEL_KEY = "j1-authorization-decision"
      GOAL_CID = "cid:goal:j1-authorize"
      VALUE_PROPOSITION_CID = "cid:vp:j1-authorize"

      module_function

      def ready?
        defined?(::Vv::Base::Journey) &&
          defined?(::Vv::Base::FlowStep) &&
          defined?(::ActiveRecord::Base) &&
          ::Vv::Base::Journey.table_exists? &&
          ::Vv::Base::FlowStep.table_exists?
      rescue StandardError
        false
      end

      def seed!
        return nil unless ready?

        # ADR 0074 decision 4. This was forty lines of find_or_initialize_by,
        # and it was one of the two callers that gave `journeys` two different
        # idempotence keys. The rows are data; the loader applies them.
        result = ::Vv::Base::Seeder.load!(seed_root: SEED_ROOT, bundle_key: BUNDLE_KEY)
        raise "J1 seed refused: #{result[:reason]} -- #{result[:because]}" unless result[:ok]

        actor = ::Vv::Base::Actor.find_by!(bundle_key: BUNDLE_KEY, role_key: ROLE_KEY)
        journey = ::Vv::Base::Journey.find_by!(bundle_key: BUNDLE_KEY, journey_key: JOURNEY_KEY)
        flow = journey.flows.find_by!(flow_key: FLOW_KEY)
        step = flow.steps.find_by!(step_key: STEP_KEY)
        model = ::Vv::Base::InformationModel.find_by!(bundle_key: BUNDLE_KEY, key: MODEL_KEY)

        mission = ::Vv::Base::Mission.find_or_initialize_by(title: "Governed authorization")
        mission.body = "Every committed Effect traces to a declared purpose"
        mission.status = "ratified"
        mission.ledger_placement = "canonical"
        mission.save!

        persona = ::Vv::Base::Persona.find_or_initialize_by(name: "Governance steward")
        persona.summary = "Accountable operator who reviews proposed Effects"
        persona.status = "ratified"
        persona.ledger_placement = "canonical"
        persona.save!

        grounding_cid = bind_grounding!(journey: journey, mission: mission, persona: persona)

        {
          actor: actor,
          journey: journey,
          flow: flow,
          step: step,
          model: model,
          mission: mission,
          persona: persona,
          grounding_cid: grounding_cid,
          actor_cid: proj(actor)["cid"],
          journey_cid: proj(journey)["cid"],
          flow_cid: proj(flow)["cid"]
        }
      end

      def bind_grounding!(journey:, mission:, persona:)
        existing = RailsOsiLevel8::Intent::Grounding.for_journey(journey)
        return existing.first["cid"] if existing.any?

        rec = RailsOsiLevel8::Intent::Grounding.bind!(
          journey: journey,
          mission: mission,
          persona: persona,
          goal_cid: GOAL_CID,
          value_proposition_cid: VALUE_PROPOSITION_CID,
          status: "ratified"
        )
        rec["cid"]
      end
      private_class_method :bind_grounding!

      def proj(record)
        RailsOsiLevel8::Intent::Projection.for(record)
      end
      private_class_method :proj
    end
  end
end
