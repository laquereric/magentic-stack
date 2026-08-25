# frozen_string_literal: true

module RailsOsiLevel8
  class Record < ::ActiveRecord::Base
    self.abstract_class = true

    # Non-negotiable: private_local never crosses a CPCP PULL boundary.
    scope :cross_boundary, -> { where(ledger_placement: %w[canonical sync_intent]) }
    scope :for_profile, ->(id) { where(profile_id: id) }
  end
end
