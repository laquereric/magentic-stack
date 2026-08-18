# frozen_string_literal: true
module RailsThreedotBack
  # Capability: an AR row reachable FROM the Cid root.
  class Capability < ApplicationRecord
    self.table_name = "rails_threedot_back_capabilitys"
    belongs_to :cid, class_name: "RailsThreedotBack::Cid"
    def as_api = attributes.slice("name", "kind", "direction", "summary").compact.merge("@type" => "threedot:Capability")
  end
end
