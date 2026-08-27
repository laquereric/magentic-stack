# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "yaml"

module Mmg
  module Acia
    # Load the Profile 9 vocabulary into acia_terms.
    #
    # db/seeds/acia_terms.yml is GENERATED from the normative shapes by
    # bin/sync-terms-from-spec. The specification owns these types; this gem
    # implements them, so the term list is derived and never authored here.
    module TermSeeds
      module_function

      PATH = ::File.expand_path("../../../db/seeds/acia_terms.yml", __dir__)

      def document(path = PATH)
        ::YAML.safe_load(::File.read(path)) || {}
      rescue ::StandardError => e
        raise ArgumentError, "cannot read #{path}: #{e.class}: #{e.message}"
      end

      def enumerations(path = PATH) = document(path)["enumerations"] || {}
      def vocabulary(path = PATH) = document(path)["vocabulary"].to_s

      # Boundary: never raises. A seed step that takes the boot down when one row
      # is malformed is a seed step nobody runs.
      def load!(path = PATH)
        return { ok: false, reason: :no_active_record, because: "ActiveRecord is not loaded" } unless defined?(::ActiveRecord::Base)

        enums = enumerations(path)
        return { ok: false, reason: :no_enumerations, because: "#{path} declares none" } if enums.empty?

        # A term can be legal in more than one enumeration, so membership is a set
        # per token, not a column per enumeration.
        membership = ::Hash.new { |h, k| h[k] = [] }
        order = {}
        enums.each do |name, tokens|
          ::Kernel.Array(tokens).each_with_index do |token, i|
            membership[token.to_s] << name.to_s
            order[token.to_s] ||= i
          end
        end

        created = 0
        membership.each do |token, names|
          row = AciaTerm.find_or_initialize_by(token: token)
          row.enumerations = "|#{names.join('|')}|"
          row.ordinal = order.fetch(token, 0)
          next unless row.changed?

          created += 1 if row.new_record?
          row.save!
        end

        { ok: true, created: created, terms: membership.size, enumerations: enums.keys,
          vocabulary: vocabulary(path) }
      rescue ::StandardError => e
        { ok: false, reason: :seed_failed, because: "#{e.class}: #{e.message}" }
      end
    end
  end
end
