# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "yaml"

module Mmg
  module Acia
    # Load db/seeds/acia_dimensions.yml into the five dimension tables.
    #
    # IDEMPOTENT, by token. Re-seeding is how a deploy makes sure the vocabulary
    # in the database matches the vocabulary in the file, so it must be safe to
    # run every time and must not renumber or duplicate anything.
    #
    # Reading the YAML is also how the drift checker gets its authoritative list,
    # so the parse lives here rather than in the seed script.
    module DimensionSeeds
      module_function

      PATH = ::File.expand_path("../../../db/seeds/acia_dimensions.yml", __dir__)

      MODELS = {
        "semanticRole" => "Mmg::Acia::Dimensions::SemanticRole",
        "contentRole"  => "Mmg::Acia::Dimensions::ContentRole",
        "layoutKind"   => "Mmg::Acia::Dimensions::LayoutKind",
        "layoutArity"  => "Mmg::Acia::Dimensions::LayoutArity",
        "behaviorKind" => "Mmg::Acia::Dimensions::BehaviorKind"
      }.freeze

      # { "semanticRole" => { "table" => ..., "tokens" => [...] }, ... }
      def definitions(path = PATH)
        raw = ::YAML.safe_load(::File.read(path)) || {}
        raw.reject { |k, _| k == "registry_version" }
      rescue ::StandardError => e
        raise ArgumentError, "cannot read dimension seeds at #{path}: #{e.class}: #{e.message}"
      end

      def registry_version(path = PATH)
        (::YAML.safe_load(::File.read(path)) || {})["registry_version"].to_s
      rescue ::StandardError
        ""
      end

      def tokens(path = PATH)
        definitions(path).transform_values { |d| ::Kernel.Array(d["tokens"]).map(&:to_s) }
      end

      # Boundary: returns an envelope, never raises. A seed step that takes the
      # boot down when one row is malformed is a seed step nobody runs.
      def load!(path = PATH)
        return { ok: false, reason: :no_active_record, because: "ActiveRecord is not loaded" } unless defined?(::ActiveRecord::Base)

        version = registry_version(path)
        created = 0
        updated = 0
        tokens(path).each do |key, list|
          model = ::Object.const_get(MODELS.fetch(key))
          list.each_with_index do |token, index|
            row = model.find_or_initialize_by(token: token)
            row.ordinal = index
            row.registry_version = version unless version.empty?
            next unless row.changed?

            row.new_record? ? created += 1 : updated += 1
            row.save!
          end
        end
        { ok: true, created: created, updated: updated, dimensions: tokens(path).keys, registry_version: version }
      rescue ::StandardError => e
        { ok: false, reason: :seed_failed, because: "#{e.class}: #{e.message}" }
      end
    end
  end
end
