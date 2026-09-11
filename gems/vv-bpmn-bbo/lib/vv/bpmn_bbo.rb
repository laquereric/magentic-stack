# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

require_relative "bpmn_bbo/version"
require_relative "bpmn_bbo/record"
require_relative "bpmn_bbo/ledger_placed"
require_relative "bpmn_bbo/spec_iri"
require_relative "bpmn_bbo/datatype"
require_relative "bpmn_bbo/package"
require_relative "bpmn_bbo/definition_version"
require_relative "bpmn_bbo/typed_value"
require_relative "bpmn_bbo/expression"
require_relative "bpmn_bbo/item_definition"
require_relative "bpmn_bbo/catalogs"
require_relative "bpmn_bbo/process"
require_relative "bpmn_bbo/loop_characteristic"
require_relative "bpmn_bbo/flow_node"
require_relative "bpmn_bbo/sequence_flow"
require_relative "bpmn_bbo/event_definition"
require_relative "bpmn_bbo/item_aware_element"
require_relative "bpmn_bbo/lane"
require_relative "bpmn_bbo/org"
require_relative "bpmn_bbo/documentation"
require_relative "bpmn_bbo/collaboration"
require_relative "bpmn_bbo/run"
require_relative "bpmn_bbo/engine" if defined?(::Rails::Engine)

module Vv
  module BpmnBbo
    module_function

    def version = VERSION

    def seed_datatypes
      Datatype.seed
    end
  end
end
