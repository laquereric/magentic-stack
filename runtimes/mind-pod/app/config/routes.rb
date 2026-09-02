# frozen_string_literal: true

# ROLE gates the route table (ADR 0047 amendment 2). FRONT must not serve
# /_cpcp; VAULT must not serve /_cpcp or the browser pages; CONFIG must not
# serve /_cpcp (it is the operator UI, vault's first caller). BACK is the
# only role that mounts the CPCP write seam. BACKJOB writes Reconciliation
# locally and does not mount this engine (ADR 0056).
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
    get "/secrets", to: "vault#index"
    post "/secrets", to: "vault#create"
    get "/secrets/:name", to: "vault#show"
  when "config"
    # Operator UI. Vault caller: put+list, never get (gap 50).
    # Catalogue (row 15) is display-only. Discovery and verify stay on switch.
    root "config_admin/secrets#index"
    post "/secrets", to: "config_admin/secrets#create"
    get "/catalog", to: "config_admin/catalog#index"
  end
end
