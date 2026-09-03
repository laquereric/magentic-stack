# frozen_string_literal: true

# BUS split follow-up: bus_projections now lives in the BUS sqlite
# (db/bus_migrate), not the domain sqlite. Drop the orphaned table from
# primary volumes created before the split. Projections are recomputable
# from BACK's journal (row 73), so no data migration — the bus DB rebuilds
# on next bus.projection.latest.
class RemoveBusProjectionsFromPrimary < ActiveRecord::Migration[8.0]
  def change
    drop_table :bus_projections, if_exists: true
  end
end
