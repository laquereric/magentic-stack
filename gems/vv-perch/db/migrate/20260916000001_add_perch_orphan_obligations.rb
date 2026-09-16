# frozen_string_literal: true

# Stage 4. perchv2 §11.2 lists seven obligations of an OPEN orphan entry, and
# §11.3's entry carries the fields that discharge them. The first cut had the
# two tables and about half the fields, so an entry could be open while
# describing none of what it owes -- which is the unmanaged liability the
# ledger exists to prevent, wearing a ledger entry.
#
# No new tables: the fifteen-table count in plan_vv-perch.md §4 is load-bearing
# and this adds columns only.
class AddPerchOrphanObligations < ActiveRecord::Migration[7.0]
  def change
    change_table :perch_orphans, bulk: true do |t|
      # "Decisions held loosely" -- named reversibility measures, e.g. a draft
      # namespace or a rung ceiling. Named, because "we'll be careful" is not one.
      t.text :reversibility_measures

      # "Learning arranged" -- a cadence between the owning teams.
      t.string :collaboration_cadence
      t.text :collaboration_participants

      # §11.3 accepted_by: the entry is accepted by the standing owners of both
      # halves. An entry nobody accepted is a note.
      t.text :accepted_by

      # §11.3 estimated_cost. start_constrained is the one that matters: it is
      # what §7.6's entanglement metric counts.
      t.integer :coordination_hours_per_week
      t.boolean :start_constrained, null: false, default: false

      # §11.3 convergence. start_offset_days and start_first are DERIVED from
      # the parties' p85 cycle times, so they are not stored -- the note is.
      t.text :convergence_note

      # Entries close when the release group releases, or when the cut changed
      # and the dependency disappeared. Which one is a different fact.
      t.datetime :closed_at
      t.string :closed_reason
    end

    # §11.3 convergence.cycle_time_p85_days is keyed by ITEM, so it belongs on
    # the party, not on the entry.
    add_column :perch_orphan_parties, :cycle_time_p85_days, :integer
  end
end
