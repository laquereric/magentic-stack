# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "json"

module SpecSupport
  # Scripted BiDi peer: answers commands by method and can emit events.
  class ScriptedBidiPeer
    def initialize(socket)
      @socket = socket
      @socket.peer = self
      @scripts = Hash.new { |h, k| h[k] = [] }
      @default = nil
      @event_queue = []
    end

    def on(method, &blk)
      @scripts[method.to_s] << blk
      self
    end

    def default(&blk)
      @default = blk
      self
    end

    def emit_event(method, params = {})
      @event_queue << { "type" => "event", "method" => method.to_s, "params" => params }
      self
    end

    def on_client_write(text)
      h = ::JSON.parse(text) rescue nil
      return unless h.is_a?(Hash) && h["id"] && h["method"]

      method = h["method"].to_s
      id = h["id"]
      params = h["params"] || {}

      # Drain any queued events first (interleaving)
      while (ev = @event_queue.shift)
        @socket.push(ev)
      end

      handlers = @scripts[method]
      result =
        if handlers.any?
          handlers.first.call(params, id)
        elsif @default
          @default.call(method, params, id)
        else
          default_result(method, params)
        end

      if result.is_a?(Hash) && (result["error"] || result[:error])
        @socket.push({
          "id" => id,
          "type" => "error",
          "error" => result["error"] || result[:error],
          "message" => result["message"] || result[:message] || "error"
        })
      else
        @socket.push({ "id" => id, "result" => result.is_a?(Hash) ? result : { "value" => result } })
      end
    end

    def default_result(method, params)
      case method
      when "session.subscribe"
        {}
      when "browsingContext.create"
        { "context" => "ctx_mock_1" }
      when "browsingContext.navigate"
        { "navigation" => "nav_1", "url" => params["url"] }
      when "browsingContext.captureScreenshot"
        { "data" => "iVBORw0KGgo=" }
      when "browsingContext.locateNodes"
        { "nodes" => [{ "sharedId" => "el_1", "type" => "element" }] }
      when "script.evaluate"
        expr = params["expression"].to_s
        val = expr.include?("title") ? "Mock Title" : 42
        { "result" => { "type" => "string", "value" => val } }
      when "input.performActions", "input.releaseActions"
        {}
      when "network.addIntercept"
        { "intercept" => "ix_1" }
      when "network.removeIntercept", "network.continueRequest", "network.failRequest"
        {}
      when "script.callFunction", "script.disown"
        { "result" => { "type" => "undefined" } }
      else
        {}
      end
    end
  end
end
