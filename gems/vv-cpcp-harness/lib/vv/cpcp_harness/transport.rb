# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Vv
  module CpcpHarness
    # The wire: JSON-RPC 2.0 over `POST <endpoint>/rpc`, plus the two
    # descriptive GETs a seam serves. Injectable, so specs never touch the
    # network.
    #
    # The transport reports the *exchange* and nothing more. It does not
    # read reasons, does not decide retries, and does not treat a status
    # as an outcome — that is the client's work, and keeping it there is
    # what lets both signals be read in one place.
    class Transport
      DEFAULT_OPEN_TIMEOUT = 5
      DEFAULT_READ_TIMEOUT = 30

      # Headers worth keeping: each one is a signal the contract names.
      KEPT_HEADERS = %w[
        retry-after www-authenticate cache-control content-type
        cpcp-http-status-profile cpcp-contract-version
      ].freeze

      attr_reader :endpoint, :status_profile

      def initialize(endpoint:, credential: nil, status_profile: nil,
                     open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT)
        @endpoint = endpoint.to_s.sub(%r{/\z}, "")
        @credential = credential
        @status_profile = status_profile
        @open_timeout = open_timeout
        @read_timeout = read_timeout
      end

      # A JSON-RPC request. `params` arrives ready to send: the client has
      # already injected `@context` where the profile calls for it.
      def rpc(method:, params: {}, operation_id: nil, rpc_id: nil)
        body = { "jsonrpc" => "2.0", "id" => rpc_id || 1, "method" => method.to_s, "params" => params }
        body["operationId"] = operation_id unless operation_id.to_s.empty?
        send_request(Net::HTTP::Post, "/rpc", body: body)
      end

      # `GET /_cpcp/cid.json` — the live contract description. Not an RPC
      # method result; it stays 200.
      def cid
        send_request(Net::HTTP::Get, "/cid.json")
      end

      # `GET /_cpcp/up` — liveness. Also not an RPC method result.
      def up
        send_request(Net::HTTP::Get, "/up")
      end

      private

      # Credentials travel out of band, are read at call time, and never
      # appear in a tool input, a description, a result or the journal.
      def token
        value = @credential.respond_to?(:call) ? @credential.call : @credential
        value.to_s
      end

      def send_request(klass, path, body: nil)
        return Envelope.refuse(:seam_unreachable, "no endpoint configured for this seam") if @endpoint.empty?

        url = URI.parse("#{@endpoint}#{path}")
        req = klass.new(url.request_uri)
        req["Accept"] = "application/json"
        req["User-Agent"] = "vv-cpcp-harness/#{VERSION}"
        bearer = token
        req["Authorization"] = "Bearer #{bearer}" unless bearer.empty?
        req["CPCP-HTTP-Status-Profile"] = @status_profile.to_s unless @status_profile.to_s.empty?
        unless body.nil?
          req["Content-Type"] = "application/json"
          req.body = JSON.generate(body)
        end

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = url.scheme == "https"
        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout

        decode(http.request(req))
      rescue Timeout::Error, Errno::ETIMEDOUT, Net::OpenTimeout, Net::ReadTimeout => e
        Envelope.refuse(:seam_unreachable, "#{e.class}: #{e.message}", transport_error: :timeout)
      rescue StandardError => e
        Envelope.refuse(:seam_unreachable, "#{e.class}: #{e.message}", transport_error: :connection)
      end

      def decode(res)
        raw = res.body.to_s
        headers = KEPT_HEADERS.each_with_object({}) do |name, h|
          value = res[name]
          h[name] = value unless value.nil?
        end

        parsed = nil
        parse_error = nil
        unless raw.empty?
          begin
            parsed = JSON.parse(raw)
          rescue JSON::ParserError => e
            parse_error = "#{e.class}: #{e.message}"
          end
        end

        {
          exchanged: true,
          http_status: res.code.to_i,
          headers: headers,
          body: parsed,
          raw: raw,
          parse_error: parse_error
        }
      end
    end
  end
end
