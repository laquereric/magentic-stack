# frozen_string_literal: true

module Vv
  module Base
    # Canonical Persona home (P10.M1 standing in for mmg-site Cohort-as-Persona).
    # Not intent_personas.
    class Persona < Record
      include LedgerPlaced
      validates :name, :status, presence: true
      validates :status, inclusion: { in: %w[draft ratified archived] }
    end
  end
end
