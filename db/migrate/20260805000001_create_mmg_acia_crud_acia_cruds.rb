class CreateMmgAciaCrudAciaCruds < ActiveRecord::Migration[7.1]
  def change
    create_table :mmg_acia_crud_acia_cruds do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, default: "active"
      t.timestamps
    end
  end
end
