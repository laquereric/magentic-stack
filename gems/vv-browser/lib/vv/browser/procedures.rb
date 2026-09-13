# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "json"
require "net/http"
require "uri"

module Vv
  module Browser
    # Named procedures: the RSpec leaves. Cucumber steps call these same
    # methods (mmg-user-flow paradigm: every action has an RSpec leaf;
    # Cucumber composes leaves into flows).
    #
    # No Chrome here — flattening, JS snippets, URL reachability, digest
    # shape. Probe (lib/vv/browser/probe.rb) is the live driver.
    module Procedures
      module_function

      DIGEST = /\Asha256:[0-9a-f]{64}\z/
      GETTER_ERROR = /only a getter|Setting type has no effect/i
      JS_ERROR_LEVELS = %w[error].freeze

      def event_method(event)
        return event.method.to_s if event.respond_to?(:method) && !event.is_a?(Hash)
        return event[:method].to_s if event.is_a?(Hash) && event.key?(:method)
        return event["method"].to_s if event.is_a?(Hash)

        ""
      end

      def event_params(event)
        return event.params if event.respond_to?(:params) && !event.is_a?(Hash)
        return event[:params] if event.is_a?(Hash) && event.key?(:params)
        return event["params"] if event.is_a?(Hash)

        {}
      end

      def flatten_console(params)
        p = stringify_keys(params)
        args = Array(p["args"]).map { |a| arg_text(a) }
        text = p["text"].to_s
        text = args.join(" ") if text.empty? && args.any?
        {
          level: p["level"].to_s,
          type: p["type"].to_s,
          method: p["method"].to_s,
          text: text,
          source: p["source"].to_s,
          args: args,
          stack: stack_text(p["stackTrace"])
        }
      end

      def flatten_network(params)
        p = stringify_keys(params)
        resp = stringify_keys(p["response"])
        req = stringify_keys(p["request"])
        {
          url: (resp["url"] || req["url"]).to_s,
          status: resp["status"] || resp["statusCode"],
          method: req["method"].to_s,
          type: p["type"].to_s
        }
      end

      def console_entries(events)
        Array(events).select { |e| event_method(e) == "log.entryAdded" }
                     .map { |e| flatten_console(event_params(e)) }
      end

      def network_entries(events)
        Array(events).select { |e| event_method(e) == "network.responseCompleted" }
                     .map { |e| flatten_network(event_params(e)) }
      end

      def javascript_errors(entries)
        Array(entries).select { |e|
          level = (e[:level] || e["level"]).to_s
          type = (e[:type] || e["type"]).to_s
          text = (e[:text] || e["text"]).to_s
          JS_ERROR_LEVELS.include?(level) ||
            type == "javascript" ||
            text.match?(/TypeError|ReferenceError|SyntaxError|Uncaught/i)
        }
      end

      def getter_errors(entries)
        Array(javascript_errors(entries)).select { |e|
          blob = [(e[:text] || e["text"]), (e[:stack] || e["stack"]), Array(e[:args] || e["args"]).join(" ")].join(" ")
          blob.match?(GETTER_ERROR)
        }
      end

      def digest?(value)
        value.to_s.match?(DIGEST)
      end

      def status_looks_like_digest?(text)
        digest?(text.to_s.strip.split(/\s/).first)
      end

      def http_failures(network, min_status: 400)
        Array(network).select { |n|
          st = (n[:status] || n["status"]).to_i
          st >= min_status
        }
      end

      def reachable?(url, timeout: 2)
        uri = URI.parse(url.to_s)
        return false if uri.host.to_s.empty?

        Net::HTTP.start(uri.host, uri.port, open_timeout: timeout, read_timeout: timeout) do |http|
          req = Net::HTTP::Get.new(uri.request_uri.to_s.empty? ? "/" : uri.request_uri)
          code = http.request(req).code.to_i
          code.positive? && code < 500
        end
      rescue StandardError
        false
      end

      def click_id_js(id)
        ident = JSON.generate(id.to_s)
        <<~JS
          (function () {
            var el = document.getElementById(#{ident});
            if (!el) return JSON.stringify({ ok: false, reason: "not_found", id: #{ident} });
            el.click();
            return JSON.stringify({ ok: true, clicked: #{ident} });
          })()
        JS
      end

      def click_button_text_js(label, within: nil)
        lab = JSON.generate(label.to_s)
        root = within.to_s.empty? ? "document" : "document.querySelector(#{JSON.generate(within.to_s)})"
        <<~JS
          (function () {
            var root = #{root};
            if (!root) return JSON.stringify({ ok: false, reason: "no_root" });
            var nodes = Array.prototype.slice.call(root.querySelectorAll("button, [role=button], a.template-card, .template-card"));
            var want = #{lab};
            var el = nodes.find(function (b) { return (b.textContent || "").trim() === want; });
            if (!el) {
              return JSON.stringify({
                ok: false,
                reason: "not_found",
                want: want,
                have: nodes.map(function (b) { return (b.textContent || "").trim(); })
              });
            }
            el.click();
            return JSON.stringify({ ok: true, clicked: want });
          })()
        JS
      end

      def board_snapshot_js
        <<~JS
          (function () {
            var bar = document.getElementById("saveStatus");
            var layers = document.getElementById("layerList");
            var grid = document.getElementById("templateGrid");
            var canvases = document.querySelectorAll("canvas");
            return JSON.stringify({
              title: document.title,
              status: bar ? bar.textContent : null,
              layerCount: layers ? layers.querySelectorAll("li").length : 0,
              canvasCount: canvases.length,
              fabric: typeof window.fabric,
              templateButtons: grid ? Array.prototype.map.call(grid.querySelectorAll("button"), function (b) { return (b.textContent || "").trim(); }) : []
            });
          })()
        JS
      end

      def throw_fixture_html(message = "boom")
        msg = JSON.generate(message.to_s)
        <<~HTML
          <!doctype html><html><head><title>throw-fixture</title></head>
          <body><h1>fixture</h1>
          <script>console.error(#{msg}); throw new Error(#{msg});</script>
          </body></html>
        HTML
      end

      # One-shot drive: open, optional acts, snapshot, close.
      # Return shape is a superset of inspect_url.
      def probe(url, acts: [], screenshot_path: nil, engine: :auto, headless: true, profile: nil, binary: nil, wait_s: 0.8)
        started = ::Vv::Browser.start_session(engine: engine, headless: headless, profile: profile, binary: binary)
        return started unless started[:ok]

        p = started[:probe]
        begin
          p.observe!
          nav = p.navigate(url)
          return nav.merge(probe: true) unless nav[:ok]

          p.wait(wait_s)
          Array(acts).each { |act| p.apply(act) }
          p.snapshot(screenshot_path: screenshot_path)
        ensure
          p.close
        end
      end

      def stringify_keys(obj)
        return {} unless obj.is_a?(Hash)

        obj.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
      end

      def arg_text(arg)
        return arg.to_s unless arg.is_a?(Hash)

        a = stringify_keys(arg)
        a["value"] || a["text"] || a["description"] || a.inspect
      end

      def stack_text(stack)
        return nil if stack.nil? || stack == ""
        return stack.to_s unless stack.is_a?(Hash)

        s = stringify_keys(stack)
        frames = s["callFrames"] || s["call_frames"] || []
        parts = Array(frames).map { |f|
          fh = stringify_keys(f)
          loc = [fh["url"], fh["lineNumber"], fh["columnNumber"]].compact.join(":")
          "#{fh["functionName"] || "?"} @ #{loc}"
        }
        parts.empty? ? nil : parts.join(" | ")
      end
    end
  end
end
