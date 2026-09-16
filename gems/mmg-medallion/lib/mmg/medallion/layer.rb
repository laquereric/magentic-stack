# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    # Bronze / Silver / Gold lifecycle contracts over RDF named graphs.
    # Layers are contracts (not RDF-native semantics): graph name + role + gate.
    module Layer
      module_function

      TIERS = %w[bronze silver gold].freeze

      ROLES = {
        "bronze" => {
          role: "raw_admit",
          gate: "parse_load_source_audit",
          meaning: "raw RDF triples admitted from a source; retain source + run identity"
        },
        "silver" => {
          role: "conformed",
          gate: "shacl_conformance_quality",
          meaning: "Conformer output; quality + strategy; SHACL gate"
        },
        "gold" => {
          role: "curated",
          gate: "curation_accept",
          meaning: "Curator-selected from Silver; linked to Mmg::Curation"
        }
      }.freeze

      def valid?(tier) = TIERS.include?(tier.to_s.downcase)

      def contract(tier)
        t = tier.to_s.downcase
        return { ok: false, reason: :unknown_tier, because: "tier must be bronze|silver|gold" } unless valid?(t)

        meta = ROLES[t]
        {
          ok: true,
          tier: t,
          role: meta[:role],
          gate: meta[:gate],
          meaning: meta[:meaning],
          graph_iri_template: "urn:mm:medallion/{flow}/#{t}/{revision}"
        }
      end

      def retention_hint(tier)
        case tier.to_s.downcase
        when "bronze" then "ephemeral_candidate"
        when "silver" then "review_extend"
        when "gold" then "retain_unless_governed"
        else "unknown"
        end
      end

      def graph_iri(flow:, tier:, revision: "latest")
        c = contract(tier)
        return c unless c[:ok]

        "urn:mm:medallion/#{flow}/#{c[:tier]}/#{revision}"
      end
    end
  end
end
