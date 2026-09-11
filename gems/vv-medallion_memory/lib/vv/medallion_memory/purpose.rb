# frozen_string_literal: true

module Vv
  module MedallionMemory
    # Build, Consume and Operate are SIBLINGS. None of them is a tier.
    #
    # Mirrors mmg-medallion's Purpose (build / consume / operate). M7 in
    # plan_vv_medallion_memory.md asks for purpose to be CARRIED rather than only
    # documented, and gives the reason plainly: it "stops Platinum sneaking into
    # CANONICAL_ROWS". If the only way to express "serving Gold" or "distil
    # offline" were to invent a rank, someone would invent a rank.
    module Purpose
      BUILD   = "build"    # the three tiers; each has a unique state change
      CONSUME = "consume"  # projection / read-model plane. Serving Gold lives here
      OPERATE = "operate"  # governance, decay, distillation. Platinum lives here

      ALL = [BUILD, CONSUME, OPERATE].freeze

      module_function

      def known?(p) = ALL.include?(p.to_s)
    end
  end
end
