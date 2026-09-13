# frozen_string_literal: true

module Vv
  module Orinth
    # Blocker is executable: this gem stays idle until v1 plants exist.
    # Loading vv-self-learn is not landing those plants.
    module V1Binding
      WAITING = %w[
        procedure.serve-shape.render.ghis-19
        learn.collect
        learn.eval-wilson
        learn.recommend
        deterministic-shape-grader
      ].freeze

      module_function

      def bind!(plants: nil)
        list = Array(plants)
        return Refusal.build(
          Refusal::ORNITH_V1_REQUIRED,
          "v1 plants have not landed. Waiting on: #{WAITING.join(', ')}. " \
          "Loading vv-self-learn is not a plant."
        ) if list.empty?

        missing = WAITING - list.map(&:to_s)
        unless missing.empty?
          return Refusal.build(
            Refusal::ORNITH_V1_REQUIRED,
            "home named but plants missing: #{missing.join(', ')}"
          )
        end

        Refusal.build(
          Refusal::ORNITH_V1_REQUIRED,
          "all v1 plant names were passed, but no engine change has landed — " \
          "Ornith weights are not in the pod"
        )
      end
    end
  end
end
