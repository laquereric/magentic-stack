# frozen_string_literal: true

require "rails/engine"

module RailsOsiLevel8
  # Additive Rails engine. Mounted in the BACK app ALONGSIDE rails-cpcp; it adds the OSI
  # Level 8 semantic layer, not a competing RPC surface. No controller / no route.
  class Engine < ::Rails::Engine
    isolate_namespace RailsOsiLevel8

    config.generators.api_only = true

    initializer "rails_osi_level_8.defaults" do
      # ADR 0044: config.shape_root is not the resolution mechanism.
      # ProfileCatalog maps each shape to a gem + file.
      RailsOsiLevel8.config.profile_catalog ||= RailsOsiLevel8::ProfileCatalog.default
    end

    # Append engine migrations into the host app only when ROLE=back (schema owner).
    # Domain writers are BACK and BACKJOB (ADR 0056); BACKJOB does not migrate.
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
