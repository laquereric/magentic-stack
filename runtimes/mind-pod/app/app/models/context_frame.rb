# frozen_string_literal: true

# A frame that meanings are activated UNDER, with a signed weight
# (docs/architecture/MeaningActivations.md). There is no
# meanings.context_frame_id: membership is the join row.
class ContextFrame < ApplicationRecord
  has_many :context_frame_meaning_weights, inverse_of: :context_frame,
           dependent: :restrict_with_error
  has_many :meanings, through: :context_frame_meaning_weights

  validates :canonical_id, presence: true, uniqueness: true

  # The OPERATIVE tree, derived per request rather than stored. Positive
  # weights only, strongest first. Inhibitions and inert pairs are still
  # readable through the join -- they are excluded from the walk, not hidden.
  def activated_meanings
    context_frame_meaning_weights
      .where("weight > 0").order(weight: :desc).includes(:meaning).map(&:meaning)
  end
end
