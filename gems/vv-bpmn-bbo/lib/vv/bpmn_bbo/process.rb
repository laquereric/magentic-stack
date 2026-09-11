# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class Process < Record
      include SpecIri

      PROCESS_TYPES = %w[none public private].freeze

      belongs_to :definition_version
      has_many :flow_nodes, dependent: :destroy
      has_many :sequence_flows, dependent: :destroy
      has_many :item_aware_elements, dependent: :destroy
      has_many :lane_sets, dependent: :destroy
      has_many :run_instances, class_name: "Vv::BpmnBbo::Run::ProcessInstance",
                               inverse_of: :process, dependent: :restrict_with_error

      validates :element_id, presence: true, uniqueness: { scope: :definition_version_id }
      validates :process_type, inclusion: { in: PROCESS_TYPES }, allow_nil: true
    end
  end
end
