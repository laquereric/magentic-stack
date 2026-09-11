# frozen_string_literal: true

module Vv
  module MedallionMemory
    # The memory Flow family, declared as data.
    #
    # plan_vv_medallion_memory.md: "One engine, several Flows. Each Flow declares
    # source graph(s), target tier, shape-set, promotion policy, audit hooks."
    # These are those declarations and NOTHING ELSE. There is no Conformer here,
    # no Curator, no projection code -- the plan names forking mmg-medallion into
    # this gem as a non-goal, and a "small private Conformer, just to get going"
    # is how that fork would arrive.
    #
    # Declaring the family before the engine binding exists is worth doing on its
    # own: it fixes the six names, their sources, their targets, and which of
    # them is refused and why. When the owner names M-home, these bind to the
    # engine; nothing about them has to be renegotiated first.
    #
    # PURPOSE IS CARRIED, NOT DOCUMENTED (M7). `memory.serve` is Consume and
    # `memory.forget` is Operate -- they are SIBLINGS of Build, not ranks within
    # it. That is precisely what stops Platinum from arriving as a fourth tier:
    # if Consume and Operate had to be tiers to be expressible, someone would
    # make them tiers.
    Flow = Struct.new(:name, :source, :target, :purpose, :notes, :blocked_by, keyword_init: true) do
      def blocked? = !Array(blocked_by).empty?

      # Build flows target a tier; Consume and Operate flows do not, and asking
      # one for a tier rank is the confusion M7 exists to prevent.
      def build? = purpose == Purpose::BUILD

      def refusal
        if build? && !Tier.build?(target.to_s)
          return Tier.refuse(target)
        end

        if !build? && Tier.build?(target.to_s)
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "#{name} is #{purpose} but targets the Build tier #{target}; a Consume or Operate " \
            "thing wearing a Build rank is what lets Platinum in"
          )
        end

        if blocked?
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "#{name} is refused until #{Array(blocked_by).join(' and ')} exist"
          )
        end

        nil
      end
    end

    module Flows
      ALL = [
        Flow.new(
          name: "memory.episode", source: "journal + blob", target: "bronze",
          purpose: Purpose::BUILD,
          notes: "Land raw. Never summarise. Observed/inferred stamp.",
          blocked_by: []
        ),
        Flow.new(
          name: "memory.conform", source: "Bronze graph + blob", target: "silver",
          purpose: Purpose::BUILD,
          notes: "Entity resolution, temporal intervals, SHACL, rag upsert of CONFORMED text. " \
                 "The vector half waits on rag_write_undecided; the graph half does not.",
          blocked_by: []
        ),
        Flow.new(
          name: "memory.curate", source: "Silver graph", target: "gold",
          purpose: Purpose::BUILD,
          notes: "Requires SemanticModel + Contract. Semantic and procedural products are " \
                 "different models with different contracts.",
          blocked_by: []
        ),
        Flow.new(
          name: "memory.serve", source: "Gold graph", target: "context_frame",
          purpose: Purpose::CONSUME,
          notes: "Budget-capped ContextFrame pack built from weighted activations, not a tree " \
                 "dump. Zero-weight activations stay inspectable and are not injected.",
          blocked_by: []
        ),
        Flow.new(
          name: "memory.forget", source: "any", target: "tombstone_cascade",
          purpose: Purpose::OPERATE,
          notes: "Per-tier decay and tombstone cascade. Bronze on a legal-retention clock, " \
                 "Silver on contradiction and supersession, Gold on utility.",
          blocked_by: []
        ),
        Flow.new(
          name: "memory.distill", source: "Silver", target: "platinum_artefact",
          purpose: Purpose::OPERATE,
          notes: "v2. Rebuildable from Silver, never from Gold-as-weights. Dropped and rebuilt " \
                 "rather than patched, because a weight matrix has no tombstone.",
          # Named in the plan: refused until temporal validity (M5) and the
          # deletion cascade (M9) exist. Distilling before a tombstone can
          # cascade means a forgotten fact can be resurrected from weights, and
          # nothing downstream would be able to tell.
          blocked_by: %w[M5-temporal-validity M9-deletion-cascades]
        )
      ].freeze

      BY_NAME = ALL.each_with_object({}) { |f, h| h[f.name] = f }.freeze

      module_function

      def named(name) = BY_NAME[name.to_s]

      def build_flows = ALL.select(&:build?)

      def blocked = ALL.select(&:blocked?)

      def names = ALL.map(&:name)
    end
  end
end
