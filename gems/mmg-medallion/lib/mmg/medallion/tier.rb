# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "vocab"
require_relative "storable_local"
require_relative "result"

module Mmg
  module Medallion
    # ONE Medallion AR surface (table: medallions) — exactly Bronze/Silver/Gold.
    # Works offline via process-local rows when ActiveRecord is unavailable.
    class Tier
      include StorableLocal

      CANONICAL_ROWS = [
        { name: "Bronze", rank: 1, slug: "bronze", description: "Raw / ingested data." }.freeze,
        { name: "Silver", rank: 2, slug: "silver", description: "Cleaned / conformed data." }.freeze,
        { name: "Gold",   rank: 3, slug: "gold",   description: "Curated / business-ready data." }.freeze
      ].freeze

      CANONICAL_BY_SLUG = CANONICAL_ROWS.each_with_object({}) { |r, h| h[r[:slug]] = r }.freeze

      attr_reader :name, :rank, :slug, :description

      def initialize(name:, rank:, slug:, description:)
        @name = name.to_s
        @rank = rank.to_i
        @slug = slug.to_s
        @description = description.to_s
      end

      def iri
        Vocab.tier(slug)
      end

      def successor_iri
        Vocab.tier_for_rank(rank + 1)
      end

      def successor
        self.class.for_rank(rank + 1)
      end

      def to_h
        { name: name, rank: rank, slug: slug, description: description, iri: iri }
      end

      triples do
        triple iri, Vocab::RDF_TYPE, Vocab::MEDALLION_TIER
        triple iri, Vocab::RDFS_LABEL, name
        triple iri, Vocab::SLUG, slug
        triple iri, Vocab::RANK, rank
        triple iri, Vocab::DESCRIPTION, description
        triple iri, Vocab::PROMOTES_TO_TIER, successor_iri if successor_iri
      end

      class << self
        def memory
          @memory ||= {}
        end

        def clear_memory!
          @memory = {}
          { ok: true }
        end

        def for(slug)
          s = slug.to_s.downcase
          return nil unless CANONICAL_BY_SLUG.key?(s)

          if ar_ready?
            row = ar_find(s)
            return from_row(row) if row
          end
          memory[s] || from_canonical(s)
        end

        def for_rank(rank)
          row = CANONICAL_ROWS.find { |r| r[:rank] == rank.to_i }
          row ? self.for(row[:slug]) : nil
        end

        def all_canonical
          CANONICAL_ROWS.map { |r| self.for(r[:slug]) }
        end

        def in_rank_order
          all_canonical.sort_by(&:rank)
        end

        def canonical?(slug)
          CANONICAL_BY_SLUG.key?(slug.to_s.downcase)
        end

        def from_canonical(slug)
          expected = CANONICAL_BY_SLUG[slug.to_s.downcase]
          return nil unless expected

          new(**expected)
        end

        def from_row(row)
          new(
            name: row[:name] || row["name"],
            rank: row[:rank] || row["rank"],
            slug: row[:slug] || row["slug"],
            description: row[:description] || row["description"]
          )
        end

        def ar_ready?
          return false unless defined?(::ActiveRecord::Base)
          return false unless ::ActiveRecord::Base.connected?

          ::ActiveRecord::Base.connection.data_source_exists?("medallions")
        rescue ::StandardError
          false
        end

        def ar_find(slug)
          return nil unless defined?(::Mmg::Medallion::TierRecord)

          rec = ::Mmg::Medallion::TierRecord.find_by(slug: slug)
          rec&.attributes&.symbolize_keys rescue rec && {
            name: rec.name, rank: rec.rank, slug: rec.slug, description: rec.description
          }
        rescue ::StandardError
          nil
        end
      end
    end
  end
end
