# frozen_string_literal: true

module RailsOsiLevel8
  class Observation < Record
    self.table_name = "osi_l8_observations"
    include GovernedRecord

    # quality_json may be {} — Rails treats blank Hash as blank, so no presence check.
    validates :observation_kind, :measured_at, :observer_iri, :value_json, presence: true
  end
end
