# frozen_string_literal: true

module Vv
  module MedallionMemory
    # M-home, answered.
    #
    # This file used to be the blocker made executable: plan_vv_medallion_memory.md
    # ended on six open questions and the first one gated the rest, so every path
    # into the engine answered medallion_home_undecided until an owner named the
    # home. That was the right behaviour while the engine lived in a gitignored
    # nested repo inside magentic-market-ai, which cannot be pinned as a closed
    # substrate dependency (ADR 0038).
    #
    # DECIDED 2026-09-15: home is :stack. mmg-medallion 0.2.0 was promoted into
    # this repo's gems/, added to the root Gemfile, and retargeted at
    # magentic-stack. That is phase 1 of docs/plans/medallion-memory-primitives.md.
    #
    # The decision did NOT write the engine. M1-M10 are all still pending, and
    # that was measured on the promoted source rather than assumed: audit! is
    # absent, the conformer still reports engine "pragmatic_shacl_v0", and there
    # is no cascade, no temporal column, no decay policy.
    #
    # So bind! still refuses -- but for a true reason. Continuing to answer
    # medallion_home_undecided would report a settled question as open, which is
    # the same defect in the other direction: a refusal whose reason is wrong
    # sends the reader to fix the wrong thing.
    module EngineBinding
      HOME = :stack

      HOMES = {
        stack: "mmg-medallion is a first-party gem in this repo's gems/; M1-M10 land there " \
               "and MM consumes it the way other stack gems are consumed",
        mm_pin: "REJECTED 2026-09-15. Keeping it in magentic-market-ai behind a published pin " \
                "was the alternative; the promotion closed it"
      }.freeze

      # The changes the plan requires of the engine, in the order it gives them.
      # Named so a refusal can say what it waits for rather than only that it waits.
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

      # The plan's own precondition for a successful bind!: "once mmg-medallion
      # is loadable from gems/ AND audit! exists". Both are ASKED, not declared,
      # so this flips to ok the moment M3 lands and nobody has to remember to
      # edit this file. A hand-maintained `landed:` list is a claim that rots.
      module_function

      def engine
        return nil unless defined?(::Mmg::Medallion)

        ::Mmg::Medallion
      end

      def engine_loadable? = !engine.nil?

      def audit_landed? = engine.respond_to?(:audit!)

      def landed
        return [] unless engine_loadable?

        [].tap do |m|
          m << "M3" if audit_landed?
          m << "M4" if engine.respond_to?(:provenance_required_on_land?) && engine.provenance_required_on_land?
          if engine.const_defined?(:Flow)
            flow = engine.const_get(:Flow)
            m << "M7" if flow.is_a?(Class) && flow.instance_methods.include?(:purpose)
          end
          m << "M9" if engine.respond_to?(:cascade)
        end
      end

      def still_pending = PENDING.reject { |k, _| landed.include?(k) }

      def bind!(home: nil)
        asked = (home || HOME).to_sym
        unless asked == HOME
          return Refusal.build(
            Refusal::MEDALLION_HOME_UNDECIDED,
            "#{Refusal::WHEN[Refusal::MEDALLION_HOME_UNDECIDED]}. Asked for #{asked}: " \
            "#{HOMES.fetch(asked, 'not a home this gem knows')}"
          )
        end

        unless engine_loadable?
          return Refusal.build(
            Refusal::ENGINE_NOT_LANDED,
            "home is :stack (gems/mmg-medallion) but Mmg::Medallion is not loadable from here; " \
            "the gem is promoted, this process has not required it"
          )
        end

        unless audit_landed?
          return Refusal.build(
            Refusal::ENGINE_NOT_LANDED,
            "home is :stack and mmg-medallion #{engine_version} is loadable, but audit! is absent. " \
            "M3 is the plan's precondition for binding. Still pending: " \
            "#{still_pending.map { |k, v| "#{k} (#{v})" }.join('; ')}"
          )
        end

        Refusal.ok(home: HOME, engine: "mmg-medallion #{engine_version}",
                   landed: landed, pending: still_pending)
      end

      def engine_version
        engine && engine.const_defined?(:VERSION) ? engine.const_get(:VERSION) : "unknown"
      end

      # The home question is closed. Whether the engine is usable is a different
      # question, and bind! is where that one is answered.
      def undecided? = false
    end
  end
end
