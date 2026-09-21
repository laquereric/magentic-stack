# frozen_string_literal: true

module Vv
  module Base
    # Canonical Actor home — shared by P9 GHIS and P10 INTENT. Not ux_actors / intent_actors.
    class Actor < Record
      include LedgerPlaced
      has_many :journeys, class_name: "Vv::Base::Journey",
                          foreign_key: :primary_actor_id, inverse_of: :primary_actor,
                          dependent: :nullify

      # ADR 0074 decision 2. role_key is unique WITHIN a bundle, not across all
      # of them: two applications may each have a "steward". A global uniqueness
      # here would refuse the second application's seed while the scoped index
      # underneath accepted it -- the model and the schema disagreeing about the
      # same rule, which is worse than either answer alone.
      validates :name, :role_key, :bundle_key, presence: true
      validates :role_key, uniqueness: { scope: :bundle_key }
    end
  end
end
