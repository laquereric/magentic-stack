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

module Mmg
  module Medallion
    # Bronze → Silver conformer (semantic medallion P1).
    # Accepts a bronze triple set / proposal, runs a pragmatic SHACL gate,
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
    module Conformer
      module_function

      @tx_clock = 0

      def next_tx
        @tx_clock += 1
      end

      def tx_clock = @tx_clock

      def run(flow:, bronze_triples: [], quality: 1.0, dry_run: true, revision: nil,
              provenance: nil, valid_from: nil, tx_from: nil, tx_to: nil)
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
