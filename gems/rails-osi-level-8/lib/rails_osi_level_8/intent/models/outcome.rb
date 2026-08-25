# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class Outcome < Record
      self.table_name = "osi_level_8_intent_outcomes"

      validates :outcome_statement, :outcome_polarity, :observed_at, presence: true
    end
  end
end
