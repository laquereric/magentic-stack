# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Fmcbs
      # EpicShow -- the real READ-ONLY action `epic_show` wrapped as a PURE Fmcb (epic_65 Stage 2). It
      # reproduces epic_show's envelope from the SURFACE ALONE: `surface.epic(id)` (a duck-typed epic that
      # responds to name/title/status/display_status/priority/summary/plans/arcs) + `surface.top_priority`
      # (the McbMap tool surface -- a subset of the substrate surface). PURE: no AR read of Mm::DevInfo::Epic,
      # no graph write -- so it is testable by MOCKING the substrate down to that surface. A READ has no
      # proposed state change, so triples: [] and the read RESULT (the never-raise envelope) is carried in
      # the Proposal `tree` (the "graph out" of a read is its value). Envelope parity with the epic_show
      # handler is proven in spec. Never-raise (Fmcb#call rescues).
      class EpicShow < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          id = (input[:id] || input["id"]).to_s.strip
          return propose(ok: false, reason: :id_required, because: "`id` must be a non-empty string") if id.empty?

          epic = (surface.respond_to?(:epic) ? surface.epic(id) : nil)
          return propose(ok: false, reason: :not_found, because: "No curated EPIC for #{id.inspect}") if epic.nil?

          top = (surface.respond_to?(:top_priority) ? surface.top_priority.to_i : 0)
          Proposal.new(tree: {
            ok: true,
            epic: {
              name:           epic.name,
              title:          epic.title,
              status:         epic.status,
              display_status: epic.display_status,
              priority:       epic.priority.to_i,
              top:            epic.priority.to_i >= top && top.positive?,
              summary:        epic.summary,
              plans:          (epic.plans || []).map { |p| { identifier: p.identifier, title: p.title, status: p.status } },
              arcs:           (epic.arcs  || []).map { |a| { id: a.id, status: a.status, branch: a.branch, merge_commit_sha: a.merge_commit_sha } }
            }
          }, triples: [])
        end

        # The projected ENVELOPE = the read result. "Prove parity THROUGH the envelope" (epic_65 Stage 2):
        # this is the value an action handler delegating to the Fmcb would return.
        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end

        private

        # A read failure carries its never-raise envelope in the tree; no triples.
        def propose(ok:, reason:, because:)
          Proposal.new(tree: { ok: ok, reason: reason, because: because }, triples: [])
        end
      end
    end
  end
end
