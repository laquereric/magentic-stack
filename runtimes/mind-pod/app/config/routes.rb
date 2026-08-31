# frozen_string_literal: true

# ROLE gates the route table (ADR 0047 amendment 2). FRONT must not serve
# /_cpcp; VAULT must not serve /_cpcp or the browser pages. BACK is the only
# role that mounts the write seam.
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
  end
end
