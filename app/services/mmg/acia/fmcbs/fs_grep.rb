# frozen_string_literal: true

module Mmg
  module Acia
    module Fmcbs
      # FsGrep -- the READ half of `fs_grep` as a PURE Fmcb (epic_65 rollout). Reproduces fs_grep's envelope
      # from the SURFACE ALONE: surface.grep(pattern, path_pattern, limit) -> the matching lines. All input
      # validation (unknown_parameter / pattern_required / pattern_invalid) is pure and lives here; the
      # surface encapsulates the file-content grep over the WorkspaceFile projection. PURE (no graph write,
      # triples: []); the read RESULT rides in the Proposal tree. The handler keeps ReadCapture in the
      # effectful shell. Envelope parity proven in spec. Never-raise.
      class FsGrep < ::Mmg::Acia::Fmcb
        DEFAULT_LIMIT = 500
        ALLOWED_INPUT_KEYS = %i[pattern path_pattern limit turn_id].freeze

        def compute(input:, surface:)
          unknown = input.keys.map { |k| k.respond_to?(:to_sym) ? k.to_sym : k } - ALLOWED_INPUT_KEYS
          if unknown.any?
            return err_("unknown_parameter", "fs_grep does not accept #{unknown.inspect}; valid keys: #{ALLOWED_INPUT_KEYS.inspect}")
          end

          pattern      = (input[:pattern] || input["pattern"]).to_s
          path_pattern = (input[:path_pattern] || input["path_pattern"]).to_s
          path_pattern = nil if path_pattern.empty?
          return err_("pattern_required", "pattern must be a non-empty string") if pattern.empty?

          begin
            ::Regexp.new(pattern)
          rescue ::RegexpError => e
            return err_("pattern_invalid", "regex compile failed: #{e.message}")
          end

          limit   = ((input[:limit] || input["limit"]) || DEFAULT_LIMIT).to_i.clamp(1, 5_000)
          matches = (surface.respond_to?(:grep) ? ::Kernel.Array(surface.grep(pattern, path_pattern, limit)) : [])
          Proposal.new(tree: { ok: true, pattern: pattern, path_pattern: path_pattern, matches: matches, truncated: matches.size >= limit }, triples: [])
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
