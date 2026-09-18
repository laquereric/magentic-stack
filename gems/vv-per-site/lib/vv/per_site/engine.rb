# frozen_string_literal: true

require "rails/engine"

module Vv
  module PerSite
    # Isolated Rails engine. Hosts run the engine migrations; table names
    # stay `vv_per_site_*`. Models live in lib/ so they do not steal the
    # host ApplicationRecord.
    class Engine < ::Rails::Engine
      isolate_namespace Vv::PerSite
      engine_name "vv_per_site"

      rake_tasks do
        load File.expand_path("../../../tasks/vv_per_site.rake", __dir__)
      end

      initializer "vv_per_site.migrations" do |app|
        config.paths["db/migrate"].expanded.each do |p|
          app.config.paths["db/migrate"] << p unless app.root.to_s.match?(root.to_s)
        end
      end

      initializer "vv_per_site.cpcp" do
        config.after_initialize { Cpcp.register! }
      end
    end
  end
end
