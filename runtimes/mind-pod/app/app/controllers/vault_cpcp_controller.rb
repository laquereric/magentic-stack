# frozen_string_literal: true

# Vault CPCP surface (gap 50 / row 4). ROLE=vault only. POST /_cpcp/rpc.
# Do NOT mount RailsCpcp::Engine here: stock RpcController always renders
# HTTP 200, which is the named hazard for vault refusals (row 49 KEEP BOTH).
# Envelope is the vault contract: {ok, reason, because, result}, plus jsonrpc/id.
# Bearer is the Authorization header, never a JSON-RPC param.
class VaultCpcpController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)

  METHODS = {
    "vault.secret.put" => :put,
    "vault.secret.list" => :list,
    "vault.secret.get" => :get,
  }.freeze

  def rpc
    parsed = parse_rpc
    unless parsed[:error].nil?
      return reply(id: parsed[:id], status: 400,
                   json: fail_json(parsed[:error], parsed[:because]))
    end
    op = METHODS[parsed[:method]]
    unless op
      return reply(id: parsed[:id], status: 400,
                   json: fail_json("unknown_operation", { "method" => parsed[:method] }))
    end
    if api.nil?
      err = @api_error
      return reply(id: parsed[:id], status: err[:status], json: err[:json])
    end
    result = perform_vault(op, parsed[:params])
    reply(id: parsed[:id], status: result[:status], json: result[:json])
  end

  private

  def perform_vault(op, params)
    token = bearer
    case op
    when :put then api.put(token, params["name"], params["value"])
    when :list then api.list(token)
    when :get then api.get(token, params["name"])
    end
  end

  def api
    @api ||= Vault::Api.new(allowlist: allowlist, store: store)
  rescue Vault::Allowlist::Unparseable, Vault::Store::Error => e
    @api_error = { status: 500, json: fail_json(e.reason, e.because) }
    nil
  end

  def allowlist
    Vault::Allowlist.parse!(ENV["VAULT_CALLERS"])
  end

  def store
    Vault::Store.new(path: ENV["VAULT_STORE_PATH"], master_key: ENV["VAULT_MASTER_KEY"])
  end

  def bearer
    h = request.headers["Authorization"].to_s
    h.start_with?("Bearer ") ? h.delete_prefix("Bearer ").strip : ""
  end

  def parse_rpc
    raw = request.body.read
    if raw.to_s.strip.empty?
      return { id: nil, error: "empty_body", because: { "offender" => "body" } }
    end
    parsed = JSON.parse(raw)
    unless parsed.is_a?(Hash)
      return { id: nil, error: "unparseable_json", because: { "offender" => "body" } }
    end
    params = parsed["params"]
    params = {} if params.nil?
    unless params.is_a?(Hash)
      return { id: parsed["id"], error: "unparseable_json", because: { "offender" => "params" } }
    end
    { id: parsed["id"], method: parsed["method"].to_s, params: params, error: nil }
  rescue JSON::ParserError
    { id: nil, error: "unparseable_json", because: { "offender" => "body" } }
  end

  def fail_json(reason, because)
    { "ok" => false, "reason" => reason.to_s, "because" => because }
  end

  def reply(id:, status:, json:)
    json = json.merge("jsonrpc" => "2.0", "id" => id)
    response.set_header("WWW-Authenticate", "Bearer") if status.to_i == 401
    render json: json, status: status
  end
end
