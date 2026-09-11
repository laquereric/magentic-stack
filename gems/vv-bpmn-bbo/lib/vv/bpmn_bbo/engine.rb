# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    # Hosts run the engine's migrations. No isolate_namespace: table names
    # are bpmn_bbo_* via Record.table_name_prefix, not vv_bpmn_bbo_*.
    class Engine < ::Rails::Engine
    end
  end
end
