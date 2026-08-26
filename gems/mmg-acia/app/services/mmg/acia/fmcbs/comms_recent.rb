# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Fmcbs
      # CommsRecent -- the real READ-ONLY action `comms_recent` wrapped as a PURE Fmcb (epic_65 rollout).
      # Reproduces comms_recent's envelope from the SURFACE ALONE: surface.recent(destination:, limit:) (the
      # most-recent grounded comms frames for a destination, read from its named graph via SPARQL). PURE: no
      # state change (triples: []); the read RESULT rides in the Proposal tree. On a surface error it returns
      # the SAME comms_recent_raised envelope the handler did (parity). Never-raise.
      class CommsRecent < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          dest   = (input[:destination] || input["destination"])
          limit  = (input[:limit] || input["limit"] || 20)
          result = surface.recent(destination: dest, limit: limit)
          Proposal.new(tree: result, triples: [])
        rescue ::StandardError => e
          Proposal.new(tree: { ok: false, reason: :comms_recent_raised, because: "#{e.class}: #{e.message}" }, triples: [])
        end

        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end
      end
    end
  end
end
