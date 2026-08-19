# frozen_string_literal: true
module RailsThreedotBack
  # Operation: an AR row reachable FROM the Cid root.
  class Operation < ApplicationRecord
    self.table_name = "rails_threedot_back_operations"
    belongs_to :cid, class_name: "RailsThreedotBack::Cid"
    def as_api = attributes.slice("name", "kind", "direction", "summary").compact.merge("@type" => "threedot:Operation")
  end
end
