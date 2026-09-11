# frozen_string_literal: true

module Vv
  module MedallionMemory
    # The blocker, made executable.
    #
    # plan_vv_medallion_memory.md ends on six open questions and the first one
    # gates the rest: "M-home. Stack gems/mmg-medallion vs MM nested repo + pin.
    # The rest of M1-M10 does not start until this is named."
    #
    # A blocker that lives only as a paragraph is one nobody trips over. Someone
    # eventually needs a Conformer, does not recall which document reserved the
    # decision, and writes "a small one, just for memory" -- which is the fork
    # the plan names as a non-goal, and the next Flow forks it again.
    #
    # So the binding exists and REFUSES. Every path into the engine goes through
    # here, and every one of them answers medallion_home_undecided until an owner
    # names the home. When the decision is made this becomes a real binding and
    # nothing above it changes: the Flows, tiers, purposes and refusals were all
    # written to be true either way.
    #
    # Measured 2026-09-11: mmg-medallion 0.2.0 is its own git repo nested at
    # magentic-market-ai/gems/mmg-medallion, and the parent gitignores gems/. A
    # gitignored nested repo cannot be pinned as a closed-substrate dependency
    # (ADR 0038), which is exactly why the question is open rather than merely
    # unasked.
    module EngineBinding
      HOMES = {
        stack: "promote mmg-medallion into this repo's gems/ as a first-party stack gem; " \
               "M1-M10 land here and MM consumes it the way other stack gems are consumed",
        mm_pin: "keep it in magentic-market-ai and publish/pin it, so magentic-stack depends on " \
                "a SHA rather than a path inside a gitignore"
      }.freeze

      # The changes the plan requires of the engine, in the order it gives them.
      # Listed here so the refusal can say what is waiting rather than only that
      # something is.
      PENDING = {
        "M1" => "arm SPARQL writes through the stack's graph seam",
        "M2" => "real SHACL gate, not pragmatic_shacl_v0",
        "M3" => "implement audit!",
        "M4" => "Bronze provenance stamps",
        "M5" => "Silver temporal validity",
        "M6" => "Gold promotion requires SemanticModel + Contract",
        "M7" => "purpose carried on Flow/Tier",
        "M8" => "per-tier decay policy",
        "M9" => "deletion cascades",
        "M10" => "confidence is a stamp, never a tier rename"
      }.freeze

      module_function

      # Always a refusal, today. Deliberately not a raise: callers are on an
      # envelope path and need a reason they can branch on.
      def bind!(home: nil)
        return decided(home) if home && HOMES.key?(home.to_sym)

        Refusal.build(
          Refusal::MEDALLION_HOME_UNDECIDED,
          "#{Refusal::WHEN[Refusal::MEDALLION_HOME_UNDECIDED]}. " \
          "Waiting on: #{PENDING.map { |k, v| "#{k} (#{v})" }.join('; ')}"
        )
      end

      def decided(home)
        # Naming a home does not itself write the engine changes. This is the
        # honest answer for the moment after the decision and before M1: the
        # blocker moved, it did not vanish.
        Refusal.build(
          Refusal::MEDALLION_HOME_UNDECIDED,
          "home #{home} is a valid choice (#{HOMES[home.to_sym]}) but no engine change has landed; " \
          "M1-M10 are still pending. This refusal lifts when the binding is written, not when the " \
          "decision is made"
        )
      end

      def undecided? = true
    end
  end
end
