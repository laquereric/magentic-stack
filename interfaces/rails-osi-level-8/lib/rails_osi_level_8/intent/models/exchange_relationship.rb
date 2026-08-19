# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class ExchangeRelationship < Record
      self.table_name = "osi_level_8_intent_exchange_relationships"

      validates :exchange_kind, :exchange_status, :summary, presence: true
    end
  end
end
