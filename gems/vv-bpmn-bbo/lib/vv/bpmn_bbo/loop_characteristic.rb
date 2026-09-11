# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class LoopCharacteristic < Record
      self.table_name = "bpmn_bbo_loop_characteristics"
      self.store_full_sti_class = true

      belongs_to :loop_condition, class_name: "Expression", optional: true
      belongs_to :loop_cardinality, class_name: "Expression", optional: true
      belongs_to :completion_condition, class_name: "Expression", optional: true
      belongs_to :collection_item_aware, class_name: "ItemAwareElement", optional: true
      has_many :flow_nodes, foreign_key: :loop_characteristics_id, inverse_of: :loop_characteristics
    end

    class StandardLoopCharacteristics < LoopCharacteristic; end
    class MultiInstanceLoopCharacteristics < LoopCharacteristic; end
  end
end
