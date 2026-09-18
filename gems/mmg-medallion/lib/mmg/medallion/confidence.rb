# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"

module Mmg
  module Medallion
    # Evidence-confidence is a STAMP, never a tier rename (M10).
    #
    # A flow that needs evidence-confidence carries confidence=L1|L2|L3 on
    # the fact. A caller that passes a confidence name where a tier goes
    # gets confidence_not_a_tier, not a new rank. Mixing the two axes is
    # how a document ships that nobody can read: pipeline position
    # (Bronze/Silver/Gold) answers "how refined?", the stamp answers
    # "how sure?".
    module Confidence
      LEVELS = %w[L1 L2 L3].freeze

      # Names that arrive wearing a tier's clothes.
      TIER_LIKE = (%w[confidence] + LEVELS.map(&:downcase)).freeze

      module_function

      def valid?(value) = LEVELS.include?(normalize(value))

      def normalize(value) = value.to_s.strip.upcase

      def tier_like?(slug) = TIER_LIKE.include?(slug.to_s.strip.downcase)

      # nil when the stamp is usable; a refusal otherwise. Never-raise.
      def refusal(value)
        return nil if value.nil?
        return nil if valid?(value)

        Result.failure(
          :confidence_not_a_tier,
          "confidence must be a stamp #{LEVELS.join('|')}, got #{value.inspect}; " \
          "it is never a tier name and never a rank"
        )
      end

      def stamp(value)
        r = refusal(value)
        return r if r

        Result.success(confidence: value.nil? ? nil : normalize(value))
      end
    end
  end
end
