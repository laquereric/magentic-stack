# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "digest"
require "time"
require_relative "layer"
require_relative "result"
require_relative "graph_projection"
require_relative "graph_sink"

module Mmg
  module Medallion
    # Silver → Gold curator (P3 lite). Only accepts silver change-sets with CAS pointer.
    # Links optional curation_id (Mmg::Curation). Default dry_run.
    #
    # M6: an armed promote (dry_run: false) requires a published
    # SemanticModel + Contract. Optional stays optional on dry_run: true.
    # PURPOSE_LAYERING Gold is "defined once" -- optional is not once.
    module Curator
      module_function

      # M6 probe. The binding asks this rather than parsing parameters.
      def requires_model_contract_on_arm? = true

      def promote(flow:, silver:, curation_id: nil, dry_run: true,
                  semantic_model: nil, contract: nil, graph_sink: :auto)
        f = flow.is_a?(Flow) ? flow : Flow.find(flow)
        return { ok: false, reason: :unknown_flow } unless f

        s = silver.is_a?(Hash) ? silver.transform_keys(&:to_s) : {}
        return { ok: false, reason: :silver_missing } if s.empty?
        return { ok: false, reason: :not_silver, because: "tier=#{s['tier']}" } unless s["tier"].to_s == "silver"

        unless dry_run
          gate = gate_model_contract(semantic_model: semantic_model, contract: contract)
          return gate if gate

          # M3: the doctrine judges the armed moment. Depth (governed,
          # matching, live) was the M6 gate above; presence of the gate
          # report and the content address is judged here.
          audit = Mmg::Medallion.audit!(
            "tier" => "gold",
            "semantic_model" => semantic_model, "contract" => contract,
            "shacl_report" => gold_shacl_report(s),
            "cas_digest" => (s["cas_digest"] || s["cas"])
          )
          return audit unless audit[:ok]
        end

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
        sinks = []
        unless dry_run
          gold["semantic_model_iri"] = model_iri(semantic_model)
          gold["contract_iri"] = contract_iri(contract)
          # M2: the gate report links onto the promotion.
          gold["shacl_report"] = gold_shacl_report(s)
          stored = Conformer.store_named_graph(
            graph_iri: gold_graph, lines: Array(s["triples"]).map(&:to_s), graph_sink: graph_sink
          )
          return stored unless stored[:ok]

          sinks = stored[:sinks]
          gold["write"] = stored[:receipt]
        end
        digest = Digest::SHA256.hexdigest(gold.to_s)

        {
          ok: true,
          dry_run: dry_run,
          gold: gold,
          cas_digest: "sha256:#{digest}",
          because: dry_run ? "dry_run — Gold not written; curation link optional" : "armed write to gold graph (#{sinks.join(' + ')})"
        }
      rescue ::StandardError => e
        { ok: false, reason: :promote_failed, because: "#{e.class}: #{e.message}" }
      end

      # nil when the armed promote may proceed; a refusal otherwise.
      # A model counts as published when it is governed; a contract counts
      # when it names that model and carries a freshness SLA.
      def gate_model_contract(semantic_model:, contract:)
        model = coerce_model(semantic_model)
        unless model && model[:governed]
          return Result.failure(
            :model_required,
            "an armed Gold promotion requires a published (governed) SemanticModel; " \
            "Gold is defined once, and optional is not once"
          )
        end

        c = coerce_contract(contract)
        unless c && !c[:semantic_model_iri].to_s.empty? && !c[:freshness_sla].to_s.empty?
          return Result.failure(
            :contract_required,
            "an armed Gold promotion requires a Contract with a freshness SLA and breakage policy"
          )
        end

        unless c[:semantic_model_iri].to_s == model[:iri].to_s
          return Result.failure(
            :contract_required,
            "contract names #{c[:semantic_model_iri].inspect} but the model is #{model[:iri].inspect}; " \
            "a Gold product is one model under one contract"
          )
        end

        nil
      end
      private_class_method :gate_model_contract

      def coerce_model(value)
        return nil if value.nil?
        h = value.is_a?(Hash) ? value.transform_keys(&:to_s) :
          { "iri" => value.iri, "governed" => value.governed? }
        { iri: h["iri"] || h["semantic_model_iri"], governed: !!h["governed"] }
      rescue ::StandardError
        nil
      end
      private_class_method :coerce_model

      def coerce_contract(value)
        return nil if value.nil?
        h = value.is_a?(Hash) ? value.transform_keys(&:to_s) :
          { "iri" => value.iri, "semantic_model_iri" => value.semantic_model_iri,
            "freshness_sla" => value.freshness_sla }
        { iri: h["iri"], semantic_model_iri: h["semantic_model_iri"],
          freshness_sla: h["freshness_sla"] }
      rescue ::StandardError
        nil
      end
      private_class_method :coerce_contract

      def model_iri(value)
        coerce_model(value)&.dig(:iri)
      end
      private_class_method :model_iri

      def contract_iri(value)
        coerce_contract(value)&.dig(:iri)
      end
      private_class_method :contract_iri

      # The SHACL gate report rides on the silver change-set: nested under
      # "audit" (Conformer output) or flat (hand-built). Either shape
      # counts; absence fails the M3 Gold check, not this helper.
      def gold_shacl_report(silver)
        audit = silver["audit"]
        audit = audit.transform_keys(&:to_s) if audit.is_a?(Hash)
        return audit["shacl"] if audit.is_a?(Hash) && !audit["shacl"].nil?

        silver["shacl_report"] || silver["shacl"]
      end
      private_class_method :gold_shacl_report
    end
  end
end
