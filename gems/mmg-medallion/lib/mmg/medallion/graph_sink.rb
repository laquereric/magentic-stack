# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"

module Mmg
  module Medallion
    # Where armed writes go (M1).
    #
    # resolve(requested) answers the sink question once for both actuators:
    #   nil/false  -> projection only (the offline default; tests use this
    #                 or inject a fake)
    #   :auto      -> projection always; plus Mmg::Graph::Execute when
    #                 MM_OXIGRAPH_URL is set. A SET endpoint that cannot be
    #                 reached fails closed (graph_sink_unavailable /
    #                 graph_write_failed) -- a configured sink must never
    #                 silently skip.
    #   object    -> projection plus requested.update(sparql) (tests inject
    #                 a fake; the fake's failures fail the write).
    #
    # The Execute seam lives in mmg-graph (whose gemspec exposes
    # app/services); the require stays lazy so this gem's own bundle --
    # which has no mmg-graph dependency -- never pays for the seam until
    # an armed write actually needs it.
    module GraphSink
      module_function

      def resolve(requested)
        return { ok: true, sink: nil } if requested.nil? || requested == false
        return { ok: true, sink: requested } unless requested == :auto

        if ::ENV["MM_OXIGRAPH_URL"].to_s.empty?
          return { ok: true, sink: nil }
        end

        begin
          require "mmg/graph/execute"
        rescue ::LoadError => e
          return {
            ok: false, reason: :graph_sink_unavailable,
            because: "MM_OXIGRAPH_URL is set but mmg/graph/execute did not load (#{e.message}); " \
                     "a configured sink must not silently skip"
          }
        end
        { ok: true, sink: Mmg::Graph::Execute }
      end

      def insert_data(graph_iri:, lines:)
        "INSERT DATA { GRAPH <#{graph_iri}> {\n#{Array(lines).join("\n")}\n} }"
      end

      # Posts the triple set to the sink's named graph. Empty sets skip
      # the POST (there is no empty INSERT DATA); the write is still ok.
      def write(sink:, graph_iri:, lines:)
        lines = Array(lines)
        if lines.empty?
          return { ok: true, skipped: true, graph: graph_iri }
        end

        res = sink.update(insert_data(graph_iri: graph_iri, lines: lines))
        unless res.is_a?(::Hash) && res[:ok]
          return {
            ok: false, reason: :graph_write_failed,
            because: "SPARQL update to #{graph_iri} failed: #{res.inspect[0, 200]}",
            graph: graph_iri
          }
        end
        { ok: true, graph: graph_iri, triples: lines.size }
      rescue ::StandardError => e
        { ok: false, reason: :graph_write_failed,
          because: "#{e.class}: #{e.message}", graph: graph_iri }
      end
    end
  end
end
