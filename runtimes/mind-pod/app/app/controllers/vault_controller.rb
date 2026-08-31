# frozen_string_literal: true

# Vault HTTP surface. ROLE=vault only -- routes.rb must not draw these on
# any other role (ADR 0047 amendment 2). Never logs a secret value.
class VaultController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)

  def index
    reply api.list(bearer)
  end

  def create
    body = parse_body
    reply api.put(bearer, body["name"], body["value"])
  end

  def show
    reply api.get(bearer, params[:name])
  end

  private

  def api
    @api ||= Vault::Api.new(allowlist: allowlist, store: store)
  rescue Vault::Allowlist::Unparseable, Vault::Store::Error => e
    @api_error = { status: 500, json: { "ok" => false, "reason" => e.reason, "because" => e.because } }
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

  def parse_body
    raw = request.body.read
    raw.to_s.empty? ? {} : JSON.parse(raw)
  rescue JSON::ParserError
    {}
  end

  def reply(result)
    result = @api_error if result.nil?
    render json: result[:json], status: result[:status]
  end
end
