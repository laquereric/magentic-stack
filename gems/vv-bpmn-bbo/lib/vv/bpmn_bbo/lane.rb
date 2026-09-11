# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class LaneSet < Record
      include SpecIri
      belongs_to :process
      has_many :lanes, dependent: :destroy
      validates :element_id, presence: true
    end

    class Lane < Record
      include SpecIri
      belongs_to :lane_set
      belongs_to :process
      belongs_to :parent_lane, class_name: "Lane", optional: true
      has_many :lane_flow_nodes, dependent: :destroy
      has_many :flow_nodes, through: :lane_flow_nodes
      validates :element_id, presence: true
    end

    class LaneFlowNode < Record
      belongs_to :lane
      belongs_to :flow_node
      validates :lane_id, uniqueness: { scope: :flow_node_id }
    end
  end
end
