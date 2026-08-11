# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv; end

module Vv::Graph
  module Publisher
    # Server publisher: drain-now == today's emit-on-save behavior.
    #
    # Re-reads the row by ref and invokes `semantica_emit_triples!`.
    # Generation is accepted for seam parity with BootAware/outbox (S2+)
    # but does not gate delivery in S1 (no durable jobs yet).
    class Immediate
      include Publisher

      # @param ref [Vv::Graph::Ref]
      # @param generation [Integer]
      # @return [Symbol] :applied | :missing | :no_declaration
      def schedule(ref:, generation:)
        record = ref.resolve
        return :missing if record.nil?
        return :no_declaration unless record.respond_to?(:semantica_emit_triples!)

        result = record.semantica_emit_triples!
        result == false ? :no_declaration : :applied
      end
    end
  end
end
