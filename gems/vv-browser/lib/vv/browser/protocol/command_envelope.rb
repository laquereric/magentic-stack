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
      # Outgoing BiDi command: { id, method, params }
      class CommandEnvelope
        attr_reader :id, :method, :params

        def initialize(id:, method:, params: {})
          @id = id
          @method = method.to_s
          @params = params.is_a?(Hash) ? params : {}
        end

        def to_h
          { "id" => id, "method" => method, "params" => params }
        end

        def to_json(*_a)
          ::JSON.generate(to_h)
        end

        def self.parse(raw)
          h = raw.is_a?(Hash) ? raw : (::JSON.parse(raw.to_s) rescue nil)
          return nil unless h.is_a?(Hash) && h.key?("method")

          new(id: h["id"], method: h["method"], params: h["params"] || {})
        end
      end
    end
  end
end
