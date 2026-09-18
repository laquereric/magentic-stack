# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Vv
  module CalCom
    # Thin HTTP wrapper over Cal.com API v2. Injectable so specs never
    # touch the network. Never raises: transport failures become envelopes.
    class Transport
      DEFAULT_OPEN_TIMEOUT = 5
      DEFAULT_READ_TIMEOUT = 30

      VERBS = {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        put: Net::HTTP::Put,
        patch: Net::HTTP::Patch,
        delete: Net::HTTP::Delete
      }.freeze

      attr_reader :uri, :token, :api_version, :client_id, :secret_key,
                  :open_timeout, :read_timeout

      def initialize(uri:, token: nil, api_version: nil, client_id: nil, secret_key: nil,
                     open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT)
        @uri = uri.to_s.sub(%r{/\z}, "")
        @token = token.to_s
        @api_version = api_version.to_s.empty? ? nil : api_version.to_s
        @client_id = client_id.to_s.empty? ? nil : client_id.to_s
        @secret_key = secret_key.to_s.empty? ? nil : secret_key.to_s
        @open_timeout = open_timeout
        @read_timeout = read_timeout
      end

      def request(method, path, body: nil, query: nil, headers: {}, auth: true, api_version: nil, form: false)
        return Envelope.refuse(:uri_required, "a Cal.com API URI is required") if @uri.empty?

        if auth == true && @token.empty?
          return Envelope.refuse(:token_required, "a Cal.com API key (cal_…) or access token is required")
        end

        klass = VERBS[method.to_s.downcase.to_sym]
        unless klass
          return Envelope.refuse(:method_unsupported, "HTTP #{method} is not a Cal.com verb this client speaks")
        end

        url = build_url(path, query)
        req = klass.new(url.request_uri)
        req["Accept"] = "application/json"
        req["Content-Type"] = "application/json"
        req["User-Agent"] = "vv-cal-com/#{VERSION}"
        req["Authorization"] = "Bearer #{@token}" if send_auth?(auth)
        version = api_version || @api_version
        req["cal-api-version"] = version if version
        req["x-cal-client-id"] = @client_id if @client_id
        req["x-cal-secret-key"] = @secret_key if @secret_key
        headers.each { |k, v| req[k.to_s] = v.to_s }

        unless body.nil?
          if form
            req["Content-Type"] = "application/x-www-form-urlencoded"
            req.body = URI.encode_www_form(stringify(body))
          else
            req.body = JSON.generate(body)
          end
        end

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = url.scheme == "https"
        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout

        decode(http.request(req))
      rescue JSON::ParserError => e
        Envelope.refuse(:json_error, "#{e.class}: #{e.message}")
      rescue Timeout::Error, Errno::ETIMEDOUT => e
        Envelope.refuse(:timeout, "#{e.class}: #{e.message}")
      rescue StandardError => e
        Envelope.refuse(:network_error, "#{e.class}: #{e.message}")
      end

      private

      def send_auth?(auth)
        return false if auth == false
        return false if @token.empty?

        true
      end

      def stringify(hash)
        hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
      end

      def build_url(path, query)
        base = "#{@uri}#{path.start_with?("/") ? path : "/#{path}"}"
        compacted = query.is_a?(Hash) ? flatten_query(Keys.compact(query)) : query
        if compacted && !compacted.empty?
          qs = URI.encode_www_form(compacted)
          base = "#{base}?#{qs}"
        end
        URI.parse(base)
      end

      # Cal.com list filters that take several ids are comma-separated
      # (`eventTypeIds=100,200`), not repeated keys.
      def flatten_query(hash)
        hash.each_with_object({}) do |(k, v), out|
          out[k] = v.is_a?(Array) ? v.join(",") : v
        end
      end

      def decode(res)
        raw = res.body.to_s
        payload =
          if raw.empty?
            {}
          else
            JSON.parse(raw)
          end

        unless res.is_a?(Net::HTTPSuccess)
          if payload.is_a?(Hash) && payload["status"].to_s == "error"
            return Envelope.cal_error(payload, http_status: res.code.to_i)
          end
          if payload.is_a?(Hash) && Envelope.oauth_error?(payload)
            return Envelope.oauth_error(payload, http_status: res.code.to_i)
          end

          message =
            if payload.is_a?(Hash) && !payload["message"].to_s.empty?
              payload["message"]
            else
              "HTTP #{res.code}"
            end
          return Envelope.refuse(:http_error, message, http_status: res.code.to_i)
        end

        Envelope.from_cal(payload, http_status: res.code.to_i)
      end
    end
  end
end
