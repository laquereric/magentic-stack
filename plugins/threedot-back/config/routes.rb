# frozen_string_literal: true
RailsThreedotBack::Engine.routes.draw do
  # Shell webview HTML endpoint
  get "/shell", to: "shell#index", as: :shell
end
