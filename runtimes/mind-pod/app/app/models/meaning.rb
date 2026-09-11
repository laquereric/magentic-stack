# frozen_string_literal: true

# Activated under frames, and activates clarifications. Owned by neither
# (docs/architecture/MeaningActivations.md).
class Meaning < ApplicationRecord
  has_many :context_frame_meaning_weights, inverse_of: :meaning,
           dependent: :restrict_with_error
  has_many :context_frames, through: :context_frame_meaning_weights

  has_many :meaning_clarification_weights, inverse_of: :meaning,
           dependent: :restrict_with_error
  has_many :clarifications, through: :meaning_clarification_weights

  def activated_clarifications
    meaning_clarification_weights
      .where("weight > 0").order(weight: :desc).includes(:clarification).map(&:clarification)
  end
end
