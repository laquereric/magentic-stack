# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv; end

module Vv::Graph
  # Rails integration. The substrate's graph engine is the Oxigraph SPARQL
  # sidecar (Vv::Graph::OxirsBackend, SPARQL-over-HTTP) — there is no in-process
  # native extension to boot, so this Railtie no longer hooks
  # config.after_initialize to load anything. It is retained as an (empty)
  # Railtie so the gem's Rails wiring surface is unchanged; the retired
  # sqlite-sparql loader (Vv::Graph::Loader.ensure_extension_loaded!) is gone.
  if defined?(::Rails::Railtie)
    class Railtie < ::Rails::Railtie
    end
  end
end
