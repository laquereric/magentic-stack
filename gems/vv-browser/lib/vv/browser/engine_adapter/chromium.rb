# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "../engine_adapter"
require_relative "../engines/chrome" if File.file?(File.expand_path("../engines/chrome.rb", __dir__))

module Vv
  module Browser
    class EngineAdapter
      class Chromium < EngineAdapter
        def name = :chromium

        def available?
          !!Browser.which("chromedriver")
        end

        def bootstrap(headless: true, profile: nil, **opts)
          Outcome.capture(reason: :chromium_bootstrap_failed) do
            if defined?(::Vv::Browser::Engines::Chrome)
              eng = ::Vv::Browser::Engines::Chrome.new
              boot = eng.bootstrap(headless: headless, profile: profile, **opts)
              return boot unless boot[:ok]

              h = boot[:handle]
              # Chrome must attach without session.new
              Outcome.ok(
                handle: h,
                endpoint: endpoint_descriptor(
                  ws_url: h.bidi_url,
                  bootstrap: :attached,
                  process_ref: h.pid,
                  session_id: h.session_id,
                  metadata: { port: h.port, engine: :chrome, session_new_forbidden: true }
                )
              )
            else
              Outcome.fail(reason: :engine_missing, because: "Engines::Chrome not loaded")
            end
          end
        end
      end

      # Alias
      Chrome = Chromium
    end
  end
end
