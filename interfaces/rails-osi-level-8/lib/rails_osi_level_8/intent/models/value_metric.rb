# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    class ValueMetric < Record
      self.table_name = "osi_level_8_intent_value_metrics"

      validates :name, :metric_dimension, :unit, :desired_direction, presence: true
    end
  end
end
