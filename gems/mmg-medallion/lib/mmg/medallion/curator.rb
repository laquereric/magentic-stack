# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "digest"
require "time"
require_relative "layer"

module Mmg
  module Medallion
    # Silver → Gold curator (P3 lite). Only accepts silver change-sets with CAS pointer.
    # Links optional curation_id (Mmg::Curation). Default dry_run.
    module Curator
      module_function

      def promote(flow:, silver:, curation_id: nil, dry_run: true)
        f = flow.is_a?(Flow) ? flow : Flow.find(flow)
        return { ok: false, reason: :unknown_flow } unless f

        s = silver.is_a?(Hash) ? silver.transform_keys(&:to_s) : {}
        return { ok: false, reason: :silver_missing } if s.empty?
        return { ok: false, reason: :not_silver, because: "tier=#{s['tier']}" } unless s["tier"].to_s == "silver"

        gold_graph = Layer.graph_iri(flow: f.name, tier: "gold", revision: s["revision"] || f.version)
        gold = {
          "tier" => "gold",
          "flow" => f.name,
          "source_silver_cas" => s["cas_digest"] || s["cas"],
          "target_graph" => gold_graph,
          "n_triples" => s["n_triples"] || Array(s["triples"]).size,
          "curation_id" => curation_id,
          "promoted_at" => Time.now.utc.iso8601,
          "retention_hint" => Layer.retention_hint("gold")
        }
        digest = Digest::SHA256.hexdigest(gold.to_s)

        {
          ok: true,
          dry_run: dry_run,
          gold: gold,
          cas_digest: "sha256:#{digest}",
          because: dry_run ? "dry_run — Gold not written; curation link optional" : "armed write not wired (0.2.0)"
        }
      rescue ::StandardError => e
        { ok: false, reason: :promote_failed, because: "#{e.class}: #{e.message}" }
      end
    end
  end
end
