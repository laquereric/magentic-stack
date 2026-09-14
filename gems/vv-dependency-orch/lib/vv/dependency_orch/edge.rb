# frozen_string_literal: true

module Vv
  module DependencyOrch
    # Edges, not nodes, are the product.
    #
    # Five kinds cover what exists today. The pair that carries the weight is
    # `declares` / `references`, and they are kept apart for the reason
    # vv-code-search keeps them apart: THE DECLARATION IS WHERE YOU CHANGE A
    # VERSION; THE REFERENCES ARE WHAT YOU MUST RE-CHECK BECAUSE IT CHANGED.
    #
    # A maintainer asking "what do I revisit" needs the second set. A naive
    # "find the version" search returns only the first, and a merged set returns
    # both with no way to tell which is which -- which is worse than either,
    # because it looks like an answer.
    class Edge
      KINDS = {
        derives_from: "an overlay image FROM a base digest",
        declares: "the line where a version is DECIDED -- change it here",
        references: "a line that CARES when the pin moves but does not choose it",
        carries: "a base image carries a component at a version",
        placed_at: "a digest present at a placement"
      }.freeze

      # The two that must never be unioned. Named so a gate can assert on the
      # constant rather than on a comment.
      DISJOINT = %i[declares references].freeze

      attr_reader :kind, :from, :to, :where, :because

      # `where` locates the edge in the world: { repo:, path:, line: } for a
      # line-shaped edge, { at: } for a placement. It is what makes the reverse
      # answer actionable -- "these four repos" is a report, "these four lines"
      # is a work list.
      def initialize(kind:, from:, to:, where: {}, because: nil)
        raise ArgumentError, "unknown edge kind #{kind.inspect}" unless KINDS.key?(kind)

        @kind = kind
        @from = from
        @to = to
        @where = where || {}
        @because = because
      end

      def disjoint_pair? = DISJOINT.include?(kind)

      def to_h
        { kind: kind, from: from, to: to }.tap do |h|
          h[:where] = where unless where.empty?
          h[:because] = because if because
        end
      end

      def key = [kind, from, to, where[:repo], where[:path], where[:line], where[:at]]

      def ==(other) = other.is_a?(Edge) && key == other.key
      alias eql? ==

      def hash = key.hash
    end
  end
end
