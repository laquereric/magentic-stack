# frozen_string_literal: true

require "uri"

module Vv
  module Figma
    # OAuth 2.0 authorization-code flow. Token endpoints are
    # `POST /v1/oauth/token` and `POST /v1/oauth/refresh` with HTTP Basic
    # (`client_id:client_secret`). Codes expire in 30 seconds.
    #
    # Never raises.
    class Oauth
      attr_reader :client_id, :client_secret, :transport

      def initialize(client_id: nil, client_secret: nil, uri: nil, transport: nil)
        @client_id = (client_id || ENV["FIGMA_CLIENT_ID"]).to_s
        @client_secret = (client_secret || ENV["FIGMA_CLIENT_SECRET"]).to_s
        api = (uri || ENV["FIGMA_API_URL"] || Figma::DEFAULT_API_URL).to_s
        @transport = transport || Transport.new(uri: api, access_token: "")
      end

      def authorize_url(redirect_uri:, state: nil, scope: nil)
        return Envelope.refuse(:client_id_required, "authorize_url needs a client_id") if blank?(@client_id)
        if blank?(redirect_uri)
          return Envelope.refuse(:redirect_uri_required, "authorize_url needs a redirect_uri")
        end

        params = {
          "client_id" => @client_id,
          "redirect_uri" => redirect_uri.to_s,
          "scope" => (scope || "file_content:read,file_comments:write,current_user:read").to_s,
          "state" => state.to_s,
          "response_type" => "code"
        }
        params.delete("state") if blank?(params["state"])
        Envelope.ok(data: "#{AUTHORIZE_URL}?#{URI.encode_www_form(params)}")
      end

      def exchange(code:, redirect_uri:)
        ready?(:code, code, :code_required, "exchange needs an authorization code") or return @__refusal
        if blank?(redirect_uri)
          return Envelope.refuse(:redirect_uri_required, "exchange needs a redirect_uri")
        end

        token_call(
          TOKEN_PATH,
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri
        )
      end

      def refresh(refresh_token:)
        ready?(:refresh_token, refresh_token, :refresh_token_required, "refresh needs a refresh_token") or
          return @__refusal

        token_call(REFRESH_PATH, grant_type: "refresh_token", refresh_token: refresh_token)
      end

      private

      def token_call(path, **body)
        credentials_ok? or return @__refusal
        @transport.request(
          :post,
          path,
          body: body,
          form: true,
          auth: false,
          basic: "#{@client_id}:#{@client_secret}"
        )
      end

      def credentials_ok?
        if blank?(@client_id)
          @__refusal = Envelope.refuse(:client_id_required, "a Figma client_id is required")
          return false
        end
        if blank?(@client_secret)
          @__refusal = Envelope.refuse(:client_secret_required, "a Figma client_secret is required")
          return false
        end
        true
      end

      def ready?(name, value, reason, because)
        if blank?(value)
          @__refusal = Envelope.refuse(reason, because)
          return false
        end
        true
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end
    end
  end
end
