class CreateMindPod < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.string :title, null: false
      t.text :body
      t.timestamps
    end
    create_table :reconciliations do |t|
      t.integer :note_count, null: false, default: 0
      t.timestamps
    end
  end
end
