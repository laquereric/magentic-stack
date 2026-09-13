# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "../engine_adapter"
require_relative "../engines/firefox" if File.file?(File.expand_path("../engines/firefox.rb", __dir__))

module Vv
  module Browser
    class EngineAdapter
      class Firefox < EngineAdapter
        def name = :firefox

        def available?
          !!Browser.which("geckodriver")
        end

        def bootstrap(headless: true, profile: nil, **opts)
          Outcome.capture(reason: :firefox_bootstrap_failed) do
            # Prefer existing Engines::Firefox when present
            if defined?(::Vv::Browser::Engines::Firefox)
              eng = ::Vv::Browser::Engines::Firefox.new
              boot = eng.bootstrap(headless: headless, profile: profile, **opts)
              return boot unless boot[:ok]

              h = boot[:handle]
              Outcome.ok(
                handle: h,
                endpoint: endpoint_descriptor(
                  ws_url: h.bidi_url,
                  bootstrap: :attached,
                  process_ref: h.pid,
                  session_id: h.session_id,
                  metadata: { port: h.port, engine: :firefox }
                )
              )
            else
              Outcome.fail(reason: :engine_missing, because: "Engines::Firefox not loaded")
            end
          end
        end
      end
    end
  end
end
