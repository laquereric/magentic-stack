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
    # Bronze → Silver conformer (semantic medallion P1).
    # Accepts a bronze triple set / proposal, runs a pragmatic SHACL gate,
    # emits a silver change-set. Default dry_run — no store write.
    module Conformer
      module_function

      def run(flow:, bronze_triples: [], quality: 1.0, dry_run: true, revision: nil)
        f = flow.is_a?(Flow) ? flow : Flow.find(flow)
        return { ok: false, reason: :unknown_flow, because: "flow #{flow.inspect} not registered" } unless f

        plan = f.plan_projection(revision: revision)
        return plan unless plan[:ok]

        triples = Array(bronze_triples).map(&:to_s)
        gate = shacl_gate(triples, shape_set: f.shape_set)
        unless gate[:ok]
          return {
            ok: false,
            reason: :shacl_failed,
            because: gate[:because],
            gate: gate,
            flow: f.name
          }
        end

        q = quality.to_f
        if q < 0.5
          return {
            ok: false,
            reason: :quality_below_threshold,
            because: "quality #{q} < 0.5",
            quality: q
          }
        end

        silver = {
          "tier" => "silver",
          "flow" => f.name,
          "target_graph" => plan[:to],
          "n_triples" => triples.size,
          "triples" => triples,
          "shape_set" => f.shape_set,
          "quality" => q,
          "revision" => (revision || f.version).to_s,
          "produced_at" => Time.now.utc.iso8601
        }
        cas_pointer = Digest::SHA256.hexdigest(silver.to_s)

        {
          ok: true,
          dry_run: dry_run,
          silver: silver,
          cas_digest: "sha256:#{cas_pointer}",
          audit: plan[:audit].merge(
            "shacl" => gate,
            "cas_digest" => "sha256:#{cas_pointer}",
            "retention_hint" => Layer.retention_hint("silver")
          ),
          because: dry_run ? "dry_run — pass dry_run:false to arm SPARQL write to silver graph" : "armed write not wired to store in 0.2.0 (CAS pointer only)"
        }
      rescue ::StandardError => e
        { ok: false, reason: :conform_failed, because: "#{e.class}: #{e.message}" }
      end

      # Pragmatic SHACL: reject empty set when shape_set required; reject blank lines.
      def shacl_gate(triples, shape_set: nil)
        if shape_set.to_s.empty?
          return { ok: false, because: "shape_set required for silver gate" }
        end
        if triples.empty?
          return { ok: false, because: "bronze triple set empty" }
        end
        bad = triples.each_with_index.select { |t, _| t.strip.empty? }.map { |_, i| i }
        if bad.any?
          return { ok: false, because: "empty triple lines at indices #{bad.inspect}" }
        end
        { ok: true, shape_set: shape_set, n: triples.size, engine: "pragmatic_shacl_v0" }
      end
    end
  end
end
