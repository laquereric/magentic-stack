# frozen_string_literal: true

# ROLE gates the route table (ADR 0047 amendment 2). FRONT must not serve
# /_cpcp; CONFIG must not serve /_cpcp (it is the operator UI, vault's
# first caller). BACK mounts the rails-cpcp engine (domain seam). VAULT
# serves POST /_cpcp/rpc on its own controller -- stock RpcController
# always renders HTTP 200 and must not handle vault refusals (row 49).
# SHAPE serves GET retrieval only -- do not mount the engine (POST rpc
# is not in v1; the engine's catalog is BACK's note.create). BUS serves
# POST /_cpcp/rpc on its own controller (row 18; no RES; not note.create).
# PERSIST serves POST /_cpcp/rpc on its own controller (row 8; placement
# intentions, not domain state).
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
  when "shape"
    # Retrieval only. Do not mount the engine (would draw POST rpc and
    # BACK's note.create catalog).
    get "/_cpcp/up", to: "shape#up"
    get "/_cpcp/shapes.json", to: "shape#index"
    get "/_cpcp/shapes/:digest", to: "shape#show",
        constraints: { digest: /sha256:[0-9a-f]{64}/ }
  when "bus"
    # Seam + projection. Do not mount the engine (note.create is BACK's;
    # stock RpcController is all-200).
    post "/_cpcp/rpc", to: "bus_cpcp#rpc"
  when "persist"
    # Placement authority. Do not mount the engine (note.create is BACK's;
    # stock RpcController is all-200).
    post "/_cpcp/rpc", to: "persist_cpcp#rpc"
  end
end
