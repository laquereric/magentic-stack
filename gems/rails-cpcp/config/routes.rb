# frozen_string_literal: true
RailsCpcp::Engine.routes.draw do
  post "rpc",      to: "rpc#rpc"
  get  "cid.json", to: "rpc#cid"
  get  "up",       to: "rpc#up"
end
