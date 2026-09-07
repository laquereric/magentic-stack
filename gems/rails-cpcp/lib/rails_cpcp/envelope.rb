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
      body = collection ? { "@graph" => graph(result) } : result
      { "jsonrpc" => "2.0", "@context" => context, "id" => id, "ok" => true, "result" => body }
    end

    # A HASH IS ONE NODE, NEVER A LIST OF PAIRS.
    #
    # This was `Array(result)`, and Array() on a Hash returns [[k, v], ...]. So an
    # operation declaring result: :collection while returning an object envelope
    # published {"@graph": [["ok", true], ["entries", [...]]]} -- valid JSON, no
    # error raised anywhere, and every caller reading result["entries"] got nil.
    # It shipped that way in mmg-blob's blob.entries and blob.list; the symptom
    # was a receipt page rendering a blank name, three layers away.
    #
    # Array() is the wrong tool here and always was: what is being built is a
    # graph of NODES, and a Hash is one node.
    def graph(result)
      case result
      when Array then result
      when nil   then []
      else [result]
      end
    end

    def fail(id:, reason:, because:)
      { "jsonrpc" => "2.0", "@context" => context, "id" => id, "ok" => false,
        "error" => { "reason" => reason.to_s, "because" => because.to_s } }
    end
  end
end
