# frozen_string_literal: true

module Vv
  module DependencyOrch
    # Nodes and edges, and the three questions.
    #
    # The graph is computable with ZERO reachable placements. That is a
    # requirement rather than a nicety: if the graph needed a live daemon, then
    # `drift` could not report `unreachable` -- it would simply fail, and a tool
    # that fails when the network is down cannot be the tool that tells you the
    # network is down.
    class Graph
      attr_reader :resources, :edges

      def initialize
        @resources = {}          # digest => Resource
        @edges = []
        @out = Hash.new { |h, k| h[k] = [] }
        @in = Hash.new { |h, k| h[k] = [] }
      end

      def add_resource(resource)
        existing = @resources[resource.digest]
        if existing
          resource.names.each { |n| existing.observe_name(n) }
          resource.placements.each_value { |p| existing.observe(p) }
          return existing
        end
        @resources[resource.digest] = resource
      end

      def add_edge(edge)
        return edge if @edges.include?(edge)

        @edges << edge
        @out[edge.from] << edge
        @in[edge.to] << edge
        edge
      end

      def [](digest) = @resources[digest]

      def of_kind(kind)
        return @resources.values if kind.nil?

        @resources.values.select { |r| r.kind == kind.to_sym }
      end

      # Name or digest or digest-prefix in, one resource out -- or a refusal.
      #
      # It refuses rather than picks. `ambiguous_reference` exists because the
      # alternative to refusing is choosing the first match, and the first match
      # is an artefact of hash ordering. A resource manager that silently picks
      # one of two digests is worse than one that cannot look things up.
      def resolve(reference)
        ref = reference.to_s.strip
        return Envelope.refuse("no_such_resource", "empty reference") if ref.empty?

        return Envelope.ok(resource: @resources[ref]) if @resources.key?(ref)

        parsed = Identity.parse(ref)
        # A tag was supplied. Pass the refusal through unchanged -- rewriting it
        # as no_such_resource would hide the actual mistake, which is not that
        # we could not find it but that it was never a key.
        return parsed if !parsed[:ok] && parsed[:reason] == "tag_is_not_identity"

        matches = if Identity.prefix?(ref)
                    @resources.values.select { |r| r.digest.start_with?(ref) }
                  else
                    @resources.values.select { |r| r.names.include?(ref) }
                  end

        case matches.length
        when 0
          Envelope.refuse("no_such_resource", "nothing in this inventory matches #{ref.inspect}")
        when 1
          Envelope.ok(resource: matches.first)
        else
          Envelope.refuse(
            "ambiguous_reference",
            "#{ref.inspect} matches #{matches.length} digests: " \
            "#{matches.map { |r| Identity.short(r.digest) }.join(', ')}"
          )
        end
      end

      # Forward: what does this depend on, transitively.
      def forward(digest, depth: 3)
        traverse(digest, depth: depth, index: @out) { |edge| edge.to }
      end

      # Reverse: if this moves, what becomes wrong. THE PRODUCT.
      def reverse(digest, depth: 3)
        traverse(digest, depth: depth, index: @in) { |edge| edge.from }
      end

      # The disjoint pair, as two accessors and deliberately not three. There is
      # no `all_pin_edges` here, and adding one is the failure this model exists
      # to prevent -- see Edge::DISJOINT.
      def declares_of(node) = @in[node].select { |e| e.kind == :declares }
      def references_of(node) = @in[node].select { |e| e.kind == :references }

      def placements_of(node) = @out[node].select { |e| e.kind == :placed_at }

      def to_h
        {
          resources: @resources.values.map(&:to_h),
          edges: @edges.map(&:to_h)
        }
      end

      private

      # Breadth-first with a seen set, because the graph is not a tree and a
      # base image that carries a component that derives from the same base is
      # an ordinary shape, not a pathology.
      def traverse(start, depth:, index:)
        seen = { start => 0 }
        frontier = [start]
        collected = []
        level = 0

        while level < depth && !frontier.empty?
          level += 1
          next_frontier = []
          frontier.each do |node|
            index[node].each do |edge|
              collected << { depth: level, edge: edge }
              other = yield(edge)
              next if seen.key?(other)

              seen[other] = level
              next_frontier << other
            end
          end
          frontier = next_frontier
        end

        collected
      end
    end
  end
end
