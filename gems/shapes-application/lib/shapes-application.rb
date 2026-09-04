# frozen_string_literal: true

require "shapes-level-8"

# Application contract shape packages. Rails-free.
#
# A FAMILY, not one flat namespace. FolkCoder-pod and translation-board-pod
# land beside mind-pod without any of them being reclassified
# (review 2026-08-29a §2.2; ADR 0063 for the third).
#
# Seam (not an implementation): Shapes::Application.bundle(application:, version:)
# resolves a versioned contract bundle for one application identifier.
# Catalog values are empty until TTL moves in a later step.
module Shapes
  module Application
    VERSION = "0.0.0"
    APPLICATIONS = %w[mind-pod folkcoder-pod translation-board-pod].freeze

    def self.catalog
      APPLICATIONS.each_with_object({}) { |app, h| h[app] = {}.freeze }.freeze
    end

    def self.bundle(application:, version:)
      app = application.to_s
      unless APPLICATIONS.include?(app)
        return {
          "ok" => false,
          "error" => {
            "reason" => "unknown_application",
            "because" => "application #{app.inspect} is not a family member; known: #{APPLICATIONS.join(', ')}"
          }
        }
      end
      key = version.to_s
      app_catalog = catalog.fetch(app)
      return app_catalog[key] if app_catalog.key?(key)

      {
        "ok" => false,
        "error" => {
          "reason" => "unknown_bundle",
          "because" => "no shapes-application bundle for #{app.inspect} version #{key.inspect}; catalog is empty (step 4 skeletons)"
        }
      }
    end
  end
end
