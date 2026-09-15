# frozen_string_literal: true

module Vv
  module Perch
    class OrphanParty < Record
      belongs_to :orphan, class_name: "Vv::Perch::Orphan"
    end
  end
end
