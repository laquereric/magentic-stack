# frozen_string_literal: true

# Canonical Mission home (P10.M1). Not intent_missions.
class Mission < ApplicationRecord
  validates :title, :status, presence: true
  validates :status, inclusion: { in: %w[draft ratified archived] }
end
