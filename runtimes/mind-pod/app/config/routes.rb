Rails.application.routes.draw do
  # BACK role: the /_cpcp seam (rails-cpcp) is the ONLY write path.
  mount RailsCpcp::Engine => "/_cpcp"
  get "/up", to: proc { [200, {}, ["ok"]] }

  # FRONT role: the browser-facing pages (read/act via BACK over CPCP).
  root "home#index"
  post "/notes", to: "home#create"
end
