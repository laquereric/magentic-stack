# frozen_string_literal: true
require "rails/engine"
module RailsCpcp
  class Engine < ::Rails::Engine
    isolate_namespace RailsCpcp

    initializer "rails_cpcp.refusal_observer" do
      config.after_initialize { RailsCpcp::RefusalLog.heartbeat! }
    end

    initializer "rails_cpcp.nats_binding" do
      config.after_initialize { RailsCpcp::NatsBinding.start! }
    end

    initializer "rails_cpcp.a2a_binding" do
      config.after_initialize { RailsCpcp::A2aBinding.start! }
    end
  end
end
