# frozen_string_literal: true

module Vv
  module Base
    # Canonical Flow home — shared by P9 GHIS and P10 INTENT. Not ux_flows / intent_flows.
    class Flow < Record
      include LedgerPlaced
      belongs_to :journey, class_name: "Vv::Base::Journey"

      validates :title, :status, :journey_id, presence: true
      validates :status, inclusion: { in: %w[draft active archived] }
    end
  end
end
