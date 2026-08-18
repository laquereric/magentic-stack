Rails.application.routes.draw do
  get  "/up",       to: proc { [200, {}, ["ok"]] }
  get  "/manifest", to: "rpc#manifest"
  post "/rpc",      to: "rpc#call"
end
