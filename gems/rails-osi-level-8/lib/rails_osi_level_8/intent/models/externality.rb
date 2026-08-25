# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class Externality < Record
      self.table_name = "osi_level_8_intent_externalities"

      validates :externality_statement, :externality_polarity, presence: true
    end
  end
end
