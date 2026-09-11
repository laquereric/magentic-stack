# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class Expression < Record
      KINDS = %w[expression formal_expression].freeze

      belongs_to :definition_version
      belongs_to :evaluates_to, class_name: "Datatype", optional: true

      validates :kind, presence: true, inclusion: { in: KINDS }
      validates :body, presence: true
    end
  end
end
