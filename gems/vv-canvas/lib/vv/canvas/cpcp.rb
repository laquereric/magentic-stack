# frozen_string_literal: true

module Vv
  module Canvas
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

        ::RailsCpcp.project(model: "Blob") do
          operation "blob.put",
            direction: :push, params: %w[operationId bytes date name description],
            summary: "Store canvas bytes; digest is the name. graph_iri refused in BlobGate.",
            via: ->(p, _c) { BlobGate.put(p) }

          operation "blob.get",
            direction: :pull, params: %w[digest],
            summary: "Fetch bytes by digest (base64)",
            via: ->(p, _c) { BlobGate.get(p) }

          operation "blob.list",
            direction: :pull,
            summary: "Recent digests, newest first",
            via: ->(p, _c) { BlobGate.list(p) }

          operation "blob.stat",
            direction: :pull, params: %w[digest],
            summary: "Size without moving the bytes",
            via: ->(p, _c) { BlobGate.stat(p) }
        end

        ::RailsCpcp.project(model: "Board") do
          operation "board.list",
            direction: :pull, result: :collection,
            summary: "Named boards (title + blob digest)",
            via: ->(p, _c) { Boards.list(p) }

          operation "board.get",
            direction: :pull, params: %w[id],
            summary: "One named board",
            via: ->(p, _c) { Boards.get(p) }

          operation "board.put",
            direction: :push, params: %w[operationId title blobDigest],
            summary: "Save a board row citing a blob digest.",
            via: ->(p, _c) { Boards.put(p) }
        end

        { ok: true, operations: %w[blob.put blob.get blob.list blob.stat board.list board.get board.put] }
      end
    end
  end
end
