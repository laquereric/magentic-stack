# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module Fmcbs
      # DoctrineList -- the read-only action `doctrine_list` wrapped as a PURE Fmcb. Reproduces its envelope
      # { ok:true, entries:, count: } from `surface.doctrine_entries` alone (the doctrine lookup, a subset
      # of the substrate surface). PURE: no graph read, no write -- testable by mocking the surface. A READ
      # has no proposed state change (triples: []); the result rides in the tree.
      class DoctrineList < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          entries = (surface.respond_to?(:doctrine_entries) ? ::Kernel.Array(surface.doctrine_entries) : [])
          Proposal.new(tree: { ok: true, entries: entries, count: entries.size }, triples: [])
        end

        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end
      end
    end
  end
end
