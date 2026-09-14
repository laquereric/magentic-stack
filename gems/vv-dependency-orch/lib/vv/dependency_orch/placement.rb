# frozen_string_literal: true

module Vv
  module DependencyOrch
    # Where a copy is, and in which of four states.
    #
    # The plan names three -- not_indexed, unreachable, absent -- and this
    # carries four, because `present` is the fourth and the other three are only
    # meaningful against it.
    #
    # THE ASYMMETRY IS THE POINT. Three of the four are cheap to produce: you
    # can return not_indexed by doing nothing, and unreachable by failing. Only
    # `absent` requires a round trip you actually completed, and `absent` is the
    # only one that is EVIDENCE. That asymmetry is exactly backwards from the
    # gravity of ordinary error handling, where the failure path is the one that
    # returns the empty list -- which is how "the VPS timed out" becomes "the
    # image is gone" and someone republishes an image that was already there.
    #
    # So the constructors are asymmetric too. `present` and `absent` are built
    # only by `Adapters::Base.round_trip`, which has a completed exit status in
    # hand; every other path in this gem can reach `unreachable` and
    # `never_looked` and cannot reach the other two.
    class Placement
      STATES = %i[present absent unreachable not_indexed].freeze

      # Only these two are evidence about the world. The gate plants an adapter
      # that times out and proves neither appears.
      COMPLETED = %i[present absent].freeze

      KINDS = %i[local_daemon registry host git_remote].freeze

      # WHICH PLACEMENT CAN ANSWER "DOES THIS EXIST".
      #
      # `absent` is evidence, but only from somewhere entitled to give it. The
      # local daemon can say an image is not on THIS MACHINE; it cannot say the
      # digest is gone, because an image that was never pulled is missing from
      # the daemon and perfectly alive in the registry. Reading the first as the
      # second is the same index-miss-reads-like-evidence failure this class
      # exists to prevent, one level up -- and it is not hypothetical: the first
      # real run of this gem reported rust:1.96.1-bookworm as declared_but_absent
      # on exactly that reasoning, for a digest Docker Hub resolves fine.
      #
      # A `host` is deliberately absent from this table. It answers "is this
      # deployed there", which is a real question and a different one; it is
      # never evidence about whether the digest exists.
      AUTHORITATIVE = {
        remote: %i[registry],
        local: %i[local_daemon],
        repo: %i[git_remote]
      }.freeze

      # Can this placement's `absent` be read as evidence about a resource of
      # this kind, or only as "not here"?
      def authoritative_for?(resource_kind)
        Array(AUTHORITATIVE[resource_kind&.to_sym]).include?(kind)
      end

      attr_reader :kind, :at, :state, :because, :details, :observed_at

      def initialize(kind:, at:, state:, because: nil, details: {}, observed_at: nil)
        raise ArgumentError, "unknown placement kind #{kind.inspect}" unless KINDS.include?(kind)
        raise ArgumentError, "unknown placement state #{state.inspect}" unless STATES.include?(state)

        @kind = kind
        @at = at
        @state = state
        @because = because
        @details = details || {}
        @observed_at = observed_at
      end

      class << self
        # The honest default. A resource starts with one of these per configured
        # placement, and an adapter upgrades it. Rendering an inventory before
        # any adapter has run therefore says "nobody looked" rather than showing
        # a suspiciously clean nothing.
        def never_looked(kind:, at:, because: nil)
          new(kind: kind, at: at, state: :not_indexed,
              because: because || "no adapter has looked at #{at}")
        end

        def unreachable(kind:, at:, because:)
          new(kind: kind, at: at, state: :unreachable, because: because)
        end

        # Deliberately not part of the public surface an adapter reaches for
        # directly -- see Adapters::Base.round_trip, which is the only caller
        # that can honestly supply `observed_at`.
        def present(kind:, at:, details: {}, observed_at: Time.now)
          new(kind: kind, at: at, state: :present, details: details, observed_at: observed_at)
        end

        def absent(kind:, at:, because:, observed_at: Time.now)
          new(kind: kind, at: at, state: :absent, because: because, observed_at: observed_at)
        end
      end

      def present? = state == :present
      def evidence? = COMPLETED.include?(state)

      # An observation may only ever REPLACE one that knows less. Without this,
      # an inventory that runs the registry adapter after a failed one would
      # quietly downgrade a present placement to not_indexed and the report
      # would change between runs for no reason in the world.
      def supersedes?(other)
        return true if other.nil?
        return false if state == :not_indexed
        return true if other.state == :not_indexed
        return true if evidence? && !other.evidence?

        # Two completed observations: the newer one wins.
        evidence? && other.evidence? && observed_at.to_f >= other.observed_at.to_f
      end

      def key = [kind, at]

      def to_h
        {
          kind: kind,
          at: at,
          state: state,
          evidence: evidence?
        }.tap do |h|
          h[:because] = because if because
          h[:observed_at] = observed_at.utc.iso8601 if observed_at
          h.merge!(details) unless details.empty?
        end
      end
    end
  end
end
