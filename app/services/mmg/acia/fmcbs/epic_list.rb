# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Fmcbs
      # EpicList -- the real READ-ONLY action `epic_list` wrapped as a PURE Fmcb (epic_65 rollout). It
      # reproduces epic_list's envelope from the SURFACE ALONE: `surface.epics(all:)` (a list of duck-typed
      # epics responding to name/title/status/display_status/priority/plans/arcs) + `surface.top_priority`.
      # PURE: no AR query of Mm::DevInfo::Epic, no graph write -- testable by MOCKING the substrate down to
      # that surface. A READ has no proposed state change (triples: []); the read RESULT rides in the
      # Proposal `tree`. Envelope parity with the epic_list handler is proven in spec. Never-raise.
      class EpicList < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          all   = (input[:all] == true || input["all"] == true)
          epics = (surface.respond_to?(:epics) ? ::Kernel.Array(surface.epics(all: all)) : [])
          top   = (surface.respond_to?(:top_priority) ? surface.top_priority.to_i : 0)
          rows  = epics.map do |e|
            {
              name:           e.name,
              title:          e.title,
              status:         e.status,
              display_status: e.display_status,
              priority:       e.priority.to_i,
              top:            e.priority.to_i >= top && top.positive?,
              plan_count:     (e.plans || []).size,
              arc_count:      (e.arcs  || []).size
            }
          end
          Proposal.new(tree: { ok: true, count: rows.size, top_priority: top, epics: rows }, triples: [])
        end

        # The projected ENVELOPE = the read result (the value a delegating handler returns).
        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end
      end
    end
  end
end
