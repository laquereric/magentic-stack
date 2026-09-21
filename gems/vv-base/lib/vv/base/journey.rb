# frozen_string_literal: true

module Vv
  module Base
    # Canonical Journey home — shared by P9 GHIS and P10 INTENT. Not ux_journeys / intent_journeys.
    class Journey < Record
      include LedgerPlaced
      belongs_to :primary_actor, class_name: "Vv::Base::Actor", optional: true
      has_many :flows, class_name: "Vv::Base::Flow", dependent: :destroy

      # ADR 0074 decision 1 and its 2026-09-21 amendment: a journey is
      # identified by (bundle_key, journey_key), never by title.
      validates :title, :status, :journey_key, :bundle_key, presence: true
      validates :journey_key, uniqueness: { scope: :bundle_key }
      validates :status, inclusion: { in: %w[draft active archived] }
    end
  end
end
