# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class ItemDefinition < Record
      include SpecIri

      ITEM_KINDS = %w[information physical].freeze

      belongs_to :definition_version
      belongs_to :datatype
      has_many :run_variables, class_name: "Vv::BpmnBbo::Run::Variable",
                               inverse_of: :item_definition,
                               dependent: :restrict_with_error

      validates :element_id, presence: true, uniqueness: { scope: :definition_version_id }
      validates :item_kind, presence: true, inclusion: { in: ITEM_KINDS }
    end
  end
end
