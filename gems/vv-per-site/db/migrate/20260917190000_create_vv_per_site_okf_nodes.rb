# frozen_string_literal: true

class CreateVvPerSiteOkfNodes < ActiveRecord::Migration[7.0]
  def change
    create_table :vv_per_site_okf_nodes do |t|
      t.string :bundle_key, null: false
      t.string :okf_path, null: false
      t.string :parent_okf_path
      t.string :ancestry
      t.string :kind, null: false
      t.string :doc_type
      t.string :title, null: false
      t.text :description
      t.string :slug
      t.string :status
      t.string :okf_version
      t.integer :position, null: false, default: 0
      t.string :generated_by
      t.datetime :generated_at
      t.string :digest
      t.string :source_path
      t.text :tags
      t.text :sources
      t.text :frontmatter
      t.text :body
      t.timestamps
    end

    add_index :vv_per_site_okf_nodes, [:bundle_key, :okf_path], unique: true,
              name: "idx_vv_per_site_okf_nodes_bundle_path"
    add_index :vv_per_site_okf_nodes, :ancestry
    add_index :vv_per_site_okf_nodes, :kind
    add_index :vv_per_site_okf_nodes, :bundle_key
  end
end
