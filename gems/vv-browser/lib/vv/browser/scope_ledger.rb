# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"

module Vv
  module Browser
    # ACIA-ish intention → resource provenance map.
    class ScopeLedger
      def initialize(intention: nil)
        @intention = intention || "intent_#{SecureRandom.hex(4)}"
        @entries = []
      end

      attr_reader :intention, :entries

      def record(kind:, resource:, meta: {})
        row = {
          intention: @intention,
          kind: kind.to_s,
          resource: resource,
          meta: meta,
          at: Time.now.utc.iso8601
        }
        @entries << row
        row
      end

      def for_intention
        @entries.select { |e| e[:intention] == @intention }
      end
    end
  end
end
