# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Fmcbs
      # EditorRecent -- the real READ-ONLY action `editor_recent` wrapped as a PURE Fmcb (epic_65 rollout).
      # Reproduces editor_recent's envelope from the SURFACE ALONE: surface.recent(limit:) (the N most recent
      # editor focus events). PURE: no bridge read, no graph write (triples: []); the read RESULT rides in
      # the Proposal tree. Envelope parity proven in spec. Never-raise.
      class EditorRecent < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          limit = (input[:limit] || input["limit"] || 1).to_i
          limit = 50 if limit > 50
          events = (surface.respond_to?(:recent) ? surface.recent(limit: limit) : [])
          Proposal.new(tree: { ok: true, events: events, count: events.size }, triples: [])
        end

        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end
      end
    end
  end
end
