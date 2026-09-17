# frozen_string_literal: true

module Vv
  module Figma
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

      # Figma REST: the resource on 2xx; `{ status, err }` or
      # `{ error: true, status, message }` on failure.
      def from_figma(payload, http_status: nil)
        extra = { http_status: http_status }

        if payload.is_a?(Hash) && error_payload?(payload)
          return figma_error(payload, http_status: http_status)
        end

        extra[:cursor] = payload["cursor"] if payload.is_a?(Hash) && payload.key?("cursor")

        if payload.is_a?(Hash) && payload.key?("document")
          return ok(data: payload, **extra)
        end

        ok(data: payload, **extra)
      end

      def figma_error(payload, http_status: nil)
        message = payload["err"].to_s
        message = payload["message"].to_s if message.empty?
        message = "Figma error" if message.empty?
        refuse(
          :figma_error,
          message,
          status: payload["status"],
          http_status: http_status || payload["status"]
        )
      end

      def error_payload?(payload)
        payload["error"] == true ||
          (payload.key?("err") && !payload["err"].to_s.empty? && !payload.key?("id") && !payload.key?("access_token"))
      end
    end
  end
end
