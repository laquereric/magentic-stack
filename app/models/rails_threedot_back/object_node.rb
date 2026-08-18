# frozen_string_literal: true
module RailsThreedotBack
  # ObjectNode: an AR row reachable FROM the Cid root.
  class ObjectNode < ApplicationRecord
    self.table_name = "rails_threedot_back_objectnodes"
    belongs_to :cid, class_name: "RailsThreedotBack::Cid"
    def as_api = attributes.slice("name", "kind", "direction", "summary").compact.merge("@type" => "threedot:ObjectNode")
  end
end
