# frozen_string_literal: true

module Vv
  module CalCom
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

      # Cal.com REST: `{ "status": "success", "data": … }` on success
      # (optional `pagination`); `{ "status": "error", "error": { "message",
      # "code" } }` on failure. The OAuth token endpoint is a raw RFC 6749
      # object (`access_token`, `token_type`, …) with no `status` wrapper.
      def from_cal(payload, http_status: nil)
        extra = { http_status: http_status }

        if payload.is_a?(Hash) && payload["status"].to_s == "error"
          return cal_error(payload, http_status: http_status)
        end

        if payload.is_a?(Hash) && oauth_error?(payload)
          return oauth_error(payload, http_status: http_status)
        end

        extra[:pagination] = payload["pagination"] if payload.is_a?(Hash) && payload.key?("pagination")

        if payload.is_a?(Hash) && payload.key?("data") &&
           (payload["status"].to_s == "success" || payload.key?("pagination") || payload["status"].to_s.empty?)
          return ok(data: payload["data"], **extra)
        end

        ok(data: payload, **extra)
      end

      def cal_error(payload, http_status: nil)
        err = payload.is_a?(Hash) ? payload["error"] : nil
        message, code =
          case err
          when Hash
            msg = err["message"].to_s
            msg = err["error"].to_s if msg.empty?
            [msg, err["code"]]
          when String
            [err, payload.is_a?(Hash) ? payload["errorCode"] || payload["code"] : nil]
          else
            msg = payload.is_a?(Hash) ? payload["message"].to_s : ""
            [msg, payload.is_a?(Hash) ? payload["code"] : nil]
          end
        message = "Cal.com error" if message.empty?

        refuse(
          :cal_error,
          message,
          code: code,
          error: err,
          timestamp: payload.is_a?(Hash) ? payload["timestamp"] : nil,
          path: payload.is_a?(Hash) ? payload["path"] : nil,
          http_status: http_status
        )
      end

      def oauth_error(payload, http_status: nil)
        message = payload["error_description"].to_s
        message = payload["error"].to_s if message.empty?
        message = "OAuth error" if message.empty?
        refuse(
          :oauth_error,
          message,
          code: payload["error"],
          http_status: http_status
        )
      end

      def oauth_error?(payload)
        payload.key?("error") &&
          payload["error"].is_a?(String) &&
          payload["status"].to_s != "success" &&
          !payload.key?("data")
      end
    end
  end
end
