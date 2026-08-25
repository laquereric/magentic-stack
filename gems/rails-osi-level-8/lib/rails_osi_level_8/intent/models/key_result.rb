# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class KeyResult < Record
      self.table_name = "osi_level_8_intent_key_results"

      validates :title, :target_value, :comparison, :target_unit, :result_status, presence: true
    end
  end
end
