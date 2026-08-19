# frozen_string_literal: true

module RailsOsiLevel8
  module GovernedRecord
    extend ActiveSupport::Concern

    PLACEMENTS = %w[canonical sync_intent private_local].freeze

    included do
      validates :cid, :profile_id, :ledger_placement, :payload_digest, :recorded_at, presence: true
      validates :ledger_placement, inclusion: { in: PLACEMENTS }
      validates :cid, uniqueness: true
      validate :provenance_is_an_object
      before_update  { errors.add(:base, "append-only"); throw(:abort) }
      before_destroy { errors.add(:base, "append-only"); throw(:abort) }
    end

    private

    def provenance_is_an_object
      errors.add(:provenance_json, "must be an object") unless provenance_json.is_a?(Hash)
    end
  end
end
