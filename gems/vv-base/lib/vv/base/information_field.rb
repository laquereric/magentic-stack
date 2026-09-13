# frozen_string_literal: true

module Vv
  module Base
    class InformationField < Record
      DATATYPES = %w[string text integer boolean date iri enum].freeze
      CARDINALITIES = %w[1 0..1 0..n 1..n].freeze

      belongs_to :information_model, class_name: "Vv::Base::InformationModel"

      validates :name, :datatype, :ordinal, :information_model_id, presence: true
      validates :datatype, inclusion: { in: DATATYPES }
      validates :cardinality, inclusion: { in: CARDINALITIES }
      validates :name, uniqueness: { scope: :information_model_id }
      validates :enum_key, presence: true, if: -> { datatype == "enum" }
    end
  end
end
