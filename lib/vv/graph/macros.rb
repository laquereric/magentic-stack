# frozen_string_literal: true

module Vv
  module Graph
    # Vv::Graph::Macros — the canonical list of named, reusable SPARQL queries over
    # the MM medallion graphs. Stop re-deriving ad-hoc SPARQL at the call site:
    # query the GRAPH through a NAMED macro, so the calculated queries live in one
    # place, are discoverable, and stay correct. Each macro carries its default
    # graph + a description. Run via Macros.run(name) or read the text via
    # Macros.sparql(name); list via Macros.list. Referenced by the doctrine
    # docs/architecture/principles/graph-queries-are-vv-graph-macros.md.
    module Macros
      MACROS = {
        # --- service / fleet liveness (urn:mm:otel# + urn:mm:fleet) ---
        "sidecar_liveness" => {
          graph: "urn:mm:otel#",
          desc:  "Supervised service (sidecar) liveness from mm-tic gauges: name + ok + status.",
          sparql: <<~SPARQL
            SELECT ?name ?ok ?status WHERE {
              ?s <urn:mm:otel#sidecarName> ?name ;
                 <urn:mm:otel#sidecarOk>   ?ok .
              OPTIONAL { ?s <urn:mm:otel#sidecarStatus> ?status }
            }
          SPARQL
        },
        "named_graphs" => {
          graph: nil,
          desc:  "All populated named graphs (the medallion inventory).",
          sparql: "SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } } ORDER BY ?g"
        },

        # --- fleet-bin elimination (urn:mm:fleetbin) — PLAN_0_230_0 S7 ---
        # The residual LOSS: fleet scripts still in project /bin (or core server/),
        # i.e. NOT yet relocated into the mmg-fleet gem's own bin. Target 0.
        # Projected via graph_project (Mm::GraphProject); one FACT per fleet bin
        # {name, logicLines, classification, location, migrationStatus, shouldExist}.
        "fleet_bins_remaining" => {
          graph: "urn:mm:fleetbin",
          desc:  "Fleet bins still in project /bin or core server/ (location != gem_bin) — the elimination residual; target 0.",
          sparql: <<~SPARQL
            PREFIX fb: <urn:mm:fleet#>
            SELECT ?name ?classification ?logicLines ?location ?migrationStatus WHERE {
              ?s a <urn:mm:fleet#FleetBin> ;
                 fb:name ?name ;
                 fb:classification ?classification ;
                 fb:logicLines ?logicLines ;
                 fb:location ?location ;
                 fb:migrationStatus ?migrationStatus .
              FILTER(?location != "gem_bin")
            } ORDER BY ?classification ?name
          SPARQL
        },

        # --- doctrine corpus (urn:mm:graph:doctrine) ---
        "doctrine_titles" => {
          graph: "urn:mm:graph:doctrine",
          desc:  "Every doctrine node + title.",
          sparql: "SELECT ?s ?t WHERE { ?s <urn:mm:doctrine#title> ?t } ORDER BY ?s"
        },
        "doctrine_cost" => {
          graph: "urn:mm:graph:doctrine",
          desc:  "Per-glob coding rules by cost (the optimize work-list).",
          sparql: <<~SPARQL
            SELECT ?s ?cost WHERE {
              ?s <urn:mm:doctrine#kind> "rule" ; <urn:mm:doctrine#cost> ?cost .
            } ORDER BY DESC(?cost)
          SPARQL
        },

        # --- friction (urn:mm:friction) ---
        "friction_open" => {
          graph: "urn:mm:friction",
          desc:  "Open operator-report frictions (route=report, unresolved).",
          sparql: <<~SPARQL
            PREFIX f: <urn:mm:friction#>
            SELECT ?s ?kind ?component ?severity ?occurredAt WHERE {
              ?s a <urn:mm:friction#Friction> ; f:kind ?kind ; f:component ?component ;
                 f:route "report" ; f:severity ?severity ; f:occurredAt ?occurredAt ;
                 f:resolved false .
            } ORDER BY DESC(?occurredAt)
          SPARQL
        },

        # --- git + hypersource delivery (urn:mm:git) ---
        "git_branches" => {
          graph: "urn:mm:git",
          desc:  "Per-repo git state (branch, dirty, ahead/behind).",
          sparql: <<~SPARQL
            PREFIX g: <urn:mm:git#>
            SELECT ?name ?branch ?dirty ?ahead ?behind WHERE {
              ?s a <urn:mm:GitRepo> ; g:name ?name ; g:branch ?branch ;
                 g:dirtyFiles ?dirty ; g:ahead ?ahead ; g:behind ?behind .
            } ORDER BY ?name
          SPARQL
        },
        "git_dirty_files" => {
          graph: "urn:mmg:git:dirty",
          desc:  "All dirty (uncommitted) files across every repo (repo, status, path). " \
                 "Source: Mmg::Git::Repo dirty-file triples (ar-grounded), refreshed by `bin/gitall dirty`.",
          sparql: <<~SPARQL
            PREFIX g: <urn:mm:git#>
            SELECT ?repo ?status ?path WHERE {
              ?r g:dirtyRepo ?repo ; g:dirtyFile ?entry .
              BIND(SUBSTR(?entry, 1, 2) AS ?status)
              BIND(SUBSTR(?entry, 4)    AS ?path)
            } ORDER BY ?repo ?path
          SPARQL
        },
        "hypersource_ops" => {
          graph: "urn:mm:git",
          desc:  "Recent HyperSource delivery actions (materialize / commit_to_ref).",
          sparql: <<~SPARQL
            PREFIX g: <urn:mm:git#>
            SELECT ?s ?op ?ref ?sha ?pane WHERE {
              ?s a <urn:mm:HyperSourceOp> ; g:op ?op .
              OPTIONAL { ?s g:ref ?ref } OPTIONAL { ?s g:sha ?sha } OPTIONAL { ?s g:pane ?pane }
            }
          SPARQL
        },

        # --- backlog dependency DAG (urn:mm:backlog) ---
        "backlog_ready" => {
          graph: "urn:mm:backlog",
          desc:  "Queued briefs whose prerequisites are all done (the pull frontier).",
          sparql: <<~SPARQL
            PREFIX bk: <urn:mm:backlog#>
            SELECT ?brief ?planId ?sliceId WHERE {
              ?brief a bk:Brief ; bk:status "queued" ; bk:planId ?planId .
              OPTIONAL { ?brief bk:sliceId ?sliceId }
              FILTER NOT EXISTS { ?brief bk:dependsOn ?dep . ?dep bk:done false . }
            } ORDER BY ?planId ?sliceId
          SPARQL
        },

        # --- turn-progress telemetry (urn:mm:turn_progress) ---
        "turn_progress_active" => {
          graph: "urn:mm:turn_progress",
          desc:  "Latest progress step + count per turn (the live where-is-each-turn frontier).",
          sparql: <<~SPARQL
            PREFIX tp: <urn:mm:turn_progress#>
            SELECT ?turnId (MAX(?occurredAt) AS ?lastAt) (COUNT(?s) AS ?steps) WHERE {
              ?s a <urn:mm:turn_progress#TurnProgress> ; tp:turnId ?turnId ; tp:occurredAt ?occurredAt .
            } GROUP BY ?turnId ORDER BY DESC(?lastAt)
          SPARQL
        },
        "turn_progress_recent" => {
          graph: "urn:mm:turn_progress",
          desc:  "Recent semantic turn-progress steps (phase + detail) across all turns.",
          sparql: <<~SPARQL
            PREFIX tp: <urn:mm:turn_progress#>
            SELECT ?turnId ?phase ?detail ?occurredAt WHERE {
              ?s a <urn:mm:turn_progress#TurnProgress> ; tp:phase ?phase ; tp:occurredAt ?occurredAt .
              OPTIONAL { ?s tp:turnId ?turnId } OPTIONAL { ?s tp:detail ?detail }
            } ORDER BY DESC(?occurredAt) LIMIT 100
          SPARQL
        }
      }.freeze

      module_function

      def list = MACROS.map { |name, m| { name: name, graph: m[:graph], desc: m[:desc] } }

      def sparql(name)
        m = MACROS[name.to_s] or raise ::ArgumentError, "unknown graph macro #{name.inspect}; known: #{MACROS.keys.join(', ')}"
        m[:sparql]
      end

      def graph_for(name)
        m = MACROS[name.to_s] or return nil
        m[:graph]
      end

      # Run a named macro via Vv::Graph::Sparql.select. graph: overrides the macro's
      # default graph (nil graph = default/union).
      def run(name, graph: :default)
        m = MACROS[name.to_s] or raise ::ArgumentError, "unknown graph macro #{name.inspect}"
        g = graph == :default ? m[:graph] : graph
        ::Vv::Graph::Sparql.select(m[:sparql], graph: g)
      end
    end
  end
end
