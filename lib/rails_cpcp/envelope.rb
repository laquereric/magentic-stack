# frozen_string_literal: true
module RailsCpcp
  # JSON-RPC-LD never-raise envelope helpers. Requests and responses carry a
  # JSON-LD @context; collections are @graph; failures are
  # {ok:false, error:{reason, because}} -- never a raised exception across the boundary.
  module Envelope
    module_function

    def context
      {
        "@vocab" => RailsCpcp.standard_iri,
        "id" => "@id", "type" => "@type",
        "operationId" => "https://w3id.org/laquereric/json-rpc-ld/ns#operationId"
      }
    end

    def ok(id:, result:, collection: false)
      body = collection ? { "@graph" => Array(result) } : result
      { "jsonrpc" => "2.0", "@context" => context, "id" => id, "ok" => true, "result" => body }
    end

    def fail(id:, reason:, because:)
      { "jsonrpc" => "2.0", "@context" => context, "id" => id, "ok" => false,
        "error" => { "reason" => reason.to_s, "because" => because.to_s } }
    end
  end
end
