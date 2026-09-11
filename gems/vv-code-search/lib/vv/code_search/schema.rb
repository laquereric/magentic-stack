# frozen_string_literal: true

module Vv
  module CodeSearch
    # A repo-family schema: which dimensions this kind of tree builds.
    #
    # plan_vv-code-search calls the gem "semi-custom" and means something
    # specific by it -- a shared engine with a schema PER REPO FAMILY, not one
    # generic embedding of every repo on GitHub. A Rails gem galaxy and a
    # lockfile-heavy JS tree want different dimensions built, and pretending
    # otherwise is how you end up paying to embed a call graph.
    #
    # The schema id is part of the index identity. Two schemas over the same
    # (repo, fork, rev) produce two different digests and never merge, which is
    # one of the doc's gates: "Two schemas for the same (repo, rev) must not
    # silently merge."
    class Schema
      REGISTRY = {}

      attr_reader :id, :dimensions, :why

      def initialize(id:, dimensions:, why:)
        @id = id
        @dimensions = dimensions.freeze
        @why = why
        freeze
      end

      # The hot union: the dimensions a lookup is allowed to consult.
      #
      # A dimension that is not a point query is REFUSED here rather than
      # tolerated and measured later, because by the time a scan has blown the
      # one-second budget the hover is already late. The doc's rule -- "if a
      # dimension cannot answer by line in < 1 s, it is not in the hot union;
      # it stays batch" -- is enforced at registration, not at request time.
      def self.register(id:, dimensions:, why:)
        scanners = dimensions.reject(&:point_query?)
        unless scanners.empty?
          raise ArgumentError,
                "schema #{id.inspect} would admit scan-shaped dimension(s) " \
                "#{scanners.map(&:name).join(', ')} to the hot union; a dimension that " \
                "cannot answer by line stays batch (plan_vv-code-search, 'the < 1 s bound')"
        end

        REGISTRY[id] = new(id: id, dimensions: dimensions, why: why)
      end

      def self.named(id)
        REGISTRY[id]
      end

      def self.ids = REGISTRY.keys.sort

      def dimension(name)
        dimensions.find { |d| d.name == name }
      end

      def names = dimensions.map(&:name)
    end
  end
end
