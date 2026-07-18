# frozen_string_literal: true

module Mmg
  module Acia
    module Fmcbs
      # FsGlob -- the READ half of `fs_glob` as a PURE Fmcb (epic_65 rollout). It reproduces fs_glob's
      # envelope from the SURFACE ALONE: surface.glob(pattern, limit) -> the matching workspace paths (the
      # surface encapsulates glob->regex + the WorkspaceFile projection query). PURE: no AR query, no graph
      # write (triples: []); the read RESULT rides in the Proposal tree. The handler keeps ReadCapture in the
      # effectful shell (a ctx/Turn-bound write) around this pure read. Envelope parity proven in spec.
      class FsGlob < ::Mmg::Acia::Fmcb
        DEFAULT_LIMIT = 1000

        def compute(input:, surface:)
          pattern = (input[:pattern] || input["pattern"]).to_s
          return err_("pattern_required", "pattern must be a non-empty string") if pattern.empty?

          limit = ((input[:limit] || input["limit"]) || DEFAULT_LIMIT).to_i.clamp(1, 10_000)
          paths = (surface.respond_to?(:glob) ? ::Kernel.Array(surface.glob(pattern, limit)) : [])
          Proposal.new(tree: { ok: true, pattern: pattern, paths: paths, truncated: paths.size >= limit }, triples: [])
        end

        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end

        private

        def err_(reason, because)
          Proposal.new(tree: { ok: false, reason: reason, because: because }, triples: [])
        end
      end
    end
  end
end
