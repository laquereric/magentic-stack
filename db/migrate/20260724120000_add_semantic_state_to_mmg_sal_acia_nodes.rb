# frozen_string_literal: true

# Phase B (epic_65): durable typed semantic state on ACIA nodes.
# semantic_state = JSON object (registry-validated keys); lock_version for optimistic CAS.
class AddSemanticStateToMmgSalAciaNodes < ActiveRecord::Migration[8.0]
  def change
    add_column :mmg_sal_acia_nodes, :semantic_state, :text
    add_column :mmg_sal_acia_nodes, :semantic_state_version, :string, default: "1"
    add_column :mmg_sal_acia_nodes, :lock_version, :integer, null: false, default: 0
  end
end
