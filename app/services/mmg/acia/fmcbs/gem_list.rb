# frozen_string_literal: true

module Mmg
  module Acia
    module Fmcbs
      # GemList -- the real READ-ONLY action `gem_list` wrapped as a PURE Fmcb (epic_65 rollout). Reproduces
      # gem_list's envelope from the SURFACE ALONE: surface.inventory (Pattern::Registry entries responding
      # to name/version/root_path/pattern_exec/discovery_source). PURE: no registry read, no graph write --
      # testable by mocking the substrate down to that surface. A READ has no proposed state change
      # (triples: []); the read RESULT rides in the Proposal tree. Envelope parity proven in spec. Never-raise.
      class GemList < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          entries = (surface.respond_to?(:inventory) ? ::Kernel.Array(surface.inventory) : [])
          gems = entries.map do |e|
            {
              name:             e.name,
              version:          e.version,
              root_path:        e.root_path,
              pattern_exec:     e.pattern_exec,
              discovery_source: e.discovery_source,
              queryable:        !e.pattern_exec.nil?
            }
          end
          Proposal.new(tree: { ok: true, gems: gems, count: gems.length }, triples: [])
        end

        # The projected ENVELOPE = the read result (the value a delegating handler returns).
        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end
      end
    end
  end
end
