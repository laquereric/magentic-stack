# frozen_string_literal: true
module RailsCpcp
  # The /_cpcp CPCP surface: a JSON-RPC-LD RPC endpoint + the projected CID.
  # This is a machine boundary; CSRF is skipped and auth (bearer/audience) belongs
  # in the projected handlers, not here.
  class RpcController < ActionController::Base
    skip_forgery_protection if respond_to?(:skip_forgery_protection)

    # POST /_cpcp/rpc  -- a JSON-RPC-LD request envelope
    def rpc
      parsed = RailsCpcp::RequestBody.read(request.body.read)
      unless parsed.error.nil?
        env = RailsCpcp::Envelope.fail(id: nil, reason: parsed.error, because: parsed.because)
        RailsCpcp::RefusalLog.observe_envelope(env, source: "rpc_controller")
        render json: env, status: :ok
        return
      end
      render json: RailsCpcp::Dispatcher.call(parsed.payload, ctx: self), status: :ok
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

    def app_name
      Rails.application.class.module_parent_name
    rescue StandardError
      "rails-cpcp"
    end
  end
end
