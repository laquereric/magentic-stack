# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class MarketSegment < Record
      self.table_name = "osi_level_8_intent_market_segments"

      validates :name, :kind, :definition_statement, presence: true
    end
  end
end
