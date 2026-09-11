# frozen_string_literal: true

# The second edge. Same algebra as ContextFrameMeaningWeight, same reasons
# (docs/architecture/MeaningActivations.md).
class MeaningClarificationWeight < ApplicationRecord
  WEIGHT_RANGE = (-1..1)

  belongs_to :meaning, inverse_of: :meaning_clarification_weights, optional: false
  belongs_to :clarification, inverse_of: :meaning_clarification_weights, optional: false

  validates :meaning_id, uniqueness: {
    scope: :clarification_id, message: "activation_not_unique",
  }
  validates :weight, numericality: {
    greater_than_or_equal_to: -1, less_than_or_equal_to: 1,
    message: "weight_out_of_range",
  }
end
