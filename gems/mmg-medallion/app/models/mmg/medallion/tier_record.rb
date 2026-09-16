# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    # ONE Medallion AR — table medallions, exactly Bronze/Silver/Gold (design §1).
    # Loaded only when ActiveRecord is present. Pure Tier + Seed work offline.
    class TierRecord < (defined?(::ApplicationRecord) ? ::ApplicationRecord : ::ActiveRecord::Base)
      self.table_name = "medallions"

      CANONICAL_BY_SLUG = Tier::CANONICAL_BY_SLUG

      validates :slug, inclusion: { in: CANONICAL_BY_SLUG.keys }
      validates :slug, :rank, :name, uniqueness: true
      validate :canonical_tuple

      scope :in_rank_order, -> { order(:rank) }

      def iri
        Vocab.tier(slug)
      end

      def successor_iri
        Vocab.tier_for_rank(rank + 1)
      end

      def to_tier
        Tier.new(name: name, rank: rank, slug: slug, description: description)
      end

      if defined?(::Vv::Graph::Storable)
        include ::Vv::Graph::Storable

        triples do
          subject -> { iri }
          triple "rdf:type", -> { "<#{Vocab::MEDALLION_TIER}>" }
          triple Vocab::RDFS_LABEL, -> { name }
          triple Vocab::SLUG, -> { slug }
          triple Vocab::RANK, -> { rank.to_s }
          triple Vocab::DESCRIPTION, -> { description }
          triple Vocab::PROMOTES_TO_TIER, -> { successor_iri }, if: -> { successor_iri }
        end
      end

      private

      def canonical_tuple
        expected = CANONICAL_BY_SLUG[slug]
        return errors.add(:slug, "is not a canonical medallion tier") unless expected

        expected.each do |attribute, expected_value|
          actual_value = public_send(attribute)
          next if actual_value == expected_value

          errors.add(attribute, "must be #{expected_value.inspect} for #{slug}")
        end
      end
    end
  end
end
