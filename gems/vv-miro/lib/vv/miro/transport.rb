# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Vv
  module Miro
    # Thin HTTP wrapper over Miro REST v2 (and the v1 OAuth endpoints).
    # Injectable so specs never touch the network. Never raises.
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

      def request(method, path, body: nil, query: nil, headers: {}, form: false, auth: true)
        return Envelope.refuse(:uri_required, "a Miro API URI is required") if @uri.empty?
        if auth && @access_token.empty?
          return Envelope.refuse(:token_required, "a Miro access token is required")
        end

        klass = VERBS[method.to_s.downcase.to_sym]
        unless klass
          return Envelope.refuse(:method_unsupported, "HTTP #{method} is not a Miro verb this client speaks")
        end

        url = build_url(path, query)
        req = klass.new(url.request_uri)
        req["Accept"] = "application/json"
        req["User-Agent"] = "vv-miro/#{VERSION}"
        req["Authorization"] = "Bearer #{@access_token}" if auth && !@access_token.empty?
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

      # `because` is returned to callers and logged. Oauth#token_call and
      # #revoke put client_secret and access_token in the QUERY STRING, so any
      # exception whose message quotes the URL -- URI::InvalidURIError does,
      # verbatim -- would carry a live credential out of this gem. Redact the
      # query before the message is ever handed on.
      #
      # This closes the leak, not the cause. The credentials should not be in
      # the URL at all; see README "Known issue: OAuth credentials travel in
      # the query string".
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
            return Envelope.miro_error(payload, http_status: res.code.to_i)
          end

          message =
            if payload.is_a?(Hash) && !payload["message"].to_s.empty?
              payload["message"]
            else
              "HTTP #{res.code}"
            end
          return Envelope.refuse(:http_error, message, http_status: res.code.to_i)
        end

        Envelope.from_miro(payload, http_status: res.code.to_i)
      end
    end
  end
end
