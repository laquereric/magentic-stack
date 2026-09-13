# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "engines/base"
require_relative "engines/firefox"
require_relative "engines/chrome"

module Vv
  module Browser
    # Engine registry / resolution. Explicit engine: wins; else auto-detect.
    module Engines
      module_function

      REGISTRY = {
        firefox: Firefox,
        chrome: Chrome
      }.freeze

      def for(name)
        cls = REGISTRY[name.to_sym]
        return nil unless cls
        cls.new
      end

      def all
        REGISTRY.map { |_, cls| cls.new }
      end

      # Resolve engine: :auto | :firefox | :chrome | nil
      # Returns engine instance or error envelope.
      def resolve(engine = :auto)
        want = (engine || :auto).to_sym
        if want == :auto
          # Prefer explicit availability order: firefox first (historic default), then chrome.
          all.each do |eng|
            return { ok: true, engine: eng } if eng.available?
          end
          return {
            ok: false, reason: :no_driver,
            because: "no WebDriver BiDi driver in PATH — install geckodriver and/or chromedriver " \
                     "(Firefox.app/Chrome.app alone do not speak BiDi)"
          }
        end

        eng = self.for(want)
        unless eng
          return { ok: false, reason: :unknown_engine, because: "unknown engine: #{want.inspect} (#{REGISTRY.keys.join(', ')})" }
        end
        unless eng.available?
          return {
            ok: false, reason: :no_driver,
            because: "#{eng.driver_bin} not in PATH (engine: #{want})"
          }
        end
        { ok: true, engine: eng }
      end
    end
  end
end
