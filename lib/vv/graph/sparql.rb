# frozen_string_literal: true

require "json"

module Vv; end

module Vv::Graph
  # SPARQL facade — the substrate's graph read/write surface.
  #
  # Executes against the Oxigraph SPARQL sidecar over HTTP via
  # Vv::Graph::OxirsBackend. The sqlite-sparql native extension and its
  # Vv::Graph::Loader are RETIRED — Oxigraph is the only backend, with no
  # fallback. This facade adds the operator-facing niceties on top of the raw
  # backend: scope:/graph: resolution, blank-node-graph refusal, with_types
  # typed rows, RDF-star QuotedTriple writes, and structured bulk writes.
  #
  # Every method returns a never-raise envelope:
  #   success → { ok: true,  … }
  #   failure → { ok: false, reason: <symbol>, because: <verbatim message> }
  #
  #   Vv::Graph::Sparql.select(query, graph: nil)   → { ok:, results: [{var=>term}] }
  #   Vv::Graph::Sparql.ask(query, graph: nil)      → { ok:, value: true|false }
  #   Vv::Graph::Sparql.construct(query, graph: nil)→ { ok:, ntriples: "…" }
  #   Vv::Graph::Sparql.execute(update, graph: nil) → { ok:, count: <integer> }
  module Sparql
    REASON_SPARQL_PARSE_ERROR = :sparql_parse_error
    REASON_GRAPH_UNREACHABLE  = :graph_unreachable
    REASON_UNEXPECTED_ERROR   = :unexpected_error
    REASON_INVALID_GRAPH      = :invalid_graph
    REASON_INVALID_DSL        = :invalid_dsl

    # Raised internally when a write DSL combination is ambiguous (e.g.
    # `CLEAR ALL` + graph:). Rescued at the boundary → :invalid_dsl envelope.
    class InvalidDsl < StandardError; end

    # RDF-star quoted-triple marker for operator-facing write paths. Pass a
    # QuotedTriple wherever an IRI / value is expected; the TermSerializer
    # emits the `<< s p o >>` N-Triples-star encoding.
    QuotedTriple = Struct.new(:s, :p, :o) do
      def initialize(s:, p:, o:)
        super(s, p, o)
        freeze
      end

      def to_ntriples_star
        s_term = QuotedTriple.serialize_term(s, slot: :subject)
        p_term = QuotedTriple.serialize_term(p, slot: :predicate)
        o_term = QuotedTriple.serialize_term(o, slot: :object)
        "<< #{s_term} #{p_term} #{o_term} >>"
      end

      def self.serialize_term(value, slot:)
        return value.to_ntriples_star if value.is_a?(QuotedTriple)
        case slot
        when :subject, :predicate then ::Vv::Graph::Storable::TermSerializer.iri(value)
        else                          ::Vv::Graph::Storable::TermSerializer.object(value)
        end
      end
    end

    def self.quoted_triple(s, p, o)
      QuotedTriple.new(s: s, p: p, o: o)
    end

    module_function

    # Every facade method accepts either the per-kwarg `graph:` or a `scope:`
    # (Vv::Graph::Scope value object). The Scope's `data:` role maps to `graph:`.
    SPARQL_SCOPE_MAPPING = { data: :graph }.freeze

    def select(query, graph: nil, scope: nil, with_types: false)
      graph = resolve_graph(graph: graph, scope: scope)
      return graph if refusal?(graph)
      ge = validate_graph(graph)
      return ge if ge

      env = ::Vv::Graph::OxirsBackend.select(query, graph: graph)
      return env unless env[:ok]

      results = with_types ? typed_rows(env[:results]) : env[:results]
      { ok: true, results: results }
    end

    # typed-row transformer used by select(..., with_types: true). Each cell
    # passes through TermParser.parse_typed → { value:, kind:, datatype:, lang: }.
    def typed_rows(rows)
      rows.map do |row|
        row.transform_values { |raw| ::Vv::Graph::Sparql::TermParser.parse_typed(raw).freeze }
      end
    end

    # Structured plan for a SPARQL query (read-only; never executes). Gem-side
    # parser — independent of the backend.
    def explain(query, graph: nil, scope: nil)
      graph = resolve_graph(graph: graph, scope: scope)
      return graph if refusal?(graph)
      ge = validate_graph(graph)
      return ge if ge

      plan = ::Vv::Graph::Sparql::Explain.parse(query)
      if plan[:kind] == ::Vv::Graph::Sparql::Explain::KIND_UNKNOWN
        return {
          ok: false,
          reason: REASON_SPARQL_PARSE_ERROR,
          because: "Vv::Graph::Sparql.explain: gem-side parser does not recognise this SPARQL form"
        }
      end

      { ok: true, plan: plan, estimated_rows: :unknown, from: :gem_parser }
    end

    def ask(query, graph: nil, scope: nil)
      graph = resolve_graph(graph: graph, scope: scope)
      return graph if refusal?(graph)
      ge = validate_graph(graph)
      return ge if ge

      ::Vv::Graph::OxirsBackend.ask(query, graph: graph)
    end

    def construct(query, graph: nil, scope: nil)
      graph = resolve_graph(graph: graph, scope: scope)
      return graph if refusal?(graph)
      ge = validate_graph(graph)
      return ge if ge

      ::Vv::Graph::OxirsBackend.construct(query, graph: graph)
    end

    # SPARQL 1.1 Update. The backend handles graph-scoping (DATA wrap / WITH).
    def execute(query, graph: nil, scope: nil)
      graph = resolve_graph(graph: graph, scope: scope)
      return graph if refusal?(graph)
      ge = validate_graph(graph)
      return ge if ge

      # CLEAR ALL / CLEAR DEFAULT name the dataset explicitly; combining with
      # graph: is ambiguous — refuse at the boundary (parity with prior facade).
      if graph && query.to_s.strip.match?(/\ACLEAR\s+(ALL|DEFAULT)\s*\z/i)
        return {
          ok: false, reason: REASON_INVALID_DSL,
          because: "CLEAR ALL/DEFAULT does not accept graph: " \
                   "(use execute(\"CLEAR GRAPH <#{graph}>\") to clear a named graph)"
        }
      end

      ::Vv::Graph::OxirsBackend.update(query, graph: graph)
    end

    # Total-triples reader. Omitting graph: → cross-graph total; explicit
    # graph: nil → default-graph only; graph: "<iri>" → that named graph.
    def store_size(**kwargs)
      omitted = !kwargs.key?(:graph)
      graph = kwargs[:graph]

      unless omitted || graph.nil?
        ge = validate_graph(graph)
        return ge if ge
      end

      query =
        if omitted
          "SELECT (COUNT(*) AS ?c) WHERE { { ?s ?p ?o } UNION { GRAPH ?g { ?s ?p ?o } } }"
        else
          "SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }"
        end

      env = ::Vv::Graph::OxirsBackend.select(query, graph: (omitted ? nil : graph))
      return env unless env[:ok]

      raw = (env[:results].first || {})["c"]
      { ok: true, count: ::Vv::Graph::Sparql::TermParser.parse_plain(raw).to_i }
    end

    # Bulk write facade. Accepts Array<Hash{s:,p:,o:,graph:}> or
    # Array<Array>([s,p,o] / [s,p,o,graph]). Rows are grouped by graph,
    # serialised to N-triples via TermSerializer, and written through the
    # backend's INSERT DATA / DELETE DATA. RDF-star quoted-triple shapes are
    # accepted in subject/object positions.
    def bulk_insert(rows, raw: false)
      result = bulk_write(rows, :insert_data, :inserted, raw: raw)
      notify_change_set(:record_adds, rows) if result[:ok] && rows && !rows.empty?
      result
    end

    def bulk_delete(rows, raw: false)
      result = bulk_write(rows, :delete_data, :deleted, raw: raw)
      notify_change_set(:record_retracts, rows) if result[:ok] && rows && !rows.empty?
      result
    end

    # Validate graph IRIs at the gem boundary. nil = default graph (valid).
    # Blank-node graphs refuse; everything else passes to the engine.
    def validate_graph(graph)
      return nil if graph.nil?
      return nil unless graph.is_a?(String)
      return nil unless graph.start_with?("_:")

      { ok: false, reason: REASON_INVALID_GRAPH,
        because: "blank-node graph IRIs are not supported (received #{graph.inspect})" }
    end

    class << self
      private

      # Resolve scope:/graph: to a single graph IRI (or a refusal envelope).
      def resolve_graph(graph:, scope:)
        resolved = ::Vv::Graph::Scope::FacadeAdapter.resolve(
          scope: scope, kwargs: { graph: graph }, mapping: SPARQL_SCOPE_MAPPING,
        )
        return resolved unless resolved.is_a?(Hash) && resolved[:kwargs]

        resolved[:kwargs][:graph]
      end

      def refusal?(value)
        value.is_a?(Hash) && value[:ok] == false
      end

      def refused(reason, because)
        { ok: false, reason: reason, because: because.to_s }
      end

      # ── bulk write backbone ──────────────────────────────────

      def bulk_write(rows, op, payload_key, raw:)
        tuples = raw ? raw_tuples(rows) : normalize_tuples(rows)
        return { ok: true, payload_key => 0 } if tuples.nil? || tuples.empty?

        total = 0
        tuples.group_by { |t| t[3] }.each do |graph, group|
          ntriples = group.map { |(s, p, o, _g)| row_to_ntriple(s, p, o) }.join("\n")
          env = ::Vv::Graph::OxirsBackend.public_send(op, ntriples, graph: graph)
          return env unless env[:ok]

          total += group.size
        end
        { ok: true, payload_key => total }
      rescue InvalidDsl => e
        refused(REASON_INVALID_DSL, e.message)
      rescue ::StandardError => e
        refused(REASON_UNEXPECTED_ERROR, e.message)
      end

      # raw: rows are already engine-form tuples → normalise arity to 4.
      def raw_tuples(rows)
        ::Kernel.Array(rows).map do |row|
          row.length == 3 ? [row[0], row[1], row[2], nil] : row[0, 4]
        end
      end

      # Accept Hash / Array rows → [s, p, o, graph] with quoted-triple coercion.
      def normalize_tuples(rows)
        return [] if rows.nil? || (rows.respond_to?(:empty?) && rows.empty?)
        raise InvalidDsl, "bulk_insert / bulk_delete expects an Array of rows" unless rows.respond_to?(:map)

        rows.map.with_index do |row, idx|
          s, p, o, graph = extract_row(row, idx)
          validate_bulk_graph(graph, idx) if graph

          s = coerce_to_quoted_triple(s, idx, position: "subject")
          o = coerce_to_quoted_triple(o, idx, position: "object")
          if p.is_a?(::Vv::Graph::Sparql::QuotedTriple) || (p.is_a?(Array) && p.length == 3)
            raise InvalidDsl, "row #{idx}: predicate position must be an IRI (W3C SPARQL-star)"
          end

          [s, p, o, graph]
        end
      end

      def row_to_ntriple(s, p, o)
        st = ::Vv::Graph::Storable::TermSerializer.iri(s)
        pt = ::Vv::Graph::Storable::TermSerializer.predicate(p)
        ot = ::Vv::Graph::Storable::TermSerializer.object(o)
        "#{st} #{pt} #{ot} ."
      end

      def coerce_to_quoted_triple(term, idx, position:)
        case term
        when ::Vv::Graph::Sparql::QuotedTriple
          term
        when Array
          if term.length == 3
            ::Vv::Graph::Sparql.quoted_triple(term[0], term[1], term[2])
          else
            raise InvalidDsl,
                  "row #{idx}: #{position} array form expects 3 elements (quoted triple); got #{term.length}"
          end
        else
          term
        end
      end

      def extract_row(row, idx)
        case row
        when Hash
          [row[:s] || row["s"], row[:p] || row["p"], row[:o] || row["o"],
           row[:graph] || row["graph"]]
        when Array
          case row.length
          when 3 then [row[0], row[1], row[2], nil]
          when 4 then row
          else
            raise InvalidDsl, "row #{idx}: array form expects 3 or 4 elements, got #{row.length}"
          end
        else
          raise InvalidDsl, "row #{idx}: expected Hash or Array, got #{row.class}"
        end
      end

      def validate_bulk_graph(graph, idx)
        return unless graph.is_a?(String) && graph.start_with?("_:")

        raise InvalidDsl, "row #{idx}: blank-node graph IRIs are not supported"
      end

      # ── change-set notification (observational; never blocks) ─

      def notify_change_set(method, rows)
        return unless ::Vv::Graph::ChangeSet.active?

        ::Vv::Graph::ChangeSet.send(method, normalize_rows_for_change_set(rows))
      rescue ::Vv::Graph::ChangeSet::ScopeMismatch
        nil
      end

      def normalize_rows_for_change_set(rows)
        rows.map do |row|
          case row
          when Hash
            [row[:s] || row["s"], row[:p] || row["p"],
             row[:o] || row["o"], row[:graph] || row["graph"]]
          when Array
            row.length == 3 ? [row[0], row[1], row[2], nil] : row[0, 4]
          end
        end.compact
      end

      # ── N-triples tokeniser (used by capabilities probe +
      #    Vv::Graph::EtherealGraph via Sparql.send(:split_ntriple)) ─

      def split_ntriple(line)
        terms = []
        rest = line.dup
        while rest && !rest.empty? && terms.length < 3
          rest = rest.lstrip
          break if rest.empty?

          term, rest = take_term(rest)
          return nil unless term

          terms << term
        end
        terms.length == 3 ? terms : nil
      end

      def take_term(rest)
        case rest[0]
        when "<"
          if rest.start_with?("<<")
            return take_quoted_triple_term(rest)
          end

          close = rest.index(">")
          return [nil, nil] unless close

          [rest[0..close], rest[(close + 1)..]]
        when '"'
          i = 1
          while i < rest.length
            if rest[i] == "\\" && i + 1 < rest.length
              i += 2
            elsif rest[i] == '"'
              break
            else
              i += 1
            end
          end
          return [nil, nil] if i >= rest.length

          tail = i + 1
          if rest[tail] == "@"
            tail += 1
            tail += 1 while tail < rest.length && rest[tail] =~ /[A-Za-z0-9-]/
          elsif rest[tail, 2] == "^^"
            tail += 2
            if rest[tail] == "<"
              close = rest.index(">", tail)
              tail = close + 1 if close
            end
          end
          [rest[0...tail], rest[tail..]]
        when "_"
          m = rest.match(/\A_:\S+/)
          return [nil, nil] unless m

          [m[0], rest[m[0].length..]]
        else
          [nil, nil]
        end
      end

      def take_quoted_triple_term(rest)
        depth = 1
        i = 2
        while i < rest.length
          if rest[i, 2] == "<<"
            depth += 1
            i += 2
          elsif rest[i, 2] == ">>"
            depth -= 1
            return [rest[0..(i + 1)], rest[(i + 2)..]] if depth.zero?

            i += 2
          else
            i += 1
          end
        end
        [nil, nil] # unbalanced
      end
    end
  end
end
