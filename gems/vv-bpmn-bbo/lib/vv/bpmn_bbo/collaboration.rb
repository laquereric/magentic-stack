# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class Collaboration < Record
      include SpecIri
      belongs_to :definition_version
      has_many :participants, dependent: :destroy
      has_many :message_flows, dependent: :destroy
      validates :element_id, presence: true, uniqueness: { scope: :definition_version_id }
    end

    class Participant < Record
      include SpecIri
      belongs_to :collaboration
      belongs_to :process, optional: true
      validates :element_id, presence: true, uniqueness: { scope: :collaboration_id }
    end

    class MessageFlow < Record
      include SpecIri
      belongs_to :collaboration
      belongs_to :source_participant, class_name: "Participant", optional: true
      belongs_to :target_participant, class_name: "Participant", optional: true
      belongs_to :source_node, class_name: "FlowNode", optional: true
      belongs_to :target_node, class_name: "FlowNode", optional: true
      belongs_to :message, optional: true
      validates :element_id, presence: true
    end
  end
end
