# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "vocab"
require_relative "storable_local"
require_relative "subject_ref"

module Mmg
  module Medallion
    # subject -> mm:medallionTier -> canonical tier IRI
    class Grounding
      include StorableLocal

      attr_reader :subject_ref, :tier

      def initialize(subject_ref:, tier:)
        @subject_ref = SubjectRef.coerce(subject_ref)
        @tier = tier
      end

      def iri
        subject_ref.iri
      end

      triples do
        triple subject_ref.iri, Vocab::MEDALLION_TIER_P, tier.iri
      end
    end
  end
end
