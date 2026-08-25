# frozen_string_literal: true

module Vv
  module Base
    # Canonical Vision home (P10.M1). Not intent_visions.
    class Vision < Record
      include LedgerPlaced
      validates :title, :status, presence: true
      validates :status, inclusion: { in: %w[draft ratified archived] }
    end
  end
end
