# frozen_string_literal: true

module Vv
  module Browser
    module Cpcp
      module_function

      def register!
        # The guard is .project, not the module. Bundler evaluates every path
        # gemspec at setup, so under the root bundle ::RailsCpcp is already
        # defined with ONLY VERSION, the seam never required -- a defined?-only
        # guard walks into NoMethodError there instead of refusing.
        unless defined?(::RailsCpcp) && ::RailsCpcp.respond_to?(:project)
          return { ok: false, reason: :cpcp_absent, because: "rails-cpcp is not loaded" }
        end

        ::RailsCpcp.project(model: "Browser") do
          operation "browser.inspect",
            direction: :pull, params: %w[url],
            summary: "Navigate, screenshot, return title + console (BiDi).",
            via: ->(p, _c) { ::Vv::Browser.inspect_url(p["url"], engine: (p["engine"] || "chrome").to_sym) }

          operation "browser.evaluate",
            direction: :pull, params: %w[url js],
            summary: "Navigate and evaluate JS.",
            via: ->(p, _c) { ::Vv::Browser.evaluate(p["url"], p["js"], engine: (p["engine"] || "chrome").to_sym) }
        end

        { ok: true, operations: %w[browser.inspect browser.evaluate] }
      end
    end
  end
end
