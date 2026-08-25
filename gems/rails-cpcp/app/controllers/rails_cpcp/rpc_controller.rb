# frozen_string_literal: true
module RailsCpcp
  # The /_cpcp CPCP surface: a JSON-RPC-LD RPC endpoint + the projected CID.
  # This is a machine boundary; CSRF is skipped and auth (bearer/audience) belongs
  # in the projected handlers, not here.
  class RpcController < ActionController::Base
    skip_forgery_protection if respond_to?(:skip_forgery_protection)

    # POST /_cpcp/rpc  -- a JSON-RPC-LD request envelope
    def rpc
      response_env = RailsCpcp::Dispatcher.call(parse_body, ctx: self)
      render json: response_env, status: :ok
    end

    # GET /_cpcp/cid.json  -- the CID projected from declared operations
    def cid
      render json: RailsCpcp::Cid.document(title: "#{app_name} CPCP projection"), status: :ok
    end

    # GET /_cpcp/up  -- liveness + declared operation list
    def up
      render json: { "ok" => true, "cid_digest" => RailsCpcp::Cid.digest,
                     "operations" => RailsCpcp::Registry.operations.map(&:name) }, status: :ok
    end

    private

    def parse_body
      raw = request.body.read
      raw.to_s.empty? ? {} : JSON.parse(raw)
    rescue JSON::ParserError
      {}
    end

    def app_name
      Rails.application.class.module_parent_name
    rescue StandardError
      "rails-cpcp"
    end
  end
end
