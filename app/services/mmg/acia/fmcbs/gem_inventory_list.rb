# frozen_string_literal: true

module Mmg
  module Acia
    module Fmcbs
      # GemInventoryList -- the real READ-ONLY action `gem_inventory_list` wrapped as a PURE Fmcb (epic_65
      # rollout). Reproduces the envelope from the SURFACE ALONE: surface.list (the canonical per-gem
      # inventory rows). PURE: no yaml/inventory read, no graph write -- testable by mocking the substrate
      # down to that surface. A READ has no proposed state change (triples: []); the read RESULT rides in the
      # Proposal tree. Envelope parity with the gem_inventory_list handler is proven in spec. Never-raise.
      class GemInventoryList < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          gems = (surface.respond_to?(:list) ? ::Kernel.Array(surface.list) : [])
          Proposal.new(tree: { ok: true, count: gems.size, gems: gems }, triples: [])
        end

        # The projected ENVELOPE = the read result (the value a delegating handler returns).
        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end
      end
    end
  end
end
