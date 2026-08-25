# frozen_string_literal: true
require "digest"
module RailsCpcp
  # Emits the CID (Cyborg Interface Descriptor) for the mounted app FROM the
  # declared projections. Shape mirrors JSON-RPC-LD-PS1 cid/cid.json.
  module Cid
    module_function

    def document(standard: "JSON-RPC-LD-PS1", title: "rails-cpcp projection")
      {
        "@context" => { "@vocab" => RailsCpcp.standard_iri, "op" => "#{RailsCpcp.base_iri}/op/" },
        "@id" => "#{RailsCpcp.base_iri}/cid",
        "standard" => standard,
        "title" => title,
        "operations" => RailsCpcp::Registry.operations.map { |o| operation_doc(o) }
      }
    end

    def operation_doc(o)
      {
        "@id" => "#{RailsCpcp.base_iri}/op/#{o.name}",
        "name" => o.name,
        "direction" => o.direction.to_s.upcase,
        "summary" => o.summary.to_s,
        "params" => o.params,
        "result" => { "shape" => (o.result == :collection ? "Collection" : "Record") },
        "type" => o.type_iri
      }
    end

    def digest
      Digest::SHA256.hexdigest(JSON.generate(document))[0, 16]
    rescue StandardError
      nil
    end
  end
end
