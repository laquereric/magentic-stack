# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class Constraint < Record
      self.table_name = "osi_level_8_intent_constraints"

      validates :name, :kind, :normative_statement, :constraint_status, presence: true
    end
  end
end
