# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class Documentation < Record
      belongs_to :subject, polymorphic: true
      validates :text, presence: true
    end

    class ExtensionValue < Record
      belongs_to :owner, polymorphic: true
      belongs_to :value, class_name: "TypedValue", optional: true
      validates :namespace, :local_name, presence: true
    end
  end
end
