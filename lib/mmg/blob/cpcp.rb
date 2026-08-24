# frozen_string_literal: true

module Mmg
  module Blob
    # Registers the blob operations on the CPCP seam, so an LLM reaches storage
    # through exactly the surface everything else reaches it through -- shape
    # gated, operationId required on writes, refusals as envelopes.
    #
    # Call from an initializer. Skipped silently when rails-cpcp is absent, so
    # the gem stays usable outside a Rails app.
    module Cpcp
      module_function

      def register!
        return { ok: false, reason: :cpcp_absent, because: "rails-cpcp is not loaded" } unless defined?(::RailsCpcp)

        ::RailsCpcp.project(model: "Blob") do
          operation "blob.put", direction: :push, params: %w[operationId bytes date name description],
            summary: "Store bytes with a date, name and description; returns the sha256 digest",
            via: ->(p, _ctx) { Mmg::Blob::Operations.put(p) }

          operation "blob.get", direction: :pull, params: %w[digest],
            summary: "Fetch bytes by digest (returned base64)",
            via: ->(p, _ctx) { Mmg::Blob::Operations.get(p) }

          operation "blob.stat", direction: :pull, params: %w[digest],
            summary: "Size and content type without moving the bytes",
            via: ->(p, _ctx) { Mmg::Blob::Operations.stat(p) }

          operation "blob.entries", direction: :pull, params: %w[digest], result: :collection,
            summary: "Every filing of these bytes: date, name, description",
            via: ->(p, _ctx) { Mmg::Blob::Operations.entries(p) }

          operation "blob.list", direction: :pull, result: :collection,
            summary: "Recent digests, newest first",
            via: ->(p, _ctx) { Mmg::Blob::Operations.list(p) }
        end

        { ok: true, operations: %w[blob.put blob.get blob.stat blob.entries blob.list] }
      end
    end
  end
end
