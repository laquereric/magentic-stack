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
      # Firefox adapter — geckodriver with --websocket-port + moz:firefoxOptions.
      # Session bootstrap: classic HTTP POST /session with webSocketUrl:true, then
      # attach the returned BiDi WS. (session.new is NOT used on this path; geckodriver
      # already minted the session via HTTP. Pure BiDi-only session.new remains available
      # via Bidi::Session#session_new for alternate boots.)
      class Firefox < Base
        NAME = :firefox

        def driver_bin = "geckodriver"

        def launch_driver(**)
          path = driver_path
          return { ok: false, reason: :no_driver, because: "geckodriver not in PATH" } unless path

          http_port = free_port
          ws_port = free_port
          args = [path, "--port", http_port.to_s, "--websocket-port", ws_port.to_s]
          spawned = spawn_driver(args)
          return spawned unless spawned[:ok]

          ready = wait_status_ready(http_port, timeout: 12)
          unless ready[:ok]
            (::Process.kill("TERM", spawned[:pid]) rescue nil)
            return ready
          end
          { ok: true, pid: spawned[:pid], port: http_port, websocket_port: ws_port, driver_path: path }
        end

        def build_capabilities(headless: true, profile: nil, **_opts)
          args = []
          args << "-headless" if headless
          if profile.to_s != ""
            (::FileUtils.mkdir_p(profile) rescue nil)
            args += ["-profile", profile.to_s]
          end
          {
            "capabilities" => {
              "alwaysMatch" => {
                "browserName" => "firefox",
                "webSocketUrl" => true,
                "moz:firefoxOptions" => { "args" => args }
              }
            }
          }
        end

        def bootstrap(headless: true, profile: nil, **opts)
          boot = launch_driver(**opts)
          return boot unless boot[:ok]

          caps = build_capabilities(headless: headless, profile: profile, **opts)
          sess = post_session(boot[:port], caps)
          unless sess[:ok]
            kill_driver(SessionHandle.new(pid: boot[:pid]))
            return sess
          end

          handle = SessionHandle.new(
            engine: :firefox,
            bidi_url: sess[:web_socket_url],
            webdriver_url: "http://127.0.0.1:#{boot[:port]}",
            session_id: sess[:session_id],
            capabilities: sess[:capabilities],
            profile_dir: profile,
            ephemeral_profile: false,
            pid: boot[:pid],
            port: boot[:port],
            driver_path: boot[:driver_path],
            session_new_sent: false, # HTTP-minted session; attach only
            bootstrap: :http_webSocketUrl
          )
          { ok: true, handle: handle }
        rescue => e
          { ok: false, reason: :firefox_bootstrap_failed, because: "#{e.class}: #{e.message}" }
        end
      end
    end
  end
end
