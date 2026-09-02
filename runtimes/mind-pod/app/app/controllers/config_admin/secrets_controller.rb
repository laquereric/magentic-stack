# frozen_string_literal: true

# ROLE=config credential-entry UI. Lists presence and writes secrets.
# Never reads a value back (ADR 0046 read-back asymmetry). Never logs a
# secret value. A vault 403 is designed behaviour, not an error path:
# surface reason and because (gap 104).
module ConfigAdmin
class SecretsController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)
  layout "config"

  def index
    listed = client.list
    @items = listed.dig("result", "items") || []
    @refusal = listed unless listed["ok"]
  end

  def create
    name = params[:name].to_s
    value = params[:value].to_s
    result = client.put(name, value)
    if result["ok"]
      redirect_to root_path
    else
      @items = []
      @refusal = result
      render :index, status: :unprocessable_entity
    end
  end

  private

  def client
    @client ||= VaultClient.new(
      base_url: ENV.fetch("VAULT_URL"),
      token: ENV.fetch("VAULT_TOKEN"),
    )
  end
end
end
