# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Fmcbs
      # ArcList -- the read-only action `arc_list` (the pending-sign-off queue) wrapped as a PURE Fmcb.
      # Reproduces arc_list's envelope from `surface.arcs(status:, limit:)` alone (each a duck-typed arc
      # responding to id/status/title/branch/briefs/branch_opened_at/created_at). PURE: no AR query, no
      # graph write. A READ has no proposed state change (triples: []); the result rides in the tree.
      class ArcList < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          status = (input[:status] || input["status"] || "pending_signoff").to_s.strip
          limit  = (input[:limit] || input["limit"] || 50).to_i
          limit  = 50 if limit <= 0
          arcs   = (surface.respond_to?(:arcs) ? ::Kernel.Array(surface.arcs(status: status, limit: limit)) : [])
          rows   = arcs.map do |arc|
            {
              id:               arc.id,
              status:           arc.status,
              title:            arc.title,
              branch:           arc.branch,
              brief_ids:        ::Kernel.Array(arc.briefs).map { |b| b.respond_to?(:id) ? b.id : b },
              branch_opened_at: arc.branch_opened_at&.iso8601,
              created_at:       arc.created_at&.iso8601
            }
          end
          Proposal.new(tree: { ok: true, status: status, count: rows.size, arcs: rows }, triples: [])
        end

        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end
      end
    end
  end
end
