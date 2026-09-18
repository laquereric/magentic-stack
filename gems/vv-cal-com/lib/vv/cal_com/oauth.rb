# frozen_string_literal: true

require "uri"

module Vv
  module CalCom
    # OAuth 2.0 authorization-code flow (RFC 6749). Token endpoint is
    # `POST /v2/auth/oauth2/token` on api.cal.com. Authorize lives on
    # the app host (`app.cal.com/v2/auth/oauth2/authorize`).
    #
    # Token bodies stay snake_case (`client_id`, `grant_type`) — that is
    # the RFC contract, not Cal.com's camelCase REST.
    #
    # Never raises.
    class Oauth
      attr_reader :client_id, :client_secret, :app_url, :transport

      def initialize(client_id: nil, client_secret: nil, uri: nil, app_url: nil, transport: nil)
        @client_id = (client_id || ENV["CAL_CLIENT_ID"] || ENV["CAL_OAUTH_CLIENT_ID"]).to_s
        @client_secret = (client_secret || ENV["CAL_CLIENT_SECRET"] || ENV["CAL_OAUTH_CLIENT_SECRET"]).to_s
        api = (uri || ENV["CAL_API_URL"] || CalCom::DEFAULT_API_URL).to_s
        @app_url = (app_url || ENV["CAL_APP_URL"] || CalCom::DEFAULT_APP_URL).to_s.sub(%r{/\z}, "")
        @transport = transport || Transport.new(uri: api, token: "")
      end

      def authorize_url(redirect_uri:, state: nil, scope: nil, code_challenge: nil,
                        code_challenge_method: nil)
        return Envelope.refuse(:client_id_required, "authorize_url needs a client_id") if blank?(@client_id)
        if blank?(redirect_uri)
          return Envelope.refuse(:redirect_uri_required, "authorize_url needs a redirect_uri")
        end

        scopes = Array(scope || CalCom::DEFAULT_SCOPES).flatten.compact
        params = {
          "response_type" => "code",
          "client_id" => @client_id,
          "redirect_uri" => redirect_uri.to_s,
          "scope" => scopes.join(" ")
        }
        params["state"] = state.to_s unless blank?(state)
        params["code_challenge"] = code_challenge.to_s unless blank?(code_challenge)
        params["code_challenge_method"] = (code_challenge_method || "S256").to_s unless blank?(code_challenge)
        Envelope.ok(data: "#{@app_url}#{CalCom::AUTHORIZE_PATH}?#{URI.encode_www_form(params)}")
      end

      def exchange(code:, redirect_uri:, code_verifier: nil)
        ready?(:code, code, :code_required, "exchange needs an authorization code") or return @__refusal
        if blank?(redirect_uri)
          return Envelope.refuse(:redirect_uri_required, "exchange needs a redirect_uri")
        end
        credentials_ok?(public_ok: !blank?(code_verifier)) or return @__refusal

        body = {
          client_id: @client_id,
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri
        }
        body[:client_secret] = @client_secret unless blank?(@client_secret)
        body[:code_verifier] = code_verifier unless blank?(code_verifier)
        token_call(body)
      end

      def refresh(refresh_token:)
        ready?(:refresh_token, refresh_token, :refresh_token_required, "refresh needs a refresh_token") or
          return @__refusal
        credentials_ok?(public_ok: true) or return @__refusal

        body = {
          client_id: @client_id,
          grant_type: "refresh_token",
          refresh_token: refresh_token
        }
        body[:client_secret] = @client_secret unless blank?(@client_secret)
        token_call(body)
      end

      private

      def token_call(body)
        @transport.request(
          :post,
          CalCom::TOKEN_PATH,
          body: Keys.compact(body).transform_keys(&:to_s),
          auth: false
        )
      end

      def credentials_ok?(public_ok: false)
        if blank?(@client_id)
          @__refusal = Envelope.refuse(:client_id_required, "a Cal.com OAuth client_id is required")
          return false
        end
        if blank?(@client_secret) && !public_ok
          @__refusal = Envelope.refuse(:client_secret_required, "a Cal.com OAuth client_secret is required")
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
