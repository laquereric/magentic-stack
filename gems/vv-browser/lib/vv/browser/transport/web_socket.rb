# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "json"
require "thread"
require_relative "socket"
require_relative "pending_command"
require_relative "../protocol/command_envelope"
require_relative "../protocol/response_envelope"
require_relative "../protocol/event_envelope"
require_relative "../outcome"

module Vv
  module Browser
    module Transport
      # BiDi transport: command/response correlation + event subscription.
      # Accepts any duck-typed socket with connect/write/read_available/close/open?
      class WebSocket
        attr_reader :events, :url, :socket

        def initialize(socket: nil)
          @socket = socket
          @next_id = 0
          @pending = {}
          @events = []
          @event_handlers = Hash.new { |h, k| h[k] = [] }
          @open = false
          @url = nil
          @mutex = Mutex.new
        end

        def open?
          @open && (@socket.nil? || @socket.open?)
        end

        def connect(url, headers: {})
          Outcome.capture(reason: :connect_failed) do
            @url = url.to_s
            if @socket
              res = @socket.connect(@url, headers: headers)
              return res if res.is_a?(Hash) && res.key?(:ok) && !res[:ok]
            end
            @open = true
            Outcome.ok(url: @url, connected: true)
          end
        end

        def close
          @socket&.close rescue nil
          @open = false
          @pending.clear
          Outcome.ok
        end

        # Send BiDi command; pump until correlated response or timeout.
        def send_command(method, params = {}, timeout: 5)
          Outcome.capture(reason: :command_failed) do
            return Outcome.fail(reason: :not_open, because: "transport not connected") unless open?

            id = (@next_id += 1)
            cmd = Protocol::CommandEnvelope.new(id: id, method: method, params: params)
            pending = PendingCommand.new(id: id, method: method)
            @mutex.synchronize { @pending[id] = pending }

            write_res = write(cmd.to_json)
            return write_res unless write_res[:ok]

            deadline = monotonic + timeout.to_f
            loop do
              pump
              pend = @mutex.synchronize { @pending[id] }
              if pend&.done?
                @mutex.synchronize { @pending.delete(id) }
                resp = pend.response
                unless resp.ok?
                  return Outcome.fail(
                    reason: :bidi_error,
                    because: { message: "#{resp.error}: #{resp.message}", error: resp.error }
                  )
                end
                return Outcome.ok(id: id, result: resp.result, method: method)
              end
              if monotonic > deadline
                @mutex.synchronize { @pending.delete(id) }
                return Outcome.fail(reason: :timeout, because: "no reply to #{method} in #{timeout}s")
              end
              sleep 0.001
            end
          end
        end

        def write(text)
          Outcome.capture(reason: :write_failed) do
            return Outcome.fail(reason: :not_open, because: "not connected") unless open?

            if @socket
              @socket.write(text.to_s)
            end
            Outcome.ok(bytes: text.to_s.bytesize)
          end
        end

        def on_event(method = nil, &blk)
          key = method ? method.to_s : "*"
          @event_handlers[key] << blk if blk
          true
        end

        def subscribe_local(methods)
          Array(methods).each { |m| @event_handlers[m.to_s] ||= [] }
          Outcome.ok(methods: Array(methods).map(&:to_s))
        end

        # Ingest one JSON frame (used by mock peer + real socket pumps).
        def ingest(raw)
          h = raw.is_a?(Hash) ? raw : (::JSON.parse(raw.to_s) rescue nil)
          return false unless h.is_a?(Hash)

          if (resp = Protocol::ResponseEnvelope.parse(h))
            @mutex.synchronize do
              pend = @pending[resp.id]
              pend&.fulfill(resp)
            end
            return :response
          end

          if (ev = Protocol::EventEnvelope.parse(h))
            @events << ev
            (@event_handlers[ev.method] + @event_handlers["*"]).each { |blk| blk.call(ev) rescue nil }
            return :event
          end
          :ignored
        end

        def pump
          return unless @socket && @socket.respond_to?(:read_available)

          frames = Array(@socket.read_available)
          frames.each { |f| ingest(f) }
        end

        def monotonic
          ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
