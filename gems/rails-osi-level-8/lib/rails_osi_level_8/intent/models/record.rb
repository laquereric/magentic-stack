# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    # Abstract base for Profile 10 INTENT socio-economic entity tables.
    class Record < ::ActiveRecord::Base
      self.abstract_class = true

      include Immutable

      PLACEMENTS = %w[canonical sync_intent private_local].freeze
      PROFILE_ID = "osi-level-8/profile-10"

      # Non-negotiable: private_local never crosses a CPCP PULL boundary.
      scope :cross_boundary, -> { where(ledger_placement: %w[canonical sync_intent]) }
      scope :for_profile, ->(id = PROFILE_ID) { where(profile_id: id) }

      validates :cid, :profile_id, :ledger_placement, :state, :payload_digest, :created_at, presence: true
      validates :cid, uniqueness: true
      validates :ledger_placement, inclusion: { in: PLACEMENTS }
    end
  end
end
