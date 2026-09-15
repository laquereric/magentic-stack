# frozen_string_literal: true

# T4: a non-engineering owner restates Aim and Receiver. Stored with the
# slice. Does not add a sixteenth table.
class AddPerchT4Restatement < ActiveRecord::Migration[7.0]
  def change
    add_column :perch_slices, :aim_restated, :text
    add_column :perch_slices, :receiver_restated, :text
    add_column :perch_slices, :restated_by_id, :integer
  end
end
