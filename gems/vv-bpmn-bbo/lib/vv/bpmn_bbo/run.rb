# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    module Run
      INSTANCE_STATES = %w[running suspended completed terminated compensating].freeze
      ACTIVITY_STATES = %w[active waiting completed terminated compensating].freeze
      JOB_KINDS = %w[user service script timer message signal].freeze
      JOB_STATES = %w[open claimed completed failed cancelled].freeze

      class ProcessInstance < Record
        self.table_name = "bpmn_bbo_run_process_instances"
        belongs_to :process, class_name: "Vv::BpmnBbo::Process"
        belongs_to :parent, class_name: "ProcessInstance", optional: true
        belongs_to :start_user_agent, class_name: "Vv::BpmnBbo::OrgAgent", optional: true
        has_many :activity_instances, class_name: "ActivityInstance",
                                      foreign_key: :process_instance_id, dependent: :destroy
        has_many :variables, class_name: "Variable",
                             foreign_key: :process_instance_id, dependent: :destroy
        has_many :jobs, class_name: "Job",
                        foreign_key: :process_instance_id, dependent: :destroy
        has_many :event_subscriptions, class_name: "EventSubscription",
                                       foreign_key: :process_instance_id, dependent: :destroy
        validates :state, presence: true, inclusion: { in: INSTANCE_STATES }
      end

      class ActivityInstance < Record
        self.table_name = "bpmn_bbo_run_activity_instances"
        belongs_to :process_instance, class_name: "ProcessInstance"
        belongs_to :flow_node, class_name: "Vv::BpmnBbo::FlowNode"
        belongs_to :parent, class_name: "ActivityInstance", optional: true
        has_many :jobs, class_name: "Job", foreign_key: :activity_instance_id, dependent: :destroy
        validates :state, inclusion: { in: ACTIVITY_STATES }, allow_nil: true
      end

      class Job < Record
        self.table_name = "bpmn_bbo_run_jobs"
        belongs_to :process_instance, class_name: "ProcessInstance"
        belongs_to :activity_instance, class_name: "ActivityInstance"
        belongs_to :flow_node, class_name: "Vv::BpmnBbo::FlowNode"
        belongs_to :assignee_agent, class_name: "Vv::BpmnBbo::OrgAgent", optional: true
        has_many :incidents, class_name: "Incident", foreign_key: :job_id, dependent: :destroy
        validates :kind, presence: true, inclusion: { in: JOB_KINDS }
        validates :state, presence: true, inclusion: { in: JOB_STATES }
      end

      class Variable < Record
        self.table_name = "bpmn_bbo_run_variables"
        belongs_to :process_instance, class_name: "ProcessInstance"
        belongs_to :activity_instance, class_name: "ActivityInstance", optional: true
        belongs_to :item_definition, class_name: "Vv::BpmnBbo::ItemDefinition", optional: true
        belongs_to :value, class_name: "Vv::BpmnBbo::TypedValue"
        validates :name, presence: true
        validates :scope_key, presence: true, uniqueness: true
        before_validation :assign_scope_key

        private

        def assign_scope_key
          self.scope_key = "#{process_instance_id}:#{activity_instance_id || '-'}:#{name}"
        end
      end

      class Incident < Record
        self.table_name = "bpmn_bbo_run_incidents"
        belongs_to :job, class_name: "Job"
        validates :kind, presence: true
      end

      class EventSubscription < Record
        self.table_name = "bpmn_bbo_run_event_subscriptions"
        belongs_to :process_instance, class_name: "ProcessInstance"
        belongs_to :activity_instance, class_name: "ActivityInstance", optional: true
        validates :kind, presence: true
      end
    end
  end
end
