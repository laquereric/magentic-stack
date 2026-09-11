# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class FlowNode < Record
      include SpecIri
      self.store_full_sti_class = true

      GATEWAY_DIRECTIONS = %w[unspecified converging diverging mixed].freeze

      belongs_to :process
      belongs_to :container_node, class_name: "FlowNode", optional: true
      belongs_to :loop_characteristics, optional: true
      belongs_to :default_flow, class_name: "SequenceFlow", optional: true
      belongs_to :called_process, class_name: "Process", optional: true
      belongs_to :attached_to, class_name: "FlowNode", optional: true
      has_many :outgoing, class_name: "SequenceFlow", foreign_key: :source_id, inverse_of: :source
      has_many :incoming, class_name: "SequenceFlow", foreign_key: :target_id, inverse_of: :target
      has_many :event_definitions, foreign_key: :event_id, inverse_of: :event, dependent: :destroy
      has_many :resource_roles, dependent: :destroy
      has_many :contained_nodes, class_name: "FlowNode", foreign_key: :container_node_id,
                                 inverse_of: :container_node

      validates :element_id, presence: true, uniqueness: { scope: :process_id }
      validates :type, presence: true
      validates :gateway_direction, inclusion: { in: GATEWAY_DIRECTIONS }, allow_nil: true
    end

    class Activity < FlowNode; end
    class Task < Activity; end
    class UserTask < Task; end
    class ServiceTask < Task; end
    class ScriptTask < Task; end
    class ManualTask < Task; end
    class BusinessRuleTask < Task; end
    class SendTask < Task; end
    class ReceiveTask < Task; end
    class SubProcess < Activity; end
    class AdHocSubProcess < SubProcess; end
    class CallActivity < Activity; end

    class Gateway < FlowNode; end
    class ExclusiveGateway < Gateway; end
    class InclusiveGateway < Gateway; end
    class ParallelGateway < Gateway; end
    class ComplexGateway < Gateway; end
    class EventBasedGateway < Gateway; end

    class Event < FlowNode; end
    class StartEvent < Event; end
    class EndEvent < Event; end
    class IntermediateCatchEvent < Event; end
    class IntermediateThrowEvent < Event; end
    class BoundaryEvent < Event; end
  end
end
