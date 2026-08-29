# frozen_string_literal: true

# OSI Level 8 protocol-profile shape packages. Rails-free.
#
# Seam (not an implementation): Shapes::Level8.bundle(version) resolves a
# versioned protocol-profile bundle. The catalog is empty until TTL moves
# in a later step. Do not invent a resolver here.
module Shapes
  module Level8
    VERSION = "0.0.0"

    def self.catalog
      {}.freeze
    end

    def self.bundle(version)
      key = version.to_s
      return catalog[key] if catalog.key?(key)

      {
        "ok" => false,
        "error" => {
          "reason" => "unknown_bundle",
          "because" => "no shapes-level-8 bundle version #{key.inspect}; catalog is empty (step 4 skeletons)"
        }
      }
    end
  end
end
