# frozen_string_literal: true
module RailsThreedotBack
  # Shape: an AR row reachable FROM the Cid root.
  class Shape < ApplicationRecord
    self.table_name = "rails_threedot_back_shapes"
    belongs_to :cid, class_name: "RailsThreedotBack::Cid"
    def as_api = attributes.slice("name", "kind", "direction", "summary").compact.merge("@type" => "threedot:Shape")
  end
end
