# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class ValueProposition < Record
      self.table_name = "osi_level_8_intent_value_propositions"

      validates :value_statement, :proposition_status, presence: true
    end
  end
end
