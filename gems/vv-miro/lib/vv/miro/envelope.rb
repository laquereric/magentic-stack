# frozen_string_literal: true

module Vv
  module Miro
    # Never-raise boundary. Every public method returns
    # `{ ok: true, data:, ... }` or `{ ok: false, reason:, because: }`.
    module Envelope
      module_function

      def ok(data: nil, **extra)
        { ok: true, data: data }.merge(extra.compact)
      end

      def refuse(reason, because, **extra)
        { ok: false, reason: reason.to_sym, because: because.to_s }.merge(extra.compact)
      end

      # Miro REST: the resource on 2xx; `{ type, code, message, status }`
      # on failure. HTTP 204 (delete) is success with no body.
      def from_miro(payload, http_status: nil)
        extra = { http_status: http_status }

        if payload.is_a?(Hash) && error_payload?(payload)
          return miro_error(payload, http_status: http_status)
        end

        extra[:cursor] = payload["cursor"] if payload.is_a?(Hash) && payload.key?("cursor")
        extra[:total] = payload["total"] if payload.is_a?(Hash) && payload.key?("total")
        extra[:size] = payload["size"] if payload.is_a?(Hash) && payload.key?("size")
        extra[:limit] = payload["limit"] if payload.is_a?(Hash) && payload.key?("limit")
        extra[:offset] = payload["offset"] if payload.is_a?(Hash) && payload.key?("offset")

        if payload.is_a?(Hash) && payload.key?("data")
          return ok(data: payload["data"], **extra)
        end

        ok(data: payload, **extra)
      end

      def miro_error(payload, http_status: nil)
        message = payload["message"].to_s
        message = "Miro error" if message.empty?
        refuse(
          :miro_error,
          message,
          code: payload["code"],
          type: payload["type"],
          context: payload["context"],
          http_status: http_status || payload["status"]
        )
      end

      def error_payload?(payload)
        payload["type"].to_s == "error" ||
          (payload.key?("code") && payload.key?("message") && !payload.key?("id") && !payload.key?("access_token"))
      end
    end
  end
end
