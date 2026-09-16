# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "tier"
require_relative "result"

module Mmg
  module Medallion
    # Idempotent seed of exactly Bronze / Silver / Gold (design §1).
    module Seed
      module_function

      def call
        Result.capture(reason: :medallion_seed_failed) do
          if Tier.ar_ready? && defined?(::Mmg::Medallion::TierRecord)
            seed_ar!
          else
            seed_memory!
          end
        end
      end

      def seed_memory!
        Tier::CANONICAL_ROWS.each do |row|
          Tier.memory[row[:slug]] = Tier.new(**row)
        end
        rows = Tier.in_rank_order
        Result.success(
          seeded: rows.map(&:slug),
          count: rows.length,
          medallions: rows.map(&:to_h),
          mode: "memory"
        )
      end

      def seed_ar!
        Tier::CANONICAL_ROWS.each do |row|
          rec = TierRecord.find_or_initialize_by(slug: row[:slug])
          rec.name = row[:name]
          rec.rank = row[:rank]
          rec.description = row[:description]
          rec.save!
          Tier.memory[row[:slug]] = Tier.from_row(rec.attributes)
        end
        rows = Tier.in_rank_order
        Result.success(
          seeded: rows.map(&:slug),
          count: rows.length,
          medallions: rows.map(&:to_h),
          mode: "ar"
        )
      end
      private_class_method :seed_memory!, :seed_ar!
    end
  end
end
