# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "json"

module Vv
  module Browser
    module Protocol
      # Inbound BiDi event: { type: "event", method, params }
      class EventEnvelope
        attr_reader :method, :params, :type

        def initialize(method:, params: {}, type: "event")
          @method = method.to_s
          @params = params.is_a?(Hash) ? params : {}
          @type = type.to_s
        end

        def to_h
          { "type" => type, "method" => method, "params" => params }
        end

        def self.parse(raw)
          h = raw.is_a?(Hash) ? raw : (::JSON.parse(raw.to_s) rescue nil)
          return nil unless h.is_a?(Hash) && h["method"]
          return nil if h.key?("id") && (h.key?("result") || h.key?("error"))

          new(method: h["method"], params: h["params"] || {}, type: h["type"] || "event")
        end
      end
    end
  end
end
