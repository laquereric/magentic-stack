# frozen_string_literal: true

require "json"
require "openssl"

module Vv
  module CalCom
    # HMAC-SHA256 verifier for inbound Cal.com webhooks.
    # Signature is a hex digest of the raw request body, compared to
    # `X-Cal-Signature-256`.
    #
    #   Vv::CalCom::Webhooks.verify(raw_body, request.headers,
    #     signing_secret: ENV["CAL_WEBHOOK_SECRET"])
    module Webhooks
      SIG_HEADERS = %w[x-cal-signature-256 x-cal-signature].freeze
      VERSION_HEADERS = %w[x-cal-webhook-version].freeze

      module_function

      def verify(payload, headers, signing_secret: nil)
        secret = (signing_secret || ENV["CAL_WEBHOOK_SECRET"] || ENV["CAL_WEBHOOK_SIGNING_SECRET"]).to_s
        if secret.empty?
          return Envelope.refuse(:signing_secret_required, "a Cal.com webhook secret is required")
        end

        signature = header_value(headers, SIG_HEADERS)
        if blank?(signature)
          return Envelope.refuse(:webhook_headers_required, "webhook needs X-Cal-Signature-256")
        end

        expected = signed_payload(secret, payload)
        unless matching_signature?(expected, signature)
          return Envelope.refuse(:webhook_invalid, "webhook signature did not verify")
        end

        parsed =
          begin
            JSON.parse(payload.to_s)
          rescue JSON::ParserError => e
            return Envelope.refuse(:json_error, "#{e.class}: #{e.message}")
          end

        trigger = parsed.is_a?(Hash) ? parsed["triggerEvent"] : nil
        Envelope.ok(
          data: parsed,
          type: trigger,
          event_id: parsed.is_a?(Hash) ? (nested_uid(parsed) || trigger) : nil,
          version: header_value(headers, VERSION_HEADERS)
        )
      end

      def signed_payload(secret, payload)
        OpenSSL::HMAC.hexdigest("SHA256", secret.to_s, payload.to_s)
      end

      def matching_signature?(expected, header)
        given = header.to_s.strip.sub(/\Asha256=/i, "")
        return false if given.empty?
        return false unless given.bytesize == expected.bytesize

        OpenSSL.fixed_length_secure_compare(given.b, expected.b)
      end

      def header_value(headers, names)
        return nil if headers.nil?

        wanted = names.map(&:downcase)
        headers.each do |k, v|
          return v if wanted.include?(k.to_s.downcase)
        end
        nil
      end

      def nested_uid(parsed)
        payload = parsed["payload"]
        return payload["uid"] if payload.is_a?(Hash) && payload["uid"]

        parsed["uid"]
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end
    end
  end
end
