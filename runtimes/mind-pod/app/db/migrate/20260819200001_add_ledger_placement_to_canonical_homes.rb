# frozen_string_literal: true

# Review fix (gstack finding #1): the canonical intent homes could not represent a
# private_local placement, so a sensitive Mission/Vision/Persona could not be marked
# private nor filtered from a CPCP PULL. Give each a ledger_placement so private_local
# is expressible and excluded at the boundary.
class AddLedgerPlacementToCanonicalHomes < ActiveRecord::Migration[8.0]
  def change
    %i[missions visions personas actors journeys flows].each do |t|
      add_column t, :ledger_placement, :string, null: false, default: "canonical"
      add_index  t, :ledger_placement
    end
  end
end
