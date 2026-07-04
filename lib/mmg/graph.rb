# frozen_string_literal: true
require_relative "graph/version"

# mmg-graph -- the wrapper around the RUST graph DB (Oxigraph). One SPARQL surface; federation anticipated.
module Mmg
  module Graph
    GRAMMAR  = ::File.expand_path("graph/grammar.bnf", __dir__)
    BOUNDARY = ::File.expand_path("graph/boundary.ttl", __dir__)

    module_function

    def mcb_actions
      [
        { name: "graphdb_query", domain: "graph", personas: %w[superdev developer],
          describe: "Query the Rust graph DB (Oxigraph) -- SELECT SPARQL -> rows. The wrapped interface.",
          input_schema: { type: "object", properties: { sparql: { type: "string" } }, required: %w[sparql] },
          handler: ->(i, _c) { Execute.query(i[:sparql]) } },
        { name: "graphdb_publish", domain: "graph", personas: %w[superdev developer],
          describe: "Publish triples (INSERT DATA) into a named graph in the Rust graph DB.",
          input_schema: { type: "object", properties: { triples: { type: "array", items: { type: "string" } }, graph: { type: "string" } }, required: %w[triples] },
          handler: ->(i, _c) { Execute.publish(i[:triples], graph: (i[:graph] || "urn:mmg:graph:default")) } },
        { name: "graphdb_update", domain: "graph", personas: %w[superdev developer],
          describe: "Run a raw SPARQL UPDATE against the Rust graph DB.",
          input_schema: { type: "object", properties: { sparql: { type: "string" } }, required: %w[sparql] },
          handler: ->(i, _c) { Execute.update(i[:sparql]) } },
        { name: "graphdb_federate", domain: "graph", personas: %w[superdev developer],
          describe: "ANTICIPATED (Manus federated graph DB): query ACROSS endpoints (SPARQL SERVICE / multi-store). Seam -- returns :not_implemented.",
          input_schema: { type: "object", properties: { sparql: { type: "string" }, endpoints: { type: "array", items: { type: "string" } } }, required: %w[sparql] },
          handler: ->(i, _c) { Execute.federate(i[:sparql], endpoints: i[:endpoints]) } }
      ]
    end
  end
end
