# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"
require_relative "outcome"

module Vv
  module Browser
    # Ground browser actions/events as triples (design §4).
    module GraphGrounding
      VOCAB = "urn:mm:browser#"
      RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

      module_function

      def triples_log
        @triples_log ||= []
      end

      def clear!
        @triples_log = []
        { ok: true }
      end

      def ground_action(kind:, session_id: nil, context: nil, url: nil, intention: nil, **meta)
        Outcome.capture(reason: :ground_failed) do
          iri = "urn:mm:browser:action:#{kind}:#{SecureRandom.hex(4)}"
          triples = []
          triples << nt(iri, RDF_TYPE, "<#{VOCAB}Action>")
          triples << nt(iri, "#{VOCAB}kind", lit(kind))
          triples << nt(iri, "#{VOCAB}session", lit(session_id)) if session_id
          triples << nt(iri, "#{VOCAB}context", lit(context)) if context
          triples << nt(iri, "#{VOCAB}url", lit(url)) if url
          triples << nt(iri, "#{VOCAB}intention", lit(intention)) if intention
          meta.each { |k, v| triples << nt(iri, "#{VOCAB}#{k}", lit(v)) }
          triples_log.concat(triples)
          if defined?(::Vv::Graph::Sparql) && ::Vv::Graph::Sparql.respond_to?(:execute)
            ::Vv::Graph::Sparql.execute("INSERT DATA { GRAPH <urn:mm:graph:browser> {\n#{triples.join("\n")}\n} }") rescue nil
          end
          Outcome.ok(iri: iri, n: triples.size, triples: triples)
        end
      end

      def nt(s, p, o)
        ss = s.start_with?("<") ? s : "<#{s}>"
        "#{ss} <#{p}> #{o} ."
      end

      def lit(v)
        "\"#{v.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\""
      end
    end
  end
end
