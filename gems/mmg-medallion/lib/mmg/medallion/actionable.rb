# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1
require_relative "purpose"
module Mmg
  module Medallion
    # ACTIONABLE — what each tier *does* under the BUILD purpose: its primary action, the state change it
    # effects, and the evidence a promotion out of it must carry (DataLayer.md fold-in). This is the
    # data-plane -> projection-plane contract expressed per tier; Promotion evidence keys align with these.
    module Actionable
      REGISTRY = {
        "bronze" => { purpose: Purpose::BUILD, primary: "landing",
                      state_change: "raw_to_landed",
                      required_evidence: %w[source_profile landing_receipt raw_integrity] },
        "silver" => { purpose: Purpose::BUILD, primary: "transform",
                      state_change: "landed_to_conformed",
                      required_evidence: %w[transformation_spec decision_execution shacl_report quality_result] },
        "gold"   => { purpose: Purpose::BUILD, primary: "semantic_model",
                      state_change: "conformed_to_governed_product",
                      required_evidence: %w[semantic_model contract acceptance shacl_report freshness_result cas_outcome] }
      }.freeze

      module_function

      def for_tier(slug) = REGISTRY[slug.to_s.downcase]
      def evidence_for(slug) = (for_tier(slug) || {})[:required_evidence] || []
      def known?(slug) = REGISTRY.key?(slug.to_s.downcase)
    end
  end
end
