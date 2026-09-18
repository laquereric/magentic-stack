# frozen_string_literal: true

require "active_record"

module Vv
  module PerSite
    # Apply this engine's migrations without a host Rails app. Used by the
    # standalone rake tasks SIC runs, and by the spec helper.
    module Migrator
      module_function

      MIGRATIONS = [
        ["20260917190000_create_vv_per_site_okf_nodes.rb", "CreateVvPerSiteOkfNodes", :vv_per_site_okf_nodes],
        ["20260917190100_create_vv_per_site_sites_and_ctas.rb", "CreateVvPerSiteSitesAndCtas", :vv_per_site_sites]
      ].freeze

      def path
        File.expand_path("../../../db/migrate", __dir__)
      end

      def run!
        ActiveRecord::Migration.verbose = false
        MIGRATIONS.each do |filename, const_name, table|
          next if ActiveRecord::Base.connection.data_source_exists?(table.to_s)

          require File.join(path, filename)
          Object.const_get(const_name).new.change
        end
        { ok: true }
      rescue StandardError => e
        { ok: false, reason: :migrate_failed, because: "#{e.class}: #{e.message}" }
      end
    end
  end
end
