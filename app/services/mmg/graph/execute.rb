# frozen_string_literal: true
require "net/http"
require "uri"
require "json"

module Mmg
  module Graph
    # Execute -- the ONE wrapper over the RUST graph DB (Oxigraph) HTTP SPARQL interface. publish / query /
    # update replace the Net::HTTP block every gem's Graph class copies today. Never-raise. `federate` is the
    # ANTICIPATED seam for Manus's federated graph DB (multi-store / SPARQL SERVICE) -- intentionally NOT
    # implemented; single-endpoint ops are live.
    module Execute
      module_function

      def endpoint = ::ENV["MM_OXIGRAPH_URL"] || "http://localhost:7878"

      def publish(triples, graph: "urn:mmg:graph:default")
        body = ::Kernel.Array(triples).join("\n")
        return { ok: true, skipped: true } if body.strip.empty?
        update("INSERT DATA { GRAPH <#{graph}> {\n#{body}\n} }")
      end

      def query(sparql)
        uri = ::URI.parse("#{endpoint}/query")
        req = ::Net::HTTP::Post.new(uri)
        req["Accept"] = "application/sparql-results+json"
        req.set_form_data("query" => sparql.to_s)
        res = ::Net::HTTP.start(uri.host, uri.port, open_timeout: 3, read_timeout: 8) { |h| h.request(req) }
        return { ok: false, reason: :query_failed, because: "HTTP #{res.code}" } unless res.is_a?(::Net::HTTPSuccess)
        rows = (::JSON.parse(res.body).dig("results", "bindings") || []).map { |b| b.transform_values { |v| v["value"] } }
        { ok: true, rows: rows }
      rescue => e
        { ok: false, reason: :query_error, because: "#{e.class}: #{e.message}" }
      end

      def update(sparql)
        uri = ::URI.parse("#{endpoint}/update")
        res = ::Net::HTTP.post(uri, sparql.to_s, "Content-Type" => "application/sparql-update")
        res.is_a?(::Net::HTTPSuccess) ? { ok: true } : { ok: false, reason: :update_failed, because: "HTTP #{res.code}" }
      rescue => e
        { ok: false, reason: :update_error, because: "#{e.class}: #{e.message}" }
      end

      # ANTICIPATED (Manus federated graph DB): query ACROSS multiple graph DB endpoints -- SPARQL SERVICE
      # federation / multi-store fan-in + merge. Seam ONLY; not implemented (KISS). Shape is fixed now so
      # callers can be written against it; the body lands when Manus's federation work does.
      def federate(sparql, endpoints: [])
        { ok: false, reason: :not_implemented,
          because: "federated graph DB (Manus) anticipated -- fan `#{sparql.to_s[0, 40]}` across #{::Kernel.Array(endpoints).size} endpoint(s) + merge; single-endpoint query/publish/update are live" }
      end
    end
  end
end
