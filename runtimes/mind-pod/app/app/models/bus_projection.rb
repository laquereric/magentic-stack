# frozen_string_literal: true

# ROLE=bus projection row. Metadata derived from BACK's journal, not the
# journal itself (row 73). Not domain state (ADR 0056).
class BusProjection < ApplicationRecord
  self.table_name = "bus_projections"

  validates :source, :payload_json, :projected_at, presence: true
end
