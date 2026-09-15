# frozen_string_literal: true

require "uri"

module Vv
  module Miro
    # OAuth 2.0 authorization-code flow. Token endpoints stay on v1
    # (`/v1/oauth/token`) even though board REST is v2 — Miro's docs
    # are explicit that those URLs are not deprecated.
    #
    # Never raises.
    class Oauth
      attr_reader :client_id, :client_secret, :transport

      def initialize(client_id: nil, client_secret: nil, uri: nil, transport: nil)
        @client_id = (client_id || ENV["MIRO_CLIENT_ID"]).to_s
        @client_secret = (client_secret || ENV["MIRO_CLIENT_SECRET"]).to_s
        api = (uri || ENV["MIRO_API_URL"] || Miro::DEFAULT_API_URL).to_s
        @transport = transport || Transport.new(uri: api, access_token: "")
      end

      def authorize_url(redirect_uri:, state: nil, team_id: nil)
        return Envelope.refuse(:client_id_required, "authorize_url needs a client_id") if blank?(@client_id)
        if blank?(redirect_uri)
          return Envelope.refuse(:redirect_uri_required, "authorize_url needs a redirect_uri")
        end

        params = {
          "response_type" => "code",
          "client_id" => @client_id,
          "redirect_uri" => redirect_uri.to_s
        }
        params["state"] = state.to_s unless blank?(state)
        params["team_id"] = team_id.to_s unless blank?(team_id)
        Envelope.ok(data: "#{AUTHORIZE_URL}?#{URI.encode_www_form(params)}")
      end

      def exchange(code:, redirect_uri:)
        ready?(:code, code, :code_required, "exchange needs an authorization code") or return @__refusal
        if blank?(redirect_uri)
          return Envelope.refuse(:redirect_uri_required, "exchange needs a redirect_uri")
        end

        token_call(
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri
        )
      end

      def refresh(refresh_token:)
        ready?(:refresh_token, refresh_token, :refresh_token_required, "refresh needs a refresh_token") or
          return @__refusal

        token_call(grant_type: "refresh_token", refresh_token: refresh_token)
      end

      def revoke(access_token:)
        ready?(:access_token, access_token, :token_required, "revoke needs an access token") or
          return @__refusal
        credentials_ok? or return @__refusal

        @transport.request(
          :post,
          "/v1/oauth/revoke",
          query: {
            access_token: access_token,
            client_id: @client_id,
            client_secret: @client_secret
          },
          auth: false
        )
      end

      def context(access_token:)
        ready?(:access_token, access_token, :token_required, "context needs an access token") or
          return @__refusal

        Transport.new(uri: @transport.uri, access_token: access_token).request(:get, "/v1/oauth-token")
      end

      private

      def token_call(**query)
        credentials_ok? or return @__refusal
        @transport.request(
          :post,
          "/v1/oauth/token",
          query: query.merge(client_id: @client_id, client_secret: @client_secret),
          auth: false
        )
      end

      def credentials_ok?
        if blank?(@client_id)
          @__refusal = Envelope.refuse(:client_id_required, "a Miro client_id is required")
          return false
        end
        if blank?(@client_secret)
          @__refusal = Envelope.refuse(:client_secret_required, "a Miro client_secret is required")
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
