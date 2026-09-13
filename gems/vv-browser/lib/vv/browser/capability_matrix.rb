# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    module CapabilityMatrix
      module_function

      MATRIX = {
        firefox: {
          session_new: true,
          http_webSocketUrl: true,
          network_intercept: true,
          input_actions: true,
          privileged_chrome: false
        },
        chromium: {
          session_new: false, # Chrome HTTP attach must not send session.new
          http_webSocketUrl: true,
          network_intercept: true,
          input_actions: true,
          privileged_chrome: false
        },
        chrome: {
          session_new: false,
          http_webSocketUrl: true,
          network_intercept: true,
          input_actions: true,
          privileged_chrome: false
        },
        mock: {
          session_new: true,
          http_webSocketUrl: true,
          network_intercept: true,
          input_actions: true,
          privileged_chrome: false
        }
      }.freeze

      def supports?(engine, feature)
        eng = engine.to_sym
        feat = feature.to_sym
        row = MATRIX[eng] || MATRIX[:mock]
        !!row[feat]
      end

      def for(engine)
        MATRIX[engine.to_sym] || MATRIX[:mock]
      end
    end
  end
end
