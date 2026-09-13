# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "base"

module Vv
  module Browser
    module Engines
      # Chrome adapter — chromedriver is a standard HTTP WebDriver server.
      # Bootstrap:
      #   1. launch chromedriver on loopback HTTP port; poll GET /status
      #   2. POST /session { alwaysMatch: { webSocketUrl: true, goog:chromeOptions: ... } }
      #   3. read sessionId + capabilities.webSocketUrl (missing → :bidi_endpoint_missing)
      #   4. attach existing BiDi client to that URL — DO NOT emit session.new
      #      (Chrome's session already exists from the HTTP POST)
      class Chrome < Base
        NAME = :chrome

        DEFAULT_ARGS_HEADLESS = %w[headless=new window-size=1440,1024 disable-gpu no-sandbox].freeze
        DEFAULT_ARGS_HEADED   = %w[window-size=1440,1024].freeze

        def driver_bin = "chromedriver"

        def launch_driver(**)
          path = driver_path
          return { ok: false, reason: :no_driver, because: "chromedriver not in PATH" } unless path

          http_port = free_port
          # ChromeDriver: pure HTTP server — NO --websocket-port (that is geckodriver-only).
          args = [
            path,
            "--port=#{http_port}",
            "--allowed-ips=127.0.0.1"
          ]
          spawned = spawn_driver(args)
          return spawned unless spawned[:ok]

          ready = wait_status_ready(http_port, timeout: 15)
          unless ready[:ok]
            (::Process.kill("TERM", spawned[:pid]) rescue nil)
            return ready
          end
          { ok: true, pid: spawned[:pid], port: http_port, driver_path: path }
        end

        def build_capabilities(headless: true, profile: nil, binary: nil, **_opts)
          binary = ::ENV["MMG_BROWSER_CHROME_BINARY"] if binary.to_s == ""
          args = (headless ? DEFAULT_ARGS_HEADLESS : DEFAULT_ARGS_HEADED).dup
          ephemeral = false
          profile_dir = profile

          if profile.to_s != ""
            (::FileUtils.mkdir_p(profile) rescue nil)
            args << "user-data-dir=#{profile}"
          elsif headless
            # ephemeral profile so parallel runs don't contend
            profile_dir = ::Dir.mktmpdir("vv-browser-chrome-")
            ephemeral = true
            args << "user-data-dir=#{profile_dir}"
          end

          chrome_opts = { "args" => args }
          chrome_opts["binary"] = binary if binary.to_s != ""

          {
            "capabilities" => {
              "alwaysMatch" => {
                "browserName" => "chrome",
                "acceptInsecureCerts" => false,
                "webSocketUrl" => true,
                "goog:chromeOptions" => chrome_opts
              }
            }
          }.tap { |c| c[:_ephemeral_profile] = ephemeral; c[:_profile_dir] = profile_dir }
        end

        def bootstrap(headless: true, profile: nil, binary: nil, **opts)
          boot = launch_driver(**opts)
          return boot unless boot[:ok]

          built = build_capabilities(headless: headless, profile: profile, binary: binary, **opts)
          ephemeral = !!built.delete(:_ephemeral_profile)
          profile_dir = built.delete(:_profile_dir) || profile
          caps = built # pure capabilities hash

          sess = post_session(boot[:port], caps)
          unless sess[:ok]
            kill_driver(SessionHandle.new(pid: boot[:pid]))
            ::FileUtils.rm_rf(profile_dir) if ephemeral && profile_dir
            return sess # may be :bidi_endpoint_missing
          end

          handle = SessionHandle.new(
            engine: :chrome,
            bidi_url: sess[:web_socket_url],
            webdriver_url: "http://127.0.0.1:#{boot[:port]}",
            session_id: sess[:session_id],
            capabilities: sess[:capabilities],
            profile_dir: profile_dir,
            ephemeral_profile: ephemeral,
            pid: boot[:pid],
            port: boot[:port],
            driver_path: boot[:driver_path],
            session_new_sent: false, # CRITICAL: never session.new for Chrome
            bootstrap: :http_webSocketUrl_attach
          )
          { ok: true, handle: handle }
        rescue => e
          { ok: false, reason: :chrome_bootstrap_failed, because: "#{e.class}: #{e.message}" }
        end
      end
    end
  end
end
