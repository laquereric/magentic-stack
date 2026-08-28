# frozen_string_literal: true

# The grounding table for ad-hoc graph assertions (mmg-graph ADR 0011).
#
# mmg-graph ships the Entry MODEL but no migration -- the gem is mounted by
# several hosts and does not assume it owns their schema -- so the host creates
# the table. Columns mirror Mmg::Graph::Entry.schema_sql exactly.
#
# date/name/description are NOT NULL because the model validates all three: an
# Entry exists to say when an assertion was made, what it is called and why it
# is here. Triples say what was asserted; they never say why.
class CreateMmgGraphEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :mmg_graph_entries do |t|
      t.string :date,        null: false
      t.string :name,        null: false
      t.text   :description, null: false
      t.timestamps
    end
  end
end
