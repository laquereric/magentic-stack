# frozen_string_literal: true

module Vv
  module Orinth
    module Cpcp
      module_function

      def register!
        # The guard is .project, not the module. Bundler evaluates every path
        # gemspec at setup, so under the root bundle ::RailsCpcp is already
        # defined with ONLY VERSION, the seam never required -- a defined?-only
        # guard walks into NoMethodError there instead of refusing.
        unless defined?(::RailsCpcp) && ::RailsCpcp.respond_to?(:project)
          return { ok: false, reason: :cpcp_absent, because: "rails-cpcp is not loaded" }
        end

        # Register the names so the surface exists; via always hits the v1 gate
        # until plants land. That is the point of an executable blocker.
        via_gate = ->(p, _c) { V1Binding.bind! }

        ::RailsCpcp.project(model: "Orinth") do
          operation "ornith.task.put", direction: :push, params: %w[operationId],
            summary: "Envelope 1. Blocked until v1 plants.", via: via_gate
          operation "ornith.scaffold.put", direction: :push, params: %w[operationId task_digest],
            summary: "Envelope 2.", via: via_gate
          operation "ornith.rollout.put", direction: :push, params: %w[operationId task_digest scaffold_digest],
            summary: "Envelope 3.", via: via_gate
          operation "ornith.reward.put", direction: :push, params: %w[operationId rollout_digest],
            summary: "Envelope 4.", via: via_gate
          operation "ornith.monitor.put", direction: :push, params: %w[operationId rollout_digest],
            summary: "Envelope 5.", via: via_gate
          operation "ornith.cycle.put", direction: :push, params: %w[operationId],
            summary: "All five envelopes, one operationId.", via: via_gate
          operation "ornith.grpo", direction: :push, params: %w[operationId],
            summary: "MIND GRPO step. Does not promote Gold.", via: via_gate
        end

        Refusal.ok(operations: Operations.names)
      end
    end
  end
end
