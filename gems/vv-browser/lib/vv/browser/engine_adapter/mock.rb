# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "../engine_adapter"

module Vv
  module Browser
    class EngineAdapter
      class Mock < EngineAdapter
        def name = :mock

        def available?
          true
        end

        def bootstrap(headless: true, profile: nil, **opts)
          url = opts[:ws_url] || "ws://mock.local/session"
          Outcome.ok(
            endpoint: endpoint_descriptor(
              ws_url: url,
              bootstrap: :fresh,
              session_id: "mock-session",
              metadata: { headless: headless, mock: true }
            )
          )
        end
      end
    end
  end
end
