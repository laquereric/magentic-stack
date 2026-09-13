# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "net/http"
require "json"
require "uri"
require "socket"
require "tmpdir"
require "fileutils"
require_relative "../session_handle"

module Vv
  module Browser
    module Engines
      # Abstract engine adapter. Concrete engines own:
      #   (a) driver launch  (b) session bootstrap  (c) capability builder
      # Shared BiDi command layer lives above this.
      class Base
        NAME = :base

        def name = self.class::NAME

        def available?
          !driver_path.nil?
        end

        def driver_bin
          raise NotImplementedError
        end

        def driver_path
          Browser.which(driver_bin)
        end

        def supports?(_feature, capabilities: nil)
          true
        end

        # Launch the WebDriver server child. Returns envelope { ok:, pid:, port: } or error.
        def launch_driver(**)
          raise NotImplementedError
        end

        # Build alwaysMatch capabilities hash for this engine.
        def build_capabilities(headless: true, profile: nil, **opts)
          raise NotImplementedError
        end

        # Bootstrap a session. Returns SessionHandle envelope or error.
        # Firefox: may open BiDi WS then session.new OR HTTP webSocketUrl (current path).
        # Chrome: MUST POST /session webSocketUrl:true then attach — never session.new.
        def bootstrap(headless: true, profile: nil, **opts)
          raise NotImplementedError
        end

        # Teardown: close BiDi (caller), DELETE /session, kill process group, clean profile.
        def shutdown(handle, bidi_session: nil)
          bidi_session&.close
          delete_http_session(handle) if handle && handle.session_id && handle.port
          kill_driver(handle) if handle && handle.pid
          clean_ephemeral_profile(handle) if handle
          { ok: true }
        rescue => e
          { ok: false, reason: :shutdown_failed, because: "#{e.class}: #{e.message}" }
        end

        # --- shared HTTP helpers ------------------------------------------------

        def free_port
          s = ::TCPServer.new("127.0.0.1", 0)
          port = s.addr[1]
          s.close
          port
        end

        def wait_status_ready(port, timeout: 15)
          deadline = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) + timeout
          last = nil
          loop do
            begin
              uri = ::URI.parse("http://127.0.0.1:#{port}/status")
              res = ::Net::HTTP.get_response(uri)
              body = (::JSON.parse(res.body) rescue {})
              last = body
              ready = body.dig("value", "ready")
              return { ok: true, status: body } if ready == true || ready == "true"
            rescue ::StandardError => e
              last = e.message
            end
            break if ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) > deadline
            sleep 0.15
          end
          { ok: false, reason: :driver_not_ready,
            because: "GET /status not ready on :#{port} within #{timeout}s (last=#{last.inspect[0, 120]})" }
        end

        def post_session(port, capabilities)
          uri = ::URI.parse("http://127.0.0.1:#{port}/session")
          res = ::Net::HTTP.post(uri, ::JSON.generate(capabilities), "Content-Type" => "application/json")
          body = (::JSON.parse(res.body) rescue {})
          session_id = body.dig("value", "sessionId")
          caps = body.dig("value", "capabilities") || {}
          ws = caps["webSocketUrl"] || body.dig("value", "capabilities", "webSocketUrl")
          unless ws
            return {
              ok: false,
              reason: :bidi_endpoint_missing,
              because: "driver returned no capabilities.webSocketUrl (BiDi not negotiated): #{res.body.to_s[0, 240]}",
              http_status: res.code, body: body
            }
          end
          {
            ok: true,
            session_id: session_id,
            web_socket_url: ws,
            capabilities: caps.is_a?(::Hash) ? caps : {},
            raw: body
          }
        rescue => e
          { ok: false, reason: :webdriver_session_failed, because: "#{e.class}: #{e.message}" }
        end

        def delete_http_session(handle)
          return unless handle.session_id && handle.port
          uri = ::URI.parse("http://127.0.0.1:#{handle.port}/session/#{handle.session_id}")
          http = ::Net::HTTP.new(uri.host, uri.port)
          http.open_timeout = 3
          http.read_timeout = 5
          req = ::Net::HTTP::Delete.new(uri.path)
          http.request(req)
        rescue ::StandardError
          nil
        end

        def kill_driver(handle)
          pid = handle.pid
          return unless pid
          begin
            ::Process.kill("TERM", -pid) # process group (pgroup: true spawn)
          rescue ::Errno::ESRCH, ::Errno::EPERM
            (::Process.kill("TERM", pid) rescue nil)
          end
          deadline = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) + 2.0
          loop do
            broken = begin
              ::Process.waitpid(pid, ::Process::WNOHANG)
            rescue ::Errno::ECHILD
              true
            end
            break if broken || ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) > deadline
            sleep 0.05
          end
          (::Process.kill("KILL", -pid) rescue nil)
          (::Process.kill("KILL", pid) rescue nil)
          (::Process.waitpid(pid, ::Process::WNOHANG) rescue nil)
        rescue ::StandardError
          nil
        end

        def clean_ephemeral_profile(handle)
          return unless handle.ephemeral_profile && handle.profile_dir
          ::FileUtils.rm_rf(handle.profile_dir) if handle.profile_dir.to_s.include?("vv-browser-")
        rescue ::StandardError
          nil
        end

        def spawn_driver(args)
          # setsid so we can kill the process group (chromedriver spawns chrome children)
          pid = ::Process.spawn(*args, out: ::File::NULL, err: ::File::NULL, pgroup: true)
          { ok: true, pid: pid }
        rescue => e
          { ok: false, reason: :driver_launch_failed, because: "#{e.class}: #{e.message}" }
        end
      end
    end
  end
end
