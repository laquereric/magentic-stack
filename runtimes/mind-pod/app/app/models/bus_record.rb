# frozen_string_literal: true

# BUS database handle. BUS owns its own sqlite file on the `bus-data` named
# volume (BUS_DB_PATH), separate from the domain sqlite (DB_PATH). Reads of
# BACK's journal go through ApplicationRecord (primary); writes of projections
# go through here.
class BusRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :bus }
end
