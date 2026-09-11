# frozen_string_literal: true

# Reaches a frame only THROUGH a meaning. No clarifications.context_frame_id:
# a shortcut would let a clarification inhibit under a frame its meaning does
# not activate (docs/architecture/MeaningActivations.md).
class Clarification < ApplicationRecord
  has_many :meaning_clarification_weights, inverse_of: :clarification,
           dependent: :restrict_with_error
  has_many :meanings, through: :meaning_clarification_weights
end
