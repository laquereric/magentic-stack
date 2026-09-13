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

        actor = ::Vv::Base::Actor.find_or_initialize_by(role_key: ROLE_KEY)
        actor.name = "Governance steward" if actor.name.to_s.empty?
        actor.ledger_placement = "canonical" if actor.respond_to?(:ledger_placement)
        actor.save!

        journey = ::Vv::Base::Journey.find_or_initialize_by(title: JOURNEY_TITLE, primary_actor_id: actor.id)
        journey.goal = "Commit or safely refuse a proposed Effect on valid delegation"
        journey.scenario = "Steward inspects Profile-6 evidence and commits approve or deny"
        journey.status = "active"
        journey.ledger_placement = "canonical"
        journey.save!

        flow = journey.flows.find_or_initialize_by(title: FLOW_TITLE)
        flow.task_goal = "Authorize or refuse the proposed effect on one page"
        flow.status = "draft"
        flow.ledger_placement = "canonical"
        flow.save!

        model = ::Vv::Base::InformationModel.find_or_initialize_by(key: MODEL_KEY)
        model.title = "Authorization decision"
        model.subject_type = "P6::AuthorizationDecisionEffect"
        model.ledger_placement = "canonical"
        model.save!
        unless model.fields.exists?(name: "decision")
          model.fields.create!(
            name: "decision", datatype: "enum", required: true,
            cardinality: "1", enum_key: "approve-deny", ordinal: 1
          )
        end

        step = flow.steps.find_or_initialize_by(step_key: STEP_KEY)
        step.ordinal = 1
        step.title = "Authorization review"
        step.kind = "decide"
        step.information_model = model
        step.route_key = ROUTE_KEY
        step.ledger_placement = "canonical"
        step.save!
        flow.update!(status: "active") unless flow.status == "active"

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
