# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    class Engine < ::Rails::Engine
      isolate_namespace Mmg::Medallion

      # THE GEM SHIPPED A MIGRATION NOTHING EVER RAN. create_medallions has been
      # here all along (renumbered to 20260922000000 -- see the migration for
      # why), but this engine -- alone among mmg-acia, rails-osi-level-8 and
      # vv-per-site -- never appended its path, so no host ever created
      # `medallions`.
      #
      # It stayed invisible because the table is only touched on a whole-store
      # REPLAY. GraphReplay.storable_models discovers every model declaring
      # triples, and a Medallion declares them, so replay was the one caller that
      # reached a table that was never created:
      #
      #   graph.replay -> ActiveRecord::StatementInvalid: Could not find table 'medallions'
      #
      # which is exactly the false rollback point runtimes/graph/README.md
      # prerequisite 1 warns about -- a reconstructable_from naming a procedure
      # nobody can execute. Same idiom as the sibling engines, deliberately.
      initializer "mmg_medallion.migrations" do |app|
        config.paths["db/migrate"].expanded.each do |p|
          app.config.paths["db/migrate"] << p unless app.root.to_s.match?(root.to_s)
        end
      end
    end
  end
end
