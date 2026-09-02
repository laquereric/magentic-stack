# frozen_string_literal: true

# ROLE gates the route table (ADR 0047 amendment 2). FRONT must not serve
# /_cpcp; CONFIG must not serve /_cpcp (it is the operator UI, vault's
# first caller). BACK mounts the rails-cpcp engine (domain seam). VAULT
# serves POST /_cpcp/rpc on its own controller -- stock RpcController
# always renders HTTP 200 and must not handle vault refusals (row 49).
# BACKJOB writes Reconciliation locally and does not mount this engine
# (ADR 0056).
Rails.application.routes.draw do
  get "/up", to: proc { [200, {}, ["ok"]] }

  case Rails.application.config.x.role.to_s
  when "back"
    mount RailsCpcp::Engine => "/_cpcp"
  when "front"
    root "home#index"
    post "/notes", to: "home#create"
    get "/governance", to: "governance#show"
  when "vault"
    post "/_cpcp/rpc", to: "vault_cpcp#rpc"
  when "config"
    # Operator UI. Vault caller: put+list, never get (gap 50).
    # Catalogue (row 15) is display-only. Discovery and verify stay on switch.
    root "config_admin/secrets#index"
    post "/secrets", to: "config_admin/secrets#create"
    get "/catalog", to: "config_admin/catalog#index"
  end
end
