require_relative "boot"
require "rails"
require "action_controller/railtie"

module Osi8NooaBack
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
    config.eager_load = false
    config.secret_key_base = "poc-not-a-secret"
    config.hosts.clear
  end
end
