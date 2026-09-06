# frozen_string_literal: true

require_relative "plane"
require_relative "tier"

module Vv
  module Routing
    # One routing decision, made explicit enough to argue with.
    #
    # THE REFUSAL IS THE GEM. A production route to the cheap tier with no named
    # verifier does not get built -- not because cheap is wrong, but because the
    # argument for cheap ("tool calling is mechanical") is an argument about
    # CHECKABILITY, and on the production plane nothing checks by default. State
    # who checks, or take the frontier tier, or say plainly that the output is
    # unverified and accept it in writing.
    #
    # Synthesis routes need no such statement: the compiler, the specs and the
    # sweep are the verifier, and they run whether or not anyone remembered them.
    class Route
      class Unverified < StandardError; end

      # An explicit escape hatch. Someone who has decided that an unverified
      # production route is acceptable can say so, and the decision is then a
      # recorded string rather than an omission nobody notices.
      ACCEPTED_UNVERIFIED = :accepted_unverified

      attr_reader :task, :kind, :plane, :tier, :verifier, :because

      def initialize(task:, kind:, plane:, tier:, verifier: nil, because: nil)
        @task = task
        @kind = kind.to_sym
        @plane = plane.is_a?(Plane) ? plane : Plane.new(plane)
        @tier = tier.is_a?(Tier) ? tier : Tier.new(tier)
        @verifier = verifier
        @because = because

        refuse_unverified_production!
      end

      def verified? = !@verifier.nil?
      def unverified_accepted? = @verifier == ACCEPTED_UNVERIFIED

      # Does the tier suit the kind of work, by the article's own taxonomy? This
      # REPORTS rather than enforces: routing prose to the router tier is a
      # choice someone may make with reason, and this gem is not the place to
      # forbid it.
      def tier_suits_kind? = @tier.suits?(@kind)

      def to_h
        { task: @task, kind: @kind, plane: @plane.name, tier: @tier.name,
          verifier: @verifier, because: @because,
          tier_suits_kind: tier_suits_kind? }
      end

      private

      def refuse_unverified_production!
        return if @plane.synthesis?          # the toolchain verifies, always
        return if @tier.frontier?            # not the cheap-tier bargain
        return if verified?                  # someone named a checker

        raise Unverified, <<~WHY.strip
          #{@task.inspect} routes to the ROUTER tier on the PRODUCTION plane with no verifier.

          The case for the cheap tier is that mechanical output is checkable --
          on the SYNTHESIS plane a compiler, a spec and the sweep read it before
          anyone depends on it. On the PRODUCTION plane nothing does, unless you
          say what: a shape, a twin, a schema, a second model, a human.

          Name one in `verifier:`, take `tier: :frontier`, or pass
          `verifier: Vv::Routing::Route::ACCEPTED_UNVERIFIED` with a `because:`
          so the decision is recorded rather than merely made.
        WHY
      end
    end
  end
end
