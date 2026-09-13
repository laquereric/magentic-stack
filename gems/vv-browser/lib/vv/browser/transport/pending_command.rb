# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    module Transport
      # Waiter for a correlated BiDi response id.
      class PendingCommand
        attr_reader :id, :method, :created_at

        def initialize(id:, method:)
          @id = id
          @method = method
          @created_at = monotonic
          @response = nil
          @done = false
        end

        def fulfill(response)
          @response = response
          @done = true
        end

        def done?
          @done
        end

        def response
          @response
        end

        def timed_out?(timeout)
          (monotonic - @created_at) > timeout.to_f
        end

        def monotonic
          ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
