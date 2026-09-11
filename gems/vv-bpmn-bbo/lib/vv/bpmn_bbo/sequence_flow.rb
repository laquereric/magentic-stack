# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class SequenceFlow < Record
      include SpecIri

      belongs_to :process
      belongs_to :source, class_name: "FlowNode"
      belongs_to :target, class_name: "FlowNode"
      belongs_to :condition_expression, class_name: "Expression", optional: true

      validates :element_id, presence: true, uniqueness: { scope: :process_id }
    end
  end
end
