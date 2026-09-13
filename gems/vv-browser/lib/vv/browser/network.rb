# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"
require_relative "outcome"

module Vv
  module Browser
    class Network
      def initialize(session)
        @session = session
        @intercepts = {}
      end

      def subscribe(events = %w[network.beforeRequestSent network.responseCompleted])
        @session.subscribe(events)
      end

      def add_intercept(phases: ["beforeRequestSent"], url_patterns: nil)
        params = { "phases" => Array(phases) }
        params["urlPatterns"] = Array(url_patterns) if url_patterns
        res = @session.send_command("network.addIntercept", params)
        return res unless res[:ok]

        iid = res.dig(:result, "intercept") || "ix_#{SecureRandom.hex(4)}"
        @intercepts[iid] = { phases: phases, url_patterns: url_patterns }
        Outcome.ok(intercept: iid, result: res[:result])
      end

      def remove_intercept(intercept)
        @intercepts.delete(intercept)
        @session.send_command("network.removeIntercept", { "intercept" => intercept })
      end

      def continue_request(request)
        @session.send_command("network.continueRequest", { "request" => request })
      end

      def fail_request(request)
        @session.send_command("network.failRequest", { "request" => request })
      end

      def intercepts
        @intercepts.dup
      end
    end
  end
end
