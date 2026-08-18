# frozen_string_literal: true
class CreateRailsThreedotBackTables < ActiveRecord::Migration[8.0]
  def change
    create_table :rails_threedot_back_cids do |t|
      t.string :cid_iri, null: false, index: { unique: true }
      t.string :title
      t.string :base_iri
      t.string :version
      t.timestamps
    end
    create_table :rails_threedot_back_operations do |t|
      t.references :cid, null: false, foreign_key: { to_table: :rails_threedot_back_cids }
      t.string :name, null: false
      t.string :direction        # pull | push
      t.string :summary
      t.json   :params
      t.timestamps
    end
    create_table :rails_threedot_back_capabilities do |t|
      t.references :cid, null: false, foreign_key: { to_table: :rails_threedot_back_cids }
      t.string :name, null: false
      t.string :summary
      t.timestamps
    end
    create_table :rails_threedot_back_shapes do |t|
      t.references :cid, null: false, foreign_key: { to_table: :rails_threedot_back_cids }
      t.string :name, null: false
      t.text   :shape_ttl        # closed SHACL shape (or shape_iri reference)
      t.timestamps
    end
    create_table :rails_threedot_back_object_nodes do |t|
      t.references :cid, null: false, foreign_key: { to_table: :rails_threedot_back_cids }
      t.string :kind
      t.json   :data
      t.integer :parent_id       # tree within the object model
      t.timestamps
    end
  end
end
