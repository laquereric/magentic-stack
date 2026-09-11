# frozen_string_literal: true

# The edge itself (docs/architecture/MeaningActivations.md).
#
#   +1        full activation
#   (0, 1)    partial activation
#   0         PRESENT AND INERT -- the pair is known, it does not fire
#   (-1, 0)   partial inhibition
#   -1        full inhibition
#
# No row is not zero. Absence means the pair is not in the model.
class ContextFrameMeaningWeight < ApplicationRecord
  WEIGHT_RANGE = (-1..1)

  belongs_to :context_frame, inverse_of: :context_frame_meaning_weights, optional: false
  belongs_to :meaning, inverse_of: :context_frame_meaning_weights, optional: false

  # A second weight for the same pair is a refusal, not a second line to
  # average. The unique index is the real guard; this names the refusal.
  validates :context_frame_id, uniqueness: {
    scope: :meaning_id, message: "activation_not_unique",
  }
  # Out of range refuses rather than clamping: a clamp would silently record a
  # weight nobody asked for and call it the author's.
  validates :weight, numericality: {
    greater_than_or_equal_to: -1, less_than_or_equal_to: 1,
    message: "weight_out_of_range",
  }
end
