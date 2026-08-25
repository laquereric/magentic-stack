# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class Stakeholder < Record
      self.table_name = "osi_level_8_intent_stakeholders"

      validates :name, :stakeholder_kind, :stake_statement, presence: true
    end
  end
end
