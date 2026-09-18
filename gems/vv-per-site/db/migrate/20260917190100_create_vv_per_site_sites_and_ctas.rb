# frozen_string_literal: true

class CreateVvPerSiteSitesAndCtas < ActiveRecord::Migration[7.0]
  def change
    create_table :vv_per_site_sites do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :host
      t.string :bundle_key, null: false
      t.text :metadata
      t.timestamps
    end
    add_index :vv_per_site_sites, :key, unique: true
    add_index :vv_per_site_sites, :bundle_key

    create_table :vv_per_site_ctas do |t|
      t.bigint :site_id, null: false
      t.bigint :okf_node_id, null: false
      t.string :key, null: false
      t.string :title, null: false
      t.string :action_kind, null: false
      t.text :payload
      t.timestamps
    end
    add_index :vv_per_site_ctas, [:site_id, :key], unique: true,
              name: "idx_vv_per_site_ctas_site_key"
    add_index :vv_per_site_ctas, [:site_id, :okf_node_id], unique: true,
              name: "idx_vv_per_site_ctas_site_node"
    add_index :vv_per_site_ctas, :okf_node_id
  end
end
