# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class EconomicActor < Record
      self.table_name = "osi_level_8_intent_economic_actors"

      validates :name, :actor_kind, presence: true
    end
  end
end
