# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"
require_relative "transport/web_socket"
require_relative "browsing_context"
require_relative "script"
require_relative "input"
require_relative "network"
require_relative "log"
require_relative "navigation"
require_relative "dom_snapshot"
require_relative "element_handle"

module Vv
  module Browser
    # Pure BiDi session over Transport::WebSocket (design BiDiSession).
    # Additive to Bidi::Session (legacy websocket-driver path remains).
    class BiDiSession
      attr_reader :transport, :subscriptions, :endpoint, :contexts

      def initialize(transport: nil)
        @transport = transport || Transport::WebSocket.new
        @subscriptions = []
        @endpoint = nil
        @contexts = {}
        @closed = false
      end

      def open?
        !@closed && @transport.open?
      end

      def self.open(descriptor:, transport: nil)
        new(transport: transport).open(descriptor: descriptor)
      end

      def open(descriptor:)
        Outcome.capture(reason: :session_open_failed) do
          desc = normalize_descriptor(descriptor)
          @endpoint = desc
          url = desc[:ws_url] || desc["ws_url"]
          return Outcome.fail(reason: :ws_url_missing, because: "EndpointDescriptor needs ws_url") if url.to_s.empty?

          conn = @transport.connect(url)
          return conn unless conn[:ok]

          Outcome.ok(session: self, endpoint: desc, connected: true)
        end
      end

      def attach(descriptor:)
        open(descriptor: descriptor.merge(bootstrap: :attached))
      end

      def send_command(method, params = {}, timeout: 5)
        @transport.send_command(method, params, timeout: timeout)
      end

      def subscribe(events)
        list = Array(events).map(&:to_s)
        res = send_command("session.subscribe", { "events" => list })
        return res unless res[:ok]

        @subscriptions |= list
        @transport.subscribe_local(list)
        Outcome.ok(events: list, subscriptions: @subscriptions.dup)
      end

      def browsing_context
        @browsing_context ||= BrowsingContext.new(self)
      end

      def script
        @script ||= Script.new(self)
      end

      def input
        @input ||= Input.new(self)
      end

      def network
        @network ||= Network.new(self)
      end

      def log
        @log ||= Log.new(self)
      end

      def events
        @transport.events
      end

      def close
        @closed = true
        @transport.close
      end

      def normalize_descriptor(d)
        h = d.is_a?(Hash) ? d.transform_keys { |k| k.to_sym rescue k } : {}
        {
          engine: (h[:engine] || :mock).to_sym,
          ws_url: h[:ws_url] || h[:web_socket_url],
          bootstrap: h[:bootstrap] || :fresh,
          process_ref: h[:process_ref],
          pane_ref: h[:pane_ref],
          session_id: h[:session_id],
          metadata: h[:metadata] || {}
        }
      end
    end
  end
end
