# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"
require_relative "redactor"
require_relative "scope_ledger"

module Vv
  module Browser
    # BiDi EventEnvelope → mmg-event SAL stream (design §4).
    class SalEventBridge
      attr_reader :emitted, :ledger

      def initialize(intention: nil, sink: nil)
        @ledger = ScopeLedger.new(intention: intention)
        @sink = sink
        @emitted = []
      end

      def bridge(event)
        Outcome.capture(reason: :sal_bridge_failed) do
          method = event.respond_to?(:method) ? event.method : event[:method] || event["method"]
          params = event.respond_to?(:params) ? event.params : (event[:params] || event["params"] || {})
          payload = Redactor.redact(
            "type" => "browser.bidi.event",
            "method" => method.to_s,
            "params" => params,
            "intention" => @ledger.intention
          )
          @ledger.record(kind: "bidi_event", resource: method.to_s, meta: { method: method })
          @emitted << payload
          @sink&.call(payload) if @sink.respond_to?(:call)
          if defined?(::Mmg::Event) && ::Mmg::Event.respond_to?(:emit)
            ::Mmg::Event.emit(payload) rescue nil
          end
          Outcome.ok(event: payload)
        end
      end

      def attach_session(session)
        session.transport.on_event { |ev| bridge(ev) }
        Outcome.ok(attached: true)
      end
    end
  end
end
