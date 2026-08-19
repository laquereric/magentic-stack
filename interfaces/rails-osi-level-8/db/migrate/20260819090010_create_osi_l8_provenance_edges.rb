# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8ProvenanceEdges < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_provenance_edges do |t|
      governed_columns(t)
      t.string   :from_cid,     null: false
      t.string   :predicate,    null: false
      t.string   :to_cid
      t.string   :to_iri
      t.string   :agent_iri
      t.string   :activity_cid
      t.datetime :asserted_at,  null: false
    end
    governed_indexes(:osi_l8_provenance_edges)
    add_index :osi_l8_provenance_edges, [:from_cid, :predicate], name: "idx_osi_l8_prov_from_pred"
    add_index :osi_l8_provenance_edges, :to_cid
    add_index :osi_l8_provenance_edges, :activity_cid
  end
end
