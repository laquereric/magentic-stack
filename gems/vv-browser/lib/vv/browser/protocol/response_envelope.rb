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
      # Inbound BiDi command response: { id, result } or { id, error, message }
      class ResponseEnvelope
        attr_reader :id, :result, :error, :message, :type

        def initialize(id:, result: nil, error: nil, message: nil, type: nil, **_rest)
          @id = id
          @result = result
          @error = error
          @message = message
          @type = type
        end

        def ok?
          error.nil? && type.to_s != "error"
        end

        def to_h
          h = { "id" => id }
          if ok?
            h["result"] = result
          else
            h["type"] = "error"
            h["error"] = error
            h["message"] = message
          end
          h
        end

        def self.parse(raw)
          h = raw.is_a?(Hash) ? raw : (::JSON.parse(raw.to_s) rescue nil)
          return nil unless h.is_a?(Hash) && h.key?("id")
          return nil if h["method"] # events have method, not correlation alone without result/error

          # Responses have id + (result | error)
          return nil unless h.key?("result") || h.key?("error") || h["type"] == "error"

          new(
            id: h["id"],
            result: h["result"],
            error: h["error"],
            message: h["message"],
            type: h["type"]
          )
        end
      end
    end
  end
end
