require_relative "boot"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

# Load the gems declared in Gemfile (incl. rails-cpcp -> mounts its Engine + DSL).
Bundler.require(*Rails.groups)

module MindPod
  class Application < Rails::Application
    config.load_defaults 8.0
    config.eager_load = false
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "mind-pod-not-a-secret")
    config.hosts.clear
    # ROLE = back | front | backjob | vault (default back). ROLE gates routes.rb.
    config.x.role = ENV.fetch("ROLE", "back")
    config.x.back_url = ENV.fetch("BACK_URL", "http://localhost:3000")
  end
end
