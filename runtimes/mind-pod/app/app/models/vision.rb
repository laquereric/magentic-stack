# frozen_string_literal: true

# Canonical Vision home (P10.M1). Not intent_visions.
class Vision < ApplicationRecord
  validates :title, :status, presence: true
  validates :status, inclusion: { in: %w[draft ratified archived] }
end
