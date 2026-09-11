# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class TypedValue < Record
      SCALAR_COLUMNS = %i[
        string_value integer_value decimal_value boolean_value
        datetime_value json_value blob_digest
      ].freeze

      belongs_to :datatype
      belongs_to :record, polymorphic: true, optional: true

      validate :payload_matches_datatype

      private

      def payload_matches_datatype
        return if datatype.nil?

        if datatype.kind == "ar_class"
          if record_type != datatype.ar_class_name || record_id.nil?
            errors.add(:base, "ar_class value must be record_type=#{datatype.ar_class_name} + record_id")
          end
          SCALAR_COLUMNS.each do |col|
            errors.add(col, "must be nil for ar_class") unless public_send(col).nil?
          end
          resolve_ar_class
        else
          unless record_type.nil? && record_id.nil?
            errors.add(:record_type, "must be nil unless datatype.kind is ar_class")
          end
        end
      end

      def resolve_ar_class
        return if record_type.blank? || record_id.nil?

        klass = record_type.constantize
        unless klass.respond_to?(:exists?) && klass.exists?(record_id)
          errors.add(:record_id, "does not exist for #{record_type}")
        end
      rescue NameError
        errors.add(:record_type, "class #{record_type} is not loaded")
      end
    end
  end
end
