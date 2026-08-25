# frozen_string_literal: true

require "rails/engine"

module RailsOsiLevel8
  # Additive Rails engine. Mounted in the BACK app ALONGSIDE rails-cpcp; it adds the OSI
  # Level 8 semantic layer, not a competing RPC surface. No controller / no route.
  class Engine < ::Rails::Engine
    isolate_namespace RailsOsiLevel8

    config.generators.api_only = true

    initializer "rails_osi_level_8.defaults" do
      root_shapes = root.join("data", "osi-level-8")
      RailsOsiLevel8.config.shape_root ||= root_shapes
      RailsOsiLevel8.config.shapes_path ||= root_shapes.to_s
    end

    # Append engine migrations into the host app only when ROLE=back (sole writer).
    initializer "rails_osi_level_8.append_migrations", before: :load_config_initializers do |app|
      next unless RailsOsiLevel8.config.back?

      unless app.root.to_s.start_with?(root.to_s)
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
