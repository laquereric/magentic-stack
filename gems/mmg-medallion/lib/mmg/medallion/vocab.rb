# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "digest"

module Mmg
  module Medallion
    # Canonical medallion vocabulary IRIs (design §2).
    module Vocab
      BASE           = "https://magentic.market"
      MM             = "#{BASE}/ns/mm#"
      MEDALLION_ROOT = "#{BASE}/id/medallion"
      TIER_GRAPH     = "#{BASE}/graph/mmg-medallion/tiers"

      RDF_TYPE     = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
      RDFS_LABEL   = "http://www.w3.org/2000/01/rdf-schema#label"
      SLUG         = "#{MM}slug"
      RANK         = "#{MM}rank"
      DESCRIPTION  = "#{MM}description"
      OCCURRED_AT  = "#{MM}occurredAt"

      MEDALLION_TIER   = "#{MM}MedallionTier"
      MEDALLION_FLOW   = "#{MM}MedallionFlow"
      PROMOTION        = "#{MM}Promotion"
      PROMOTED_FROM    = "#{MM}promotedFrom"
      PROMOTED_TO      = "#{MM}promotedTo"
      PROMOTES_TO_TIER = "#{MM}promotesToTier"
      SUBJECT          = "#{MM}subject"
      FLOW             = "#{MM}flow"
      FLOW_TEMPLATE    = "#{MM}flowTemplate"
      MEDALLION_TIER_P = "#{MM}medallionTier"
      HAS_STAMP        = "#{MM}hasStamp"
      STAMP_KEY        = "#{MM}stampKey"
      STAMP_VALUE      = "#{MM}stampValue"


      # --- DataLayer.md fold-in: purpose-based layering + Gold governed-product vocabulary ---
      PURPOSE          = "#{MM}purpose"
      ACTIONABLE       = "#{MM}Actionable"
      SEMANTIC_MODEL   = "#{MM}SemanticModel"
      CONTRACT         = "#{MM}Contract"
      AUDIT_RECORD     = "#{MM}AuditRecord"
      CONFORMS_TO      = "#{MM}conformsTo"
      FRESHNESS_SLA    = "#{MM}freshnessSla"

      module_function

      def tier(slug)
        "#{MEDALLION_ROOT}/#{slug}"
      end

      def tier_for_rank(rank)
        { 1 => tier("bronze"), 2 => tier("silver"), 3 => tier("gold") }[rank.to_i]
      end

      def flow(subject_iri)
        "#{BASE}/id/medallion-flow/#{Digest::SHA256.hexdigest(subject_iri.to_s)}"
      end

      def promotion(event_id)
        "#{BASE}/id/medallion-promotion/#{event_id}"
      end

      def stamp(event_id, ordinal)
        "#{BASE}/id/medallion-stamp/#{event_id}/#{ordinal}"
      end

      def template(key)
        "#{BASE}/id/medallion-template/#{key}"
      end
    end
  end
end
