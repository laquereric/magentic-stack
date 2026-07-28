# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "rails/engine"

module Mmg
  module Acia
    # Biological membrane: an isolated Rails engine (epic_22). isolate_namespace keeps
    # the ACIA core's models/services from leaking into the host. This gem is the CORE
    # ACIA primitive extracted from mmg-sal (epic_65): the tree model + its markdown
    # materialization + its graph projection. Presentation (unix_tree/dom) stays in
    # mmg-sal, which now DEPENDS ON this core.
    class Engine < ::Rails::Engine
      isolate_namespace Mmg::Acia

      # The gem's hard-structure tables live in this engine's db/migrate; applied only
      # when the host mounts the engine and runs migrations.
      initializer "mmg_acia.migrations" do |app|
        config.paths["db/migrate"].expanded.each do |p|
          app.config.paths["db/migrate"] << p unless app.root.to_s.match?(root.to_s)
        end
      end
    end
  end
end
