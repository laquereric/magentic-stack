# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class ItemAwareElement < Record
      include SpecIri
      self.store_full_sti_class = true

      belongs_to :process
      belongs_to :item_definition, optional: true
      belongs_to :default_value, class_name: "TypedValue", optional: true

      validates :element_id, presence: true, uniqueness: { scope: :process_id }
    end

    class DataObject < ItemAwareElement; end
    class DataObjectReference < ItemAwareElement; end
    class DataStore < ItemAwareElement; end
    class DataStoreReference < ItemAwareElement; end
    class Property < ItemAwareElement; end
    class DataInput < ItemAwareElement; end
    class DataOutput < ItemAwareElement; end

    class DataAssociation < Record
      KINDS = %w[input output].freeze
      belongs_to :process
      belongs_to :source_element, class_name: "ItemAwareElement", optional: true
      belongs_to :target_element, class_name: "ItemAwareElement", optional: true
      belongs_to :transformation_expression, class_name: "Expression", optional: true
      validates :kind, presence: true, inclusion: { in: KINDS }
    end
  end
end
