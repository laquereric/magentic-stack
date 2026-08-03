require_relative "acia_crud/version"
require_relative "acia_crud/deriver"
module Mmg
  module AciaCrud
    # Derive the full ACIA CRUD skeleton for a resolved AR model. Never-raise.
    def self.derive(model, base_path: nil)
      d = Deriver.new(model, base_path: base_path)
      { create: d.form(:create), update: d.form(:update), table: d.table,
        details: d.details, destroy: d.destroy_action, crud: d.crud }
    rescue => e
      { error: "#{e.class}: #{e.message}" }
    end

    # Derive from an explicit column list [{name:, type:, null:}] (no live DB needed).
    def self.derive_columns(name:, columns:, base_path: nil)
      d = Deriver.from_columns(name: name, columns: columns, base_path: base_path)
      { create: d.form(:create), update: d.form(:update), table: d.table, details: d.details, destroy: d.destroy_action, crud: d.crud }
    rescue => e
      { error: "#{e.class}: #{e.message}" }
    end
  end
end
