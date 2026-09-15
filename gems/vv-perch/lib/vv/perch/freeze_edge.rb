# frozen_string_literal: true

module Vv
  module Perch
    class FreezeEdge < Record
      belongs_to :rung_freeze, class_name: "Vv::Perch::Freeze", foreign_key: :freeze_id
      belongs_to :depends_on_freeze, class_name: "Vv::Perch::Freeze",
                                     foreign_key: :depends_on_freeze_id
    end
  end
end
