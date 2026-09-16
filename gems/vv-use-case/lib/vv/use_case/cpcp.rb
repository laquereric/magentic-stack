# frozen_string_literal: true

module Vv
  module UseCase
    module Cpcp
      module_function

      def register!
        unless defined?(::RailsCpcp)
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
