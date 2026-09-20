# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "digest"
require "time"
require_relative "layer"
require_relative "provenance"
require_relative "result"
require_relative "shape_set"
require_relative "graph_projection"
require_relative "graph_sink"

module Mmg
  module Medallion
    # Bronze → Silver conformer (semantic medallion P1).
    # Accepts a bronze triple set / proposal, runs the mmg_shacl_v1 gate,
    # emits a silver change-set. Default dry_run — no store write.
    #
    # M4: a land (dry_run: false) requires a Provenance stamp. Dry plans may
    # omit it so existing callers stay green. Derived text wearing an
    # observed stamp is bronze_mutated here, not only in the memory gem.
    #
    # M5: silver change-sets carry a temporal envelope. tx_from is
    # engine-stamped from the module clock (the journal-position analog);
    # a caller that passes tx_from / tx_to is refused tx_time_client_set.
    # valid_from is caller world-time and rides along unstamped.
    #
    # M1: an armed run WRITES the named silver graph -- into the
    # in-process projection always, plus the configured SPARQL sink
    # (graph_sink:; :auto reads MM_OXIGRAPH_URL). CAS still binds the
    # change-set, now including the write receipt.
    module Conformer
      module_function

      @tx_clock = 0

      def next_tx
        @tx_clock += 1
      end

      def tx_clock = @tx_clock

      def run(flow:, bronze_triples: [], quality: 1.0, dry_run: true, revision: nil,
              provenance: nil, valid_from: nil, tx_from: nil, tx_to: nil,
              graph_sink: :auto)
        f = flow.is_a?(Flow) ? flow : Flow.find(flow)
        return { ok: false, reason: :unknown_flow, because: "flow #{flow.inspect} not registered" } unless f

        unless tx_from.nil? && tx_to.nil?
          return Result.failure(
            :tx_time_client_set,
            "tx_from/tx_to are engine-stamped from the journal position, never caller arguments; " \
            "a caller-set tx lets two writers disagree about what was believed when"
          )
        end

        stamp = gate_provenance(provenance, dry_run: dry_run)
        return stamp if stamp.is_a?(Hash) && stamp[:ok] == false

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
        silver["provenance"] = stamp.to_h if stamp
        silver["temporal"] = { "valid_from" => valid_from, "tx_from" => next_tx, "tx_to" => nil }
        silver["shacl_report"] = gate

        sinks = []
        unless dry_run
          stored = store_named_graph(graph_iri: plan[:to], lines: triples, graph_sink: graph_sink)
          return stored unless stored[:ok]

          sinks = stored[:sinks]
          silver["write"] = stored[:receipt]
        end
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
          because: dry_run ? "dry_run — pass dry_run:false to arm SPARQL write to silver graph" : "armed write to silver graph (#{sinks.join(' + ')})"
        }
      rescue ::StandardError => e
        { ok: false, reason: :conform_failed, because: "#{e.class}: #{e.message}" }
      end

      # M4 probe: land requires a stamp. The binding asks this rather than
      # parsing method parameters, so "landed" is measured not declared.
      def provenance_required_on_land? = true

      # M5 probe: silver change-sets carry engine-stamped tx. Same posture
      # as the M4 probe above.
      def temporal_stamps_tx? = true

      def gate_provenance(provenance, dry_run:)
        if provenance.nil?
          return nil if dry_run

          return Result.failure(
            :audit_rejected,
            "Bronze provenance is required to land (dry_run: false); an episode that cannot " \
            "say where it came from cannot be replayed"
          )
        end

        env = Provenance.coerce(provenance)
        unless env
          return Result.failure(:audit_rejected,
                                "Bronze provenance could not be read; expected the M4 envelope fields")
        end
        env.refusal || env
      end
      private_class_method :gate_provenance

      # M1: projection always, SPARQL sink when resolved. The gate
      # parsed every line first, so projection ingest cannot fail here;
      # a failing sink fails the run (a configured sink never skips).
      # Public so Curator writes its gold graph through the same path.
      def store_named_graph(graph_iri:, lines:, graph_sink:)
        ingested = GraphProjection.new.ingest(graph_iri: graph_iri, lines: lines)
        return ingested unless ingested[:ok]

        sinks = ["projection"]
        resolved = GraphSink.resolve(graph_sink)
        return resolved unless resolved[:ok]

        unless resolved[:sink].nil?
          written = GraphSink.write(sink: resolved[:sink], graph_iri: graph_iri, lines: lines)
          return written unless written[:ok]

          sinks << "oxigraph" unless written[:skipped]
        end
        Result.success(
          sinks: sinks,
          receipt: { graph: graph_iri, triples: ingested[:triples_written], sinks: sinks }
        )
      end

      # M2: mmg_shacl_v1. The flow's shape_set must resolve in the
      # registry; validation is structural plus declared constraints, and
      # the report persists on the result (and links onto the promotion).
      def shacl_gate(triples, shape_set: nil)
        set = ShapeSet.for(shape_set.to_s)
        unless set
          return {
            ok: false, shape_set: shape_set,
            because: "unknown shape_set #{shape_set.inspect}: register it with ShapeSet.register; " \
                     "an undeclared gate is how untyped triples enter Silver"
          }
        end

        report = set.validate(triples)
        unless report[:ok]
          report = report.merge(
            because: "#{report[:violations].size} SHACL violation(s): " \
                     "#{report[:violations].first(3).join('; ')}"
          )
        end
        report
      end
    end
  end
end
