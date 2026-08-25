# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv; end

module Vv::Graph
  # Storable-facing projection seam (ADR StorableBootSafe).
  #
  # Storable depends ONLY on `Vv::Graph.publisher.schedule(ref:, generation:)` —
  # never on store readiness or Oxigraph lifecycle. Server = Publisher::Immediate
  # (S1); plugin = Publisher::BootAware (S3).
  #
  # S1 was drain-now via emit. S2 adds durable ProjectionJob outbox +
  # atomic-replace / tombstone. S3/S4 add boot gating (BootAware).
  module Publisher
    # @param ref [Vv::Graph::Ref]
    # @param generation [Integer] monotonic projection generation for the row
    # @param action [Symbol] :project | :retract
    # @param record [Object,nil] optional in-memory row for retract context
    # @return [Symbol] implementation-defined status (:applied, :missing, …)
    def schedule(ref:, generation:, action: :project, record: nil)
      raise NotImplementedError, "#{self.class}#schedule"
    end

    def drain_pending!
      raise NotImplementedError, "#{self.class}#drain_pending!"
    end
  end
end

require_relative "publisher/immediate"
