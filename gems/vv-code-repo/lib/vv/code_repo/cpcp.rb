# frozen_string_literal: true

module Vv
  module CodeRepo
    # CPCP projection. No-op when rails-cpcp is absent (mmg-blob pattern).
    module Cpcp
      module_function

      def register!
        # The guard is .project, not the module. Bundler evaluates every path
        # gemspec at setup, so under the root bundle ::RailsCpcp is already
        # defined with ONLY VERSION, the seam never required -- a defined?-only
        # guard walks into NoMethodError there instead of refusing.
        return { ok: false, reason: :cpcp_absent, because: "rails-cpcp is not loaded" } unless defined?(::RailsCpcp) && ::RailsCpcp.respond_to?(:project)

        grant = { "PROCEDURE_WRITE" => ENV["PROCEDURE_WRITE"] }

        ::RailsCpcp.project(model: "Procedure") do
          operation "procedure.put",
            direction: :push, params: %w[operationId digest],
            summary: "Land a revision. Digest is the name. DEV grant for Gold.",
            via: ->(p, _c) {
              landed = Catalog.land(p.merge(grant))
              next landed unless landed[:ok]

              Store.write(landed)
            }

          operation "procedure.get",
            direction: :pull, params: %w[slug],
            summary: "Revision by slug (or digest if provided).",
            via: ->(p, _c) {
              row = Store.fetch(digest: p["digest"], slug: p["slug"])
              next Refusal.build(Refusal::AUDIT_REJECTED, "no procedure #{p['slug']}") unless row

              row.merge(bindings: Store.bindings_for(row[:digest]))
            }

          operation "procedure.list",
            direction: :pull,
            summary: "Catalog.",
            via: ->(_p, _c) { Refusal.ok(procedures: Store.list) }

          operation "procedure.bind",
            direction: :push, params: %w[operationId digest language],
            summary: "Attach a language binding.",
            via: ->(p, _c) {
              b = Catalog.bind(p)
              next b unless b[:ok]

              Store.bind(p["digest"], b)
            }

          operation "procedure.conform",
            direction: :push, params: %w[operationId digest],
            summary: "Bronze → Silver (LinkML still required for Gold).",
            via: ->(p, _c) { Catalog.land(p.merge(grant).merge("tier" => "silver")) }

          operation "procedure.promote",
            direction: :push, params: %w[operationId silver_digest],
            summary: "Silver → Gold. Grant + recommend + contract.",
            via: ->(p, _c) {
              r = Catalog.promote(p.merge(grant))
              next r unless r[:ok]

              Store.write(r.merge(digest: r[:gold_digest], tier: "gold", slug: p["slug"].to_s))
            }

          operation "procedure.graph.get",
            direction: :pull, params: %w[slug],
            summary: "PG neighborhood. Frozen in PROD.",
            via: ->(p, _c) { Refusal.ok(slug: p["slug"], hops: 2, edges: []) }

          operation "procedure.serve",
            direction: :pull, params: %w[slug],
            summary: "Gold only.",
            via: ->(p, _c) {
              row = Store.fetch(slug: p["slug"])
              Catalog.serve("slug" => p["slug"], "tier" => (row && row[:tier]), "gold_digest" => (row && row[:digest]))
            }

          operation "procedure.reject",
            direction: :push, params: %w[operationId digest],
            summary: "Rejection memory.",
            via: ->(p, _c) { Refusal.ok(rejected: p["digest"]) }
        end

        Refusal.ok(operations: Operations.names)
      end
    end
  end
end
