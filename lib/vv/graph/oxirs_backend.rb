# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "net/http"
require "uri"
require "cgi"
require "json"

module Vv; end

module Vv::Graph
  # OxiGraph SPARQL-1.1-Protocol backend — the substrate's ONLY graph engine.
  #
  # Speaks SPARQL over HTTP to the Oxigraph sidecar (:7878, MM_OXIGRAPH_URL).
  # Supersedes the retired sqlite-sparql native extension: there is NO sqlite
  # fallback and no Vv::Graph::Loader. Every entry point returns the substrate
  # never-raise envelope — { ok: true, ... } | { ok: false, reason:, because: }.
  #
  # RESULT-ENCODING PARITY. SELECT bindings are re-encoded into the SAME
  # N-triples-ish term strings the old engine returned, so
  # Vv::Graph::Sparql::TermParser and every existing caller round-trip:
  #
  #   IRI            → "<urn:mm:x>"
  #   plain literal  → "\"Alpha\""
  #   typed literal  → "\"42\"^^<http://www.w3.org/2001/XMLSchema#integer>"
  #   lang literal   → "\"fr\"@en-US"
  #   blank node     → "_:b0"
  #   quoted triple  → "<< <s> <p> <o> >>"   (RDF-star)
  module OxirsBackend
    DEFAULT_ENDPOINT = "http://localhost:7878"

    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 30

    RESULTS_JSON = "application/sparql-results+json"
    NTRIPLES     = "application/n-triples"
    TURTLE       = "text/turtle"
    FORM_URLENC  = "application/x-www-form-urlencoded"

    class << self
      # Wired. Reachability is surfaced per-call as { ok: false,
      # reason: :graph_unreachable }, not gated here.
      def available?
        true
      end

      def endpoint
        ENV["MM_OXIGRAPH_URL"] || ENV["MM_OXIRS_URL"] ||
          ENV["MM_SLICE_SPARQL_URL"] || DEFAULT_ENDPOINT
      end

      # ── reads ────────────────────────────────────────────────

      def select(query, graph: nil)
        resp = http_query(query, graph: graph, accept: RESULTS_JSON)
        return resp unless resp[:ok]

        json = parse_json(resp[:body])
        return json unless json[:ok]

        bindings = json[:data].dig("results", "bindings") || []
        { ok: true, results: bindings.map { |b| encode_row(b) } }
      end

      def ask(query, graph: nil)
        resp = http_query(query, graph: graph, accept: RESULTS_JSON)
        return resp unless resp[:ok]

        json = parse_json(resp[:body])
        return json unless json[:ok]

        { ok: true, value: json[:data]["boolean"] == true }
      end

      def construct(query, graph: nil)
        resp = http_query(query, graph: graph, accept: NTRIPLES)
        return resp unless resp[:ok]

        { ok: true, ntriples: resp[:body].to_s }
      end

      # ── writes ───────────────────────────────────────────────

      # SPARQL 1.1 Update. `graph:` scopes DATA writes into a named graph
      # (GRAPH { … } wrap); graph-explicit forms (CLEAR/DROP/…) pass through;
      # everything else gets the WITH <graph> prefix (INSERT/DELETE WHERE).
      def update(statement, graph: nil)
        stmt = scope_update(statement.to_s, graph)
        resp = http_update(stmt)
        return resp unless resp[:ok]

        { ok: true, count: statement_count(statement) }
      end

      def insert_data(ntriples, graph: nil)
        body = ntriples.to_s.strip
        return { ok: true, inserted: 0 } if body.empty?

        env = update("INSERT DATA { #{body} }", graph: graph)
        env[:ok] ? { ok: true, inserted: count_triples(body) } : env
      end

      def delete_data(ntriples, graph: nil)
        body = ntriples.to_s.strip
        return { ok: true, deleted: 0 } if body.empty?

        env = update("DELETE DATA { #{body} }", graph: graph)
        env[:ok] ? { ok: true, deleted: count_triples(body) } : env
      end

      # Bulk-load a Turtle document into a named (or default) graph via the
      # SPARQL Graph Store HTTP Protocol (POST /store). Replaces the retired
      # rdf_load_turtle_to_graph sqlite scalar.
      def load_turtle(turtle, graph: nil)
        body = turtle.to_s
        return { ok: true, loaded: 0 } if body.strip.empty?

        uri = store_uri(graph)
        resp = http_post(uri, body, content_type: TURTLE, accept: nil)
        return resp unless resp[:ok]

        { ok: true, loaded: count_triples(body) }
      end

      # ── internals ────────────────────────────────────────────

      private

      def http_query(query, graph:, accept:)
        uri = URI("#{endpoint}/query")
        form = { "query" => query.to_s }
        form["default-graph-uri"] = graph.to_s if graph && !graph.to_s.empty?
        http_form(uri, form, accept: accept)
      end

      def http_update(update)
        uri = URI("#{endpoint}/update")
        http_form(uri, { "update" => update.to_s }, accept: nil)
      end

      def store_uri(graph)
        if graph && !graph.to_s.empty?
          URI("#{endpoint}/store?graph=#{CGI.escape(graph.to_s)}")
        else
          URI("#{endpoint}/store?default")
        end
      end

      def http_form(uri, form, accept:)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = FORM_URLENC
        req["Accept"] = accept if accept
        req.set_form_data(form)
        dispatch(uri, req)
      end

      def http_post(uri, body, content_type:, accept:)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = content_type
        req["Accept"] = accept if accept
        req.body = body
        dispatch(uri, req)
      end

      def dispatch(uri, req)
        resp = Net::HTTP.start(
          uri.hostname, uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT
        ) { |http| http.request(req) }

        code = resp.code.to_i
        if code >= 200 && code < 300
          { ok: true, body: resp.body }
        elsif [400, 422].include?(code)
          { ok: false, reason: :sparql_parse_error, because: truncate(resp.body) }
        else
          { ok: false, reason: :graph_error, because: "HTTP #{code}: #{truncate(resp.body)}" }
        end
      rescue ::StandardError => e
        { ok: false, reason: :graph_unreachable,
          because: "#{e.class}: #{e.message} (endpoint #{endpoint})" }
      end

      def parse_json(body)
        { ok: true, data: ::JSON.parse(body.to_s) }
      rescue ::JSON::ParserError => e
        { ok: false, reason: :unexpected_error, because: "non-JSON from graph: #{e.message}" }
      end

      def truncate(str, max = 500)
        s = str.to_s
        s.length > max ? "#{s[0, max]}…" : s
      end

      # One SPARQL-results-JSON binding row → { "var" => "<ntriples-term>" }.
      # Unbound variables are omitted (parity with the old engine).
      def encode_row(binding)
        binding.each_with_object({}) do |(var, term), row|
          row[var] = term_to_ntriples(term)
        end
      end

      def term_to_ntriples(term)
        case term["type"]
        when "uri"
          "<#{term['value']}>"
        when "bnode"
          "_:#{term['value']}"
        when "literal", "typed-literal"
          v = escape_literal(term["value"].to_s)
          if (lang = term["xml:lang"])
            %("#{v}"@#{lang})
          elsif (dt = term["datatype"])
            %("#{v}"^^<#{dt}>)
          else
            %("#{v}")
          end
        when "triple" # RDF-star quoted triple
          inner = term["value"] || {}
          s = term_to_ntriples(inner["subject"]   || {})
          p = term_to_ntriples(inner["predicate"] || {})
          o = term_to_ntriples(inner["object"]    || {})
          "<< #{s} #{p} #{o} >>"
        else
          term["value"].to_s
        end
      end

      # N-triples literal escaping (matches TermParser's "((?:[^"\\]|\\.)*)"
      # + unescape). Block form so no gsub backreference interpretation.
      def escape_literal(str)
        str.gsub(/[\\"\n\r\t]/) do |c|
          case c
          when "\\" then "\\\\"
          when '"'  then "\\\""
          when "\n" then "\\n"
          when "\r" then "\\r"
          when "\t" then "\\t"
          end
        end
      end

      # Scope a SPARQL UPDATE into a named graph. DATA forms wrap their body in
      # GRAPH { … }; graph-naming DDL passes through; WHERE forms get WITH.
      def scope_update(stmt, graph)
        s = stmt.strip
        return s if graph.nil? || graph.to_s.empty?

        case s
        when /\AINSERT\s+DATA\s*\{(.+)\}\s*\z/im
          "INSERT DATA { GRAPH <#{graph}> { #{Regexp.last_match(1).strip} } }"
        when /\ADELETE\s+DATA\s*\{(.+)\}\s*\z/im
          "DELETE DATA { GRAPH <#{graph}> { #{Regexp.last_match(1).strip} } }"
        when /\A(CLEAR|DROP|CREATE|LOAD|COPY|MOVE|ADD)\b/i
          s # graph named explicitly in the statement
        else
          "WITH <#{graph}>\n#{s}" # INSERT/DELETE WHERE forms
        end
      end

      # Best-effort affected-triple count for the { ok:, count: } envelope.
      # DATA forms count their body; other forms report 0 (Oxigraph's HTTP
      # update surface returns no delta).
      def statement_count(statement)
        m = statement.to_s.strip.match(/\A(?:INSERT|DELETE)\s+DATA\s*\{(.+)\}\s*\z/im)
        m ? count_triples(m[1]) : 0
      end

      def count_triples(body)
        body.to_s.each_line.count { |l| !l.strip.empty? && !l.strip.start_with?("#") }
      end
    end
  end
end
