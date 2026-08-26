module Mmg
  module AciaCrud
    # Seed domain entity grounding the AciaCrud gem (biological invariant: grammar + models).
    class AciaCrud < ApplicationRecord
      self.table_name = "mmg_acia_crud_acia_cruds"
      validates :name, presence: true
    end
  end
end
