# frozen_string_literal: true

module Vv
  module MedallionMemory
    # Exactly three Build tiers. Platinum is refused BY NAME.
    #
    # plan_vv_medallion_memory.md restates the PDF's §4.4 warning as a substrate
    # rule: parametric memory breaks the medallion's core guarantee because it
    # has no tombstone. A fact cannot be deleted from a weight matrix the way a
    # row is dropped, and a weight update leaves no audit trail for the
    # provenance of the shift. So Platinum is not a fourth Build tier, and
    # neither is Serving, and neither is Working.
    #
    # This mirrors mmg-medallion's Tier::CANONICAL_ROWS rather than replacing it.
    # The engine is the authority; this is the memory product's copy of the
    # contract, and a gate compares the two so they cannot drift apart in
    # silence. Duplicating the rows without that comparison would be how the
    # fork the plan forbids starts.
    module Tier
      CANONICAL = [
        { slug: "bronze", rank: 1, memory: "Raw episodic log",
          guarantees: "Immutability, replay, full provenance. Nothing overwritten." },
        { slug: "silver", rank: 2, memory: "Resolved entities + timestamped facts",
          guarantees: "Stable identity, typing, temporal validity, dedup, contradiction." },
        { slug: "gold", rank: 3, memory: "Task-shaped knowledge",
          guarantees: "Relevance, abstraction, fit inside a hard context budget." }
      ].map(&:freeze).freeze

      BY_SLUG = CANONICAL.each_with_object({}) { |r, h| h[r[:slug]] = r }.freeze

      SLUGS = CANONICAL.map { |r| r[:slug] }.freeze

      # Names that get proposed as a fourth tier, and the reason each is not one.
      # Kept explicit because a refusal that cannot say WHY reads as an oversight
      # and gets "fixed" by the next person to want the tier.
      NOT_TIERS = {
        "platinum" => "knowledge folded into weights has no tombstone; it is Purpose::OPERATE, " \
                      "an optional rebuildable cache distilled from SILVER, never from Gold-as-weights",
        "serving" => "serving is Consume: Gold injected under a token budget every turn, " \
                     "not a Build rank of its own",
        "working" => "the live context window is VOLATILE BRONZE, session-scoped; " \
                     "calling it a tier is how a session cache becomes a weight update with no receipt"
      }.freeze

      module_function

      def build?(slug)
        BY_SLUG.key?(slug.to_s)
      end

      def for(slug)
        BY_SLUG[slug.to_s]
      end

      def rank(slug)
        row = BY_SLUG[slug.to_s]
        row && row[:rank]
      end

      # nil when the slug is a legitimate Build tier; a refusal otherwise.
      #
      # Returning a refusal rather than raising is deliberate: this is called on
      # a request path where the answer is an envelope, and the caller that
      # passed `tier: platinum` needs to be told which rule it hit, not handed
      # an exception to translate.
      def refuse(slug)
        slug = slug.to_s
        return nil if build?(slug)

        if (why = NOT_TIERS[slug])
          reason = slug == "platinum" ? Refusal::PLATINUM_NOT_A_TIER : Refusal::AUDIT_REJECTED
          return Refusal.build(reason, "#{slug} is not a Build tier: #{why}")
        end

        Refusal.build(Refusal::AUDIT_REJECTED,
                      "unknown tier #{slug.inspect}; the Build tiers are #{SLUGS.join(', ')}")
      end

      # The promotion ladder. Bronze promotes on identity+timestamp, Silver on
      # consolidation. There is no successor to Gold -- which is the point.
      def successor(slug)
        SLUGS[SLUGS.index(slug.to_s).to_i + 1] if build?(slug)
      end
    end
  end
end
