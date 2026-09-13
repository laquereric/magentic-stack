# frozen_string_literal: true

module Vv
  module SelfLearn
    module Cpcp
      module_function

      def register!
        unless defined?(::RailsCpcp)
          return { ok: false, reason: :cpcp_absent, because: "rails-cpcp is not loaded" }
        end

        ::RailsCpcp.project(model: "Learn") do
          operation "learn.collect",
            direction: :push, params: %w[operationId gold_digest],
            summary: "Observed Bronze from PROD. Cites the Gold that served.",
            via: ->(p, _c) {
              r = Loop.collect(p)
              next r unless r[:ok]

              Store.collect(r)
            }

          operation "learn.eval",
            direction: :pull, params: %w[n passes],
            summary: "Wilson eval. Deterministic grader for SHAPE. Does not promote.",
            via: ->(p, _c) {
              r = Loop.eval(p.merge("role" => p["role"]))
              next r unless r[:ok]

              Store.save_eval(r)
            }

          operation "learn.recommend",
            direction: :pull,
            summary: "Latest eval. recommend:true is not a promote.",
            via: ->(p, _c) { Store.last_eval || Loop.recommend(p) }
        end

        Refusal.ok(operations: Operations.names)
      end
    end
  end
end
