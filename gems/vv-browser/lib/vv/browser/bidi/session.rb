# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "socket"
require "json"
require "uri"
require "websocket/driver"

module Vv
  module Browser
    module Bidi
      # Session -- a SYNCHRONOUS WebDriver BiDi client. BiDi is JSON-RPC over a
      # WebSocket: every command carries an incrementing `id`, and the matching
      # `{id, result}` reply resolves it; unsolicited `{method, params}` frames are
      # EVENTS (log.entryAdded, browsingContext.load, ...) buffered for the caller
      # (the bidirectional half). Built on websocket-driver over a raw TCPSocket --
      # no CDP, no Chrome-only dependency (Firefox-first, cross-browser is the point).
      #
      # NEVER-RAISE: every public method returns { ok: true, ... } or
      # { ok: false, reason:, because: } (substrate boundary convention).
      class Session
        # Unsolicited BiDi events collected since connect (each { method:, params: }).
        attr_reader :events

        def initialize
          @next_id = 0
          @pending = {}   # id => reply hash
          @events  = []
          @open    = false
          @closed  = false
          @session_new_sent = false
          @attach_mode = nil # :attach_webdriver | :start_bidi
        end

        def open? = @open && !@closed
        def session_new_sent? = !!@session_new_sent
        def attach_mode = @attach_mode

        # Open the BiDi WebSocket at `ws_url` (ws://host:port/session). Blocks until
        # the handshake completes or fails. Generic connect (legacy).
        def connect(ws_url, timeout: 15)
          open_ws(ws_url, timeout: timeout, mode: :connect)
        end

        # Chrome path: attach to an HTTP-created WebDriver BiDi session.
        # MUST NOT emit session.new — the session already exists.
        def attach_to_webdriver_session(ws_url, timeout: 15)
          open_ws(ws_url, timeout: timeout, mode: :attach_webdriver)
        end

        # Firefox alternate: open a bare BiDi endpoint then call session.new yourself.
        def start_bidi_session(ws_url, capabilities: {}, timeout: 15)
          opened = open_ws(ws_url, timeout: timeout, mode: :start_bidi)
          return opened unless opened[:ok]
          res = session_new(capabilities)
          opened.merge(session_new: res, session_new_sent: @session_new_sent)
        end

        # Send a BiDi command and BLOCK until its reply. Returns { ok:, result: } or
        # a never-raise error envelope. Public seam for any BiDi method.
        def send_command(method, params = {}, timeout: 30)
          return { ok: false, reason: :not_open, because: "session not connected" } unless open?

          id = (@next_id += 1)
          @driver.text(::JSON.generate(id: id, method: method, params: params))
          pump_until(timeout) { @pending.key?(id) }
          reply = @pending.delete(id)
          return { ok: false, reason: :timeout, because: "no reply to #{method} in #{timeout}s" } if reply.nil?
          return { ok: false, reason: :bidi_error, because: reply["error"].to_s + ": " + reply["message"].to_s } if reply["type"] == "error" || reply["error"]

          { ok: true, result: reply["result"] }
        rescue => e
          { ok: false, reason: :command_error, because: "#{e.class}: #{e.message}" }
        end

        # --- BiDi command builders (the protocol surface) ---
        def session_new(capabilities = {})
          @session_new_sent = true
          send_command("session.new", { capabilities: capabilities })
        end
        def subscribe(events)                          = send_command("session.subscribe", { events: ::Kernel.Array(events) })
        def browsing_context_create(type: "tab")       = send_command("browsingContext.create", { type: type })
        def browsing_context_navigate(context, url, wait: "complete")
          send_command("browsingContext.navigate", { context: context, url: url.to_s, wait: wait })
        end
        def script_evaluate(context, expression)
          send_command("script.evaluate", { expression: expression.to_s, target: { context: context }, awaitPromise: true })
        end
        def capture_screenshot(context)                = send_command("browsingContext.captureScreenshot", { context: context })

        def close
          (@driver&.close rescue nil)
          (@socket&.close rescue nil)
          @open = false
          @closed = true
          { ok: true }
        end

        private

        def open_ws(ws_url, timeout:, mode:)
          uri = ::URI.parse(ws_url.to_s)
          return { ok: false, reason: :bad_url, because: "not a ws url: #{ws_url.inspect}" } unless uri.host && uri.port

          @socket = ::TCPSocket.new(uri.host, uri.port)
          @driver = ::WebSocket::Driver.client(SocketAdapter.new(@socket, ws_url.to_s))
          @driver.on(:open)    { @open = true }
          @driver.on(:close)   { @closed = true }
          @driver.on(:message) { |e| ingest(e.data) }
          @driver.start
          pump_until(timeout) { @open || @closed }
          if @open
            @attach_mode = mode
            { ok: true, ws_url: ws_url.to_s, attach_mode: mode, session_new_sent: @session_new_sent }
          else
            { ok: false, reason: :connect_failed, because: "websocket did not open" }
          end
        rescue => e
          { ok: false, reason: :connect_error, because: "#{e.class}: #{e.message}" }
        end

        def ingest(data)
          msg = (::JSON.parse(data) rescue nil)
          return unless msg.is_a?(::Hash)
          if msg.key?("id")
            @pending[msg["id"]] = msg
          elsif msg["method"]
            @events << { method: msg["method"], params: msg["params"] }
          end
        end

        # Drive the websocket: read available bytes into the driver until the block
        # is satisfied or the timeout elapses.
        def pump_until(timeout)
          deadline = monotonic + timeout
          until yield
            return if monotonic > deadline
            ready = ::IO.select([ @socket ], nil, nil, 0.1)
            next unless ready
            begin
              @driver.parse(@socket.read_nonblock(16_384))
            rescue ::IO::WaitReadable
              next
            rescue ::EOFError, ::Errno::ECONNRESET
              @closed = true
              return
            end
          end
        end

        def monotonic = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      end

      # The thin object websocket-driver drives: it needs #url (the ws url) and
      # #write (send framed bytes to the socket). Incoming bytes are fed via
      # driver.parse in the pump loop above.
      class SocketAdapter
        attr_reader :url
        def initialize(socket, url)
          @socket = socket
          @url = url
        end

        def write(data)
          @socket.write(data)
        end
      end
    end
  end
end
