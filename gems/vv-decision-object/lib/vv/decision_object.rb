# frozen_string_literal: true

require_relative "decision_object/version"

module Vv
  # A decision as a durable, inspectable, governable object rather than a
  # moment, a memo, or a model output.
  #
  # The term arrived from four directions at once — a rules table (DMN,
  # Appian), a proposal bundled with its constraints (agent literature), a
  # recorded outcome (decision intelligence), and a six-layer ontology
  # (Decision Object Theory). Those are not interchangeable, so this gem
  # takes the parts with running code and makes them one record:
  #
  #   Vv::DecisionObject::Definition — the six layers, declared
  #   Vv::DecisionObject::Question   — Choice, Score, Noul (Jev's primitives)
  #   Vv::DecisionObject::Table      — DMN-style rules, deterministic
  #   Vv::DecisionObject::Constraint — boundaries, checked in code, first
  #   Vv::DecisionObject::Policy     — thresholds calibrated by consequence
  #   Vv::DecisionObject::Decision   — one situation, traced end to end
  #   Vv::DecisionObject::Audit      — the five named failure modes
  #
  # The separation it enforces: code keeps arithmetic, permissions and
  # side effects; a model supplies bounded semantic judgment; a threshold
  # someone chose on purpose stands between the two. Never raises.
  module DecisionObject
    # Layers of the object, in the order they are evaluated.
    LAYERS = %i[intent constraint signal evaluation commitment feedback].freeze

    # Named failure modes the Audit module looks for.
    FAILURE_MODES = %i[
      signal_degradation
      constraint_drift
      metric_myopia
      feedback_suppression
      over_automation
    ].freeze
  end
end

require_relative "decision_object/envelope"
require_relative "decision_object/question"
require_relative "decision_object/answer"
require_relative "decision_object/constraint"
require_relative "decision_object/table"
require_relative "decision_object/policy"
require_relative "decision_object/lifecycle"
require_relative "decision_object/trace"
require_relative "decision_object/decision"
require_relative "decision_object/definition"
require_relative "decision_object/adapters"
require_relative "decision_object/audit"

module Vv
  module DecisionObject
    class << self
      # Declare a decision object.
      #
      #   result = Vv::DecisionObject.define(:route_ticket) do |d|
      #     d.intent "Route the ticket to the team that can close it"
      #     d.signal :subject, :body, :tier
      #     d.choice(:route, instructions: "...", criteria: { ... })
      #     d.thresholds floors: { route: 0.8 }
      #     d.commit_to :assign_team
      #     d.track :resolved, :reopened
      #   end
      #
      # @return [Hash] `{ ok: true, data: Definition }` or a refusal
      #   naming every problem at once.
      def define(name, version: 1, &block)
        Definition.define(name, version: version, &block)
      end

      # Define and instantiate in one call, for the common case where the
      # definition is built per-request rather than held as a constant.
      #
      # @return [Hash] `{ ok: true, data: Decision }` or a refusal
      def open(name, state: {}, actor: nil, version: 1, &block)
        defined = define(name, version: version, &block)
        return defined unless defined[:ok]

        defined[:data].instantiate(state: state, actor: actor)
      end

      def audit(decisions, **overrides)
        Audit.run(decisions, **overrides)
      end
    end
  end
end
