# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class OrgJob < Record
      validates :name, :key, presence: true
      validates :key, uniqueness: true
    end

    class OrgRole < Record
      validates :name, :key, presence: true
      validates :key, uniqueness: true
    end

    class OrgAgent < Record
      KINDS = %w[human software].freeze
      has_many :resource_roles, foreign_key: :agent_id, inverse_of: :agent
      validates :kind, presence: true, inclusion: { in: KINDS }
      validate :actor_exists_when_base_loaded

      private

      def actor_exists_when_base_loaded
        return if actor_id.nil?
        return unless defined?(::Vv::Base::Actor)

        unless ::Vv::Base::Actor.exists?(actor_id)
          errors.add(:actor_id, "does not exist")
        end
      end
    end

    class ResourceRole < Record
      KINDS = %w[potential_owner human_performer performer].freeze
      belongs_to :flow_node
      belongs_to :agent, class_name: "OrgAgent", optional: true
      belongs_to :org_role, optional: true
      belongs_to :org_job, optional: true
      belongs_to :assignment_expression, class_name: "Expression", optional: true
      validates :kind, presence: true, inclusion: { in: KINDS }
      validate :exactly_one_assignment

      private

      def exactly_one_assignment
        n = [agent_id, org_role_id, org_job_id, assignment_expression_id].count(&:present?)
        errors.add(:base, "exactly one of agent, org_role, org_job, expression") unless n == 1
      end
    end
  end
end
