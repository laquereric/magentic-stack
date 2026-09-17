# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Vv
  module Figma
    # Thin HTTP wrapper over api.figma.com. Injectable so specs never
    # touch the network. Never raises.
    #
    # Personal access tokens travel as `X-Figma-Token`. OAuth access
    # tokens travel as `Authorization: Bearer`. This transport sends
    # both with the same secret so a caller does not have to know which
    # kind they hold. OAuth token exchange uses HTTP Basic instead.
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

      attr_reader :uri, :access_token, :open_timeout, :read_timeout

      def initialize(uri:, access_token: nil,
                     open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT)
        @uri = uri.to_s.sub(%r{/\z}, "")
        @access_token = access_token.to_s
        @open_timeout = open_timeout
        @read_timeout = read_timeout
      end

      def request(method, path, body: nil, query: nil, headers: {}, form: false, auth: true, basic: nil)
        return Envelope.refuse(:uri_required, "a Figma API URI is required") if @uri.empty?
        if auth && basic.nil? && @access_token.empty?
          return Envelope.refuse(:token_required, "a Figma access token is required")
        end

        klass = VERBS[method.to_s.downcase.to_sym]
        unless klass
          return Envelope.refuse(:method_unsupported, "HTTP #{method} is not a Figma verb this client speaks")
        end

        url = build_url(path, query)
        req = klass.new(url.request_uri)
        req["Accept"] = "application/json"
        req["User-Agent"] = "vv-figma/#{VERSION}"
        if basic
          req["Authorization"] = "Basic #{[basic].pack("m0")}"
        elsif auth && !@access_token.empty?
          req["Authorization"] = "Bearer #{@access_token}"
          req["X-Figma-Token"] = @access_token
        end
        headers.each { |k, v| req[k.to_s] = v.to_s }

        unless body.nil?
          if form
            req["Content-Type"] = "application/x-www-form-urlencoded"
            req.body = URI.encode_www_form(stringify(body))
          else
            req["Content-Type"] = "application/json"
            req.body = JSON.generate(body)
          end
        end

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = url.scheme == "https"
        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout

        decode(http.request(req))
      rescue JSON::ParserError => e
        Envelope.refuse(:json_error, safe_message(e))
      rescue Timeout::Error, Errno::ETIMEDOUT => e
        Envelope.refuse(:timeout, safe_message(e))
      rescue StandardError => e
        Envelope.refuse(:network_error, safe_message(e))
      end

      private

      SECRETISH = /\b(client_secret|access_token|refresh_token|code)=[^&\s"']+/i

      def safe_message(error)
        text = "#{error.class}: #{error.message}"
        text.gsub(SECRETISH) { "#{Regexp.last_match(0).split("=", 2).first}=[redacted]" }
      end

      def stringify(hash)
        hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
      end

      def build_url(path, query)
        base = "#{@uri}#{path.start_with?("/") ? path : "/#{path}"}"
        compacted = query.is_a?(Hash) ? Keys.compact(query) : query
        if compacted && !compacted.empty?
          qs = URI.encode_www_form(Keys.to_wire(compacted, query: true))
          base = "#{base}?#{qs}"
        end
        URI.parse(base)
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
          if payload.is_a?(Hash) && Envelope.error_payload?(payload)
            return Envelope.figma_error(payload, http_status: res.code.to_i)
          end

          message =
            if payload.is_a?(Hash) && !payload["message"].to_s.empty?
              payload["message"]
            elsif payload.is_a?(Hash) && !payload["err"].to_s.empty?
              payload["err"]
            else
              "HTTP #{res.code}"
            end
          return Envelope.refuse(:http_error, message, http_status: res.code.to_i)
        end

        Envelope.from_figma(payload, http_status: res.code.to_i)
      end
    end
  end
end
