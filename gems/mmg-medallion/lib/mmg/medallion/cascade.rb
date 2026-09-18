# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "time"
require_relative "result"
require_relative "decay"

module Mmg
  module Medallion
    # Deletion / invalidation walk, Silver then Gold (M9).
    #
    # This is the ENGINE half: given a set of IRIs it records the tombstone
    # and reports what each tier must do. The MEMORY-gem Derivation index is
    # what COMPUTES the iri set from a fact_id; this module never scans for
    # consumers itself. SPARQL deletes arrive when the M1 sink is live; until
    # then the receipt is the contract (in-process graph, journalled by the
    # caller -- a tombstone that never journals is not landed).
    #
    # Three kinds, three Gold outcomes. Supersession and correction sharing
    # one path would make them indistinguishable downstream -- that shared
    # path is refused by the derivation independence spec.
    module Cascade
      KINDS = {
        supersession: { silver: "closed", gold: "stale" },
        correction: { silver: "closed", gold: "invalidated" },
        forget: { silver: "tombstoned", gold: "tombstoned" }
      }.freeze

      @tombstones = {}

      class << self
        # M8: a forget executes on the Bronze legal-retention clock, so it
        # carries retention evidence. Supersession/correction evidence is
        # the successor row by construction -- nothing extra to pass.
        def call(iris:, kind:, evidence: nil)
          k = kind.to_sym
          outcome = KINDS[k]
          unless outcome
            return Result.failure(
              :audit_rejected,
              "cascade kind must be #{KINDS.keys.join('|')}, got #{kind.inspect}"
            )
          end

          if k == :forget
            gate = Decay.evidence_refusal(tier: "bronze", evidence: evidence)
            return gate if gate
          end

          list = Array(iris).map(&:to_s).reject(&:empty?).uniq
          if list.empty?
            return Result.failure(:audit_rejected, "cascade needs at least one iri; a tombstone with no subject deletes nothing")
          end

          at = Time.now.utc.iso8601
          receipts = list.map do |iri|
            receipt = { iri: iri, kind: k.to_s, silver: outcome[:silver], gold: outcome[:gold], at: at }
            @tombstones[iri] = receipt
            receipt
          end
          Result.success(kind: k.to_s, iris: list, receipts: receipts,
                         silver: outcome[:silver], gold: outcome[:gold])
        end

        def tombstoned?(iri) = @tombstones.key?(iri.to_s)

        def receipt_for(iri) = @tombstones[iri.to_s]

        def clear!
          @tombstones.clear
          { ok: true }
        end
      end
    end
  end
end
