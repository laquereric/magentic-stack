# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class Goal < Record
      self.table_name = "osi_level_8_intent_goals"

      validates :title, :kind, :goal_status, presence: true
    end
  end
end
