# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class DefinitionVersion < Record
      belongs_to :package
      has_many :processes, dependent: :destroy
      has_many :collaborations, dependent: :destroy
      has_many :expressions, dependent: :destroy
      has_many :item_definitions, dependent: :destroy
      has_many :datatypes, dependent: :destroy
      has_many :messages, dependent: :destroy
      has_many :signals, dependent: :destroy
      has_many :bpmn_errors, class_name: "BpmnError", dependent: :destroy
      has_many :escalations, dependent: :destroy

      validates :version, presence: true
      validates :source_digest, presence: true
      validates :version, uniqueness: { scope: :package_id }

      after_save :clear_other_latest, if: :is_latest?

      private

      def clear_other_latest
        self.class.where(package_id: package_id).where.not(id: id).update_all(is_latest: false)
      end
    end
  end
end
