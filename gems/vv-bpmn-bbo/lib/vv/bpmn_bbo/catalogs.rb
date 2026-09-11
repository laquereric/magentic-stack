# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class Message < Record
      include SpecIri
      belongs_to :definition_version
      belongs_to :item_definition, optional: true
      validates :element_id, presence: true, uniqueness: { scope: :definition_version_id }
    end

    class Signal < Record
      include SpecIri
      belongs_to :definition_version
      belongs_to :structure_datatype, class_name: "Datatype", optional: true
      validates :element_id, presence: true, uniqueness: { scope: :definition_version_id }
    end

    class BpmnError < Record
      self.table_name = "bpmn_bbo_errors"
      include SpecIri
      belongs_to :definition_version
      belongs_to :structure_datatype, class_name: "Datatype", optional: true
      validates :element_id, presence: true, uniqueness: { scope: :definition_version_id }
    end

    class Escalation < Record
      include SpecIri
      belongs_to :definition_version
      validates :element_id, presence: true, uniqueness: { scope: :definition_version_id }
    end
  end
end
