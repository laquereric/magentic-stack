# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "rails/engine"

module Vv
  module Browser
    # Isolated Rails engine so the gem autoloads its app/ tree in the host without
    # colliding names. No migrations (vv-browser holds no AR state -- it drives a
    # browser over BiDi and surfaces events).
    class Engine < ::Rails::Engine
      isolate_namespace Vv::Browser
    end
  end
end
