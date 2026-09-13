# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "json"
require_relative "procedures"

module Vv
  module Browser
    # Live BiDi probe. Cucumber World holds one of these across a scenario
    # so "open the board" and "apply Poster" share a session. RSpec unit
    # tests the Procedures this class calls; this class is the integration
    # driver.
    class Probe
      attr_reader :handle, :session, :context, :url, :engine_adapter, :last_eval

      def initialize(engine:, handle:, session:)
        @engine_adapter = engine
        @handle = handle
        @session = session
        @context = nil
        @url = nil
        @closed = false
        @last_eval = nil
      end

      def engine
        @handle.engine
      end

      def close
        return { ok: true, closed: true } if @closed

        @closed = true
        @engine_adapter.shutdown(@handle, bidi_session: @session)
      end

      def observe!(events = %w[log.entryAdded network.responseCompleted])
        @session.subscribe(events)
      end

      def navigate(url, wait_s: 0.4)
        @url = url.to_s
        unless @context
          created = @session.browsing_context_create
          @context = created.dig(:result, "context")
          unless @context
            return { ok: false, reason: :no_context, because: created[:because] || created.inspect }
          end
        end
        nav = @session.browsing_context_navigate(@context, @url)
        wait(wait_s)
        nav[:ok] ? { ok: true, url: @url, context: @context } : nav
      end

      def wait(seconds)
        s = seconds.to_f
        sleep s if s.positive?
        { ok: true, waited: s }
      end

      def evaluate(js)
        raw = @session.script_evaluate(@context, js)
        val = raw.dig(:result, "result", "value")
        parsed = try_json(val)
        @last_eval = parsed
        { ok: raw[:ok] != false, value: parsed.nil? ? val : parsed, raw: raw }
      end

      def click_id(id)
        evaluate(Procedures.click_id_js(id))
      end

      def click_button_text(label, within: nil)
        evaluate(Procedures.click_button_text_js(label, within: within))
      end

      def apply_template(name)
        click_button_text(name, within: "#templateGrid")
      end

      def apply(act)
        h = stringify(act)
        if h.key?("click_text") || h.key?("click_button")
          click_button_text(h["click_text"] || h["click_button"], within: h["within"])
        elsif h.key?("click_id")
          click_id(h["click_id"])
        elsif h.key?("template")
          apply_template(h["template"])
        elsif h.key?("wait")
          wait(h["wait"])
        elsif h.key?("js") || h.key?("evaluate")
          evaluate(h["js"] || h["evaluate"])
        else
          { ok: false, reason: :unknown_act, because: "unknown act #{act.inspect}" }
        end
      end

      def console
        Procedures.console_entries(@session.events)
      end

      def network
        Procedures.network_entries(@session.events)
      end

      def javascript_errors
        Procedures.javascript_errors(console)
      end

      def getter_errors
        Procedures.getter_errors(console)
      end

      def board_snapshot
        evaluate(Procedures.board_snapshot_js)
      end

      def screenshot(path = nil)
        shot = @session.capture_screenshot(@context)
        ::Vv::Browser.save_screenshot(shot, path)
      end

      def snapshot(screenshot_path: nil)
        snap = board_snapshot
        body = try_json(snap[:value]) || snap[:value]
        body = stringify(body) if body.is_a?(Hash)
        path = screenshot_path ? screenshot(screenshot_path) : nil
        title = if body.is_a?(Hash)
          body["title"] || body[:title]
        end
        title ||= evaluate("document.title")[:value]
        {
          ok: true,
          url: @url.to_s,
          title: title,
          screenshot_path: path,
          console: console.map { |e| e[:text] }.compact,
          console_entries: console,
          network: network,
          javascript_errors: javascript_errors,
          getter_errors: getter_errors,
          snapshot: body,
          browser: engine,
          engine: engine,
          session_new_sent: @session.session_new_sent?,
          bootstrap: @handle.bootstrap
        }
      end

      private

      def stringify(obj)
        return {} unless obj.is_a?(Hash)

        obj.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
      end

      def try_json(val)
        return val unless val.is_a?(String)
        return val unless val.start_with?("{", "[")

        ::JSON.parse(val)
      rescue JSON::ParserError
        val
      end
    end
  end
end
