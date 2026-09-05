# frozen_string_literal: true
require_relative "graph/version"
# The CPCP seam. Registration is explicit (Cpcp.register! from an initializer),
# so requiring the gem never reaches for Rails that may not be there.
require_relative "graph/cpcp"

# mmg-graph -- the wrapper around the RUST graph DB (Oxigraph). One SPARQL surface; federation anticipated.
module Mmg
  module Graph
    GRAMMAR  = ::File.expand_path("graph/grammar.bnf", __dir__)
    BOUNDARY = ::File.expand_path("graph/boundary.ttl", __dir__)

    # A GRAPH NAME IS UNIQUE PER DATABASE; THE STORE IS NOT.
    #
    # An entry's graph is named for its row id, which is a SQLite autoincrement:
    # unique in ONE database, while the graph lives in a store several databases
    # can reach. Two databases pointed at one store therefore issue the same
    # names, and the second writer's triples land in the first writer's graph --
    # silently, because the store is happy to accept them.
    #
    # Observed 2026-09-05: containers with an ephemeral database and the
    # production oxigraph asserted 5,107 triples into a graph production already
    # owned, and created another that production had no row for.
    #
    # MMG_GRAPH_NAMESPACE inserts a segment that a second database cannot
    # accidentally share, making the collision impossible rather than detected.
    #
    # DEFAULT IS THE LEGACY NAME, deliberately. Stores already hold graphs named
    # the old way, and a database that renamed its graphs would lose track of
    # every triple it had already asserted -- so adopting a namespace on an
    # existing deployment is a data migration, not a config change. Unset means
    # "keep the names I already use". Anything ephemeral should set it.
    NAMESPACE_ENV = "MMG_GRAPH_NAMESPACE"
    NAMESPACE_SHAPE = /\A[A-Za-z0-9._-]+\z/

    module_function

    # nil when unset -- callers name graphs the legacy way.
    def namespace
      raw = ENV.fetch(NAMESPACE_ENV, "").to_s.strip
      return nil if raw.empty?

      # A REFUSAL, NOT A SANITISATION. Quietly stripping bad characters would
      # give two different namespaces the same name, which is the failure this
      # exists to prevent, arriving by a shorter road.
      unless NAMESPACE_SHAPE.match?(raw)
        raise ArgumentError,
              "#{NAMESPACE_ENV}=#{raw.inspect} is not usable in an IRI segment; " \
              "use letters, digits, dot, underscore or hyphen"
      end

      raw
    end

    # DERIVE an action's input_schema FROM this gem's grammar.bnf production, so the grammar is the SINGLE
    # source of truth and schema-drift is physically impossible (human_legible_grammars doctrine;
    # grammar_as_action_interface §5c). Projected live at manifest-load time -- no second checked-in artifact
    # to drift. Fail-open: if the shared deriver isn't mounted, fall back to a permissive object schema.
    def schema_for(production)
      if defined?(::Mmg::Optimize::GrammarSchema)
        ::Mmg::Optimize::GrammarSchema.derive_file(GRAMMAR, production)
      else
        { type: "object" }
      end
    end

    def mcb_actions
      [
        { name: "graphdb_query", domain: "graph", personas: %w[superdev developer],
          describe: "Query the Rust graph DB (Oxigraph) -- SELECT SPARQL -> rows. The wrapped interface.",
          input_schema: schema_for("query"),
          handler: ->(i, _c) { Execute.query(i[:sparql]) } },
        { name: "graphdb_publish", domain: "graph", personas: %w[superdev developer],
          describe: "Publish triples (INSERT DATA) into a named graph in the Rust graph DB.",
          input_schema: schema_for("publish"),
          handler: ->(i, _c) { Execute.publish(i[:triples], graph: (i[:graph] || "urn:mmg:graph:default")) } },
        { name: "graphdb_update", domain: "graph", personas: %w[superdev developer],
          describe: "Run a raw SPARQL UPDATE against the Rust graph DB.",
          input_schema: schema_for("update"),
          handler: ->(i, _c) { Execute.update(i[:sparql]) } },
        { name: "graphdb_federate", domain: "graph", personas: %w[superdev developer],
          describe: "ANTICIPATED (Manus federated graph DB): query ACROSS endpoints (SPARQL SERVICE / multi-store). Seam -- returns :not_implemented.",
          input_schema: schema_for("federate"),
          handler: ->(i, _c) { Execute.federate(i[:sparql], endpoints: i[:endpoints]) } }
      ]
    end
  end
end
