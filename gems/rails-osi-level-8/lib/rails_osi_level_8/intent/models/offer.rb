# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class Offer < Record
      self.table_name = "osi_level_8_intent_offers"

      validates :name, :offer_kind, :description, presence: true
    end
  end
end
