# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"
require_relative "outcome"
require_relative "bidi_session"
require_relative "sal_event_bridge"
require_relative "graph_grounding"
require_relative "dom_snapshot"
require_relative "engine_adapter/mock"
require_relative "engine_adapter/firefox"
require_relative "engine_adapter/chromium"

module Vv
  module Browser
    # High-level agent affordance: drive/open/navigate/read/act/capture (design §5).
    class AgentDriver
      attr_reader :session, :context, :bridge, :intention, :engine

      def initialize(session:, context: nil, intention: nil, engine: :mock)
        @session = session
        @context = context
        @intention = intention || "drive_#{SecureRandom.hex(4)}"
        @engine = engine
        @bridge = SalEventBridge.new(intention: @intention)
        @bridge.attach_session(session)
      end

      def navigate(url)
        Outcome.capture(reason: :navigate_failed) do
          ensure_context!
          res = @session.browsing_context.navigate(@context, url)
          GraphGrounding.ground_action(kind: "navigate", context: @context, url: url, intention: @intention)
          res
        end
      end

      def read(css: "body")
        Outcome.capture(reason: :read_failed) do
          ensure_context!
          snap = DomSnapshot.new(@session, context: @context).capture(css: css)
          return snap unless snap[:ok]

          title = @session.script.evaluate(@context, "document.title")
          GraphGrounding.ground_action(kind: "read", context: @context, intention: @intention)
          Outcome.ok(
            context: @context,
            title: title[:ok] ? title[:value] : nil,
            snapshot: snap,
            logs: @session.log.texts
          )
        end
      end

      def act(kind:, **args)
        Outcome.capture(reason: :act_failed) do
          ensure_context!
          res = case kind.to_s
                when "click"
                  @session.input.click(@context, x: args[:x] || 0, y: args[:y] || 0)
                when "type"
                  @session.input.type_text(@context, args[:text].to_s)
                when "evaluate"
                  @session.script.evaluate(@context, args[:js] || args[:expression])
                else
                  Outcome.fail(reason: :unknown_act, because: "unknown act #{kind}")
                end
          GraphGrounding.ground_action(kind: "act:#{kind}", context: @context, intention: @intention)
          res
        end
      end

      def capture
        Outcome.capture(reason: :capture_failed) do
          ensure_context!
          shot = @session.browsing_context.capture_screenshot(@context)
          GraphGrounding.ground_action(kind: "capture", context: @context, intention: @intention)
          shot
        end
      end

      def close
        @session.close
        Outcome.ok(closed: true)
      end

      def ensure_context!
        return @context if @context

        created = @session.browsing_context.create
        raise "context create failed: #{created.inspect}" unless created[:ok]

        @context = created[:context]
      end
    end
  end
end
