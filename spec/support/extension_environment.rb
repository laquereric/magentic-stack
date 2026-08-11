# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# Extension-environment lifecycle for specs (S2+).
#
# Boots ActiveRecord + sqlite3 :memory: for AR models / ProjectionJob,
# and probes the Oxigraph SPARQL sidecar (Vv::Graph::OxirsBackend).
# The retired sqlite-sparql Loader is gone — live graph specs need
# Oxigraph reachable (MM_OXIGRAPH_URL or localhost:7878).
#
# Specs that need a live store tag `:requires_extension`;
# spec_helper.rb skips them when this module reports unavailable.
module Vv::Graph
  module SpecSupport
    module ExtensionEnvironment
      class << self
        def available?
          ensure_attempted!
          @available
        end

        def skip_reason
          ensure_attempted!
          @skip_reason
        end

        # Empties the triple store between examples (Oxigraph CLEAR ALL).
        def reset_store!
          return unless available?

          env = ::Vv::Graph::Sparql.execute("CLEAR ALL")
          return if env.is_a?(Hash) && env[:ok]

          # Fallback: DELETE WHERE default graph
          ::Vv::Graph::Sparql.execute("DELETE { ?s ?p ?o } WHERE { ?s ?p ?o }")
        end

        private

        def ensure_attempted!
          return if defined?(@attempted)
          @attempted = true
          @available = false
          @skip_reason = nil
          attempt_bootstrap
        end

        def attempt_bootstrap
          begin
            require "active_record"
            require "sqlite3"
          rescue LoadError => e
            @skip_reason = "skipping — required gems not loadable (#{e.message}). Run `bundle install`."
            return
          end

          begin
            ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
            ::ActiveRecord::Base.connection.execute("SELECT 1")
          rescue StandardError => e
            @skip_reason = "skipping — ActiveRecord/sqlite3 bootstrap failed: #{e.message}"
            return
          end

          # Probe Oxigraph sidecar (never-raise envelope).
          probe = ::Vv::Graph::Sparql.ask("ASK { ?s ?p ?o }")
          unless probe.is_a?(Hash) && probe[:ok]
            reason = probe.is_a?(Hash) ? (probe[:because] || probe[:reason]) : probe.inspect
            @skip_reason = "skipping — Oxigraph unreachable (#{reason}). " \
                           "Start sidecar or set MM_OXIGRAPH_URL."
            return
          end

          @available = true
        end
      end
    end
  end
end
