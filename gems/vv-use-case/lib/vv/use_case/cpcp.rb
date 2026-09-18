# frozen_string_literal: true

module Vv
  module UseCase
    module Cpcp
      module_function

      def register!
        # The guard is .project, not the module. Bundler evaluates every path
        # gemspec at setup, so under the root bundle ::RailsCpcp is already
        # defined with ONLY VERSION, the seam never required -- a defined?-only
        # guard walks into NoMethodError there instead of refusing.
        unless defined?(::RailsCpcp) && ::RailsCpcp.respond_to?(:project)
          return { "ok" => false, "reason" => "cpcp_absent", "because" => "rails-cpcp is not loaded" }
        end

        ::RailsCpcp.project(model: "UseCase") do
          operation "usecase.extract",
            direction: :pull,
            summary: "Derive sharedai.uc.essentials.v1 from a canvas blob.",
            via: ->(p, _c) { Share.extract(p) }

          operation "usecase.share",
            direction: :push,
            params: %w[operationId blobDigest],
            summary: "One-way push of a use-case diagram onto a new Miro board.",
            via: ->(p, _c) { Share.call(p) }
        end

        { "ok" => true, "operations" => %w[usecase.extract usecase.share] }
      end
    end
  end
end
