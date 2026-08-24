# frozen_string_literal: true

module Vv
  module Base
    # Canonical Journey home — shared by P9 GHIS and P10 INTENT. Not ux_journeys / intent_journeys.
    class Journey < Record
      include LedgerPlaced
      belongs_to :primary_actor, class_name: "Vv::Base::Actor", optional: true
      has_many :flows, class_name: "Vv::Base::Flow", dependent: :destroy

      validates :title, :status, presence: true
      validates :status, inclusion: { in: %w[draft active archived] }
    end
  end
end
