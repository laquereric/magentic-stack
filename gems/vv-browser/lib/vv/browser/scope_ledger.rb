# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"
# Time#iso8601 IS NOT CORE. It arrives with the `time` stdlib, and `at:` below
# calls it on every ledger record. This file required securerandom and not
# time, so the call worked only where something else had already loaded it --
# ActiveSupport in a Rails process, or a fatter bundle on a developer's
# machine. vv-browser has no Rails dependency, so in its own bundle the method
# is simply undefined and SalEventBridge#bridge returned
# {ok: false, reason: :sal_bridge_failed} with the NoMethodError swallowed by
# Outcome.capture -- a spec asserting ok == true failed with no clue why.
#
# It passed locally and failed on the runner for exactly that reason, which is
# the shape bin/ci-local exists to catch: reproduced there in 0.01s on a clean
# Linux clone after passing three times in a row on macOS.
require "time"

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
