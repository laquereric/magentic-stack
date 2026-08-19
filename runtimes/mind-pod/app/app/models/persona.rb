# frozen_string_literal: true

# Canonical Persona home (P10.M1 standing in for mmg-site Cohort-as-Persona).
# Not intent_personas. Jobs/pains/gains live in the graph later.
class Persona < ApplicationRecord
  validates :name, :status, presence: true
  validates :status, inclusion: { in: %w[draft ratified archived] }
end
