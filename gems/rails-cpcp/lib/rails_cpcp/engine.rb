# frozen_string_literal: true
require "rails/engine"
module RailsCpcp
  class Engine < ::Rails::Engine
    isolate_namespace RailsCpcp

    initializer "rails_cpcp.refusal_observer" do
      config.after_initialize { RailsCpcp::RefusalLog.heartbeat! }
    end
  end
end
