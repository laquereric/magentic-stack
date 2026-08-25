# frozen_string_literal: true

module Vv
  module Base
    # Canonical Actor home — shared by P9 GHIS and P10 INTENT. Not ux_actors / intent_actors.
    class Actor < Record
      include LedgerPlaced
      has_many :journeys, class_name: "Vv::Base::Journey",
                          foreign_key: :primary_actor_id, inverse_of: :primary_actor,
                          dependent: :nullify

      validates :name, :role_key, presence: true
      validates :role_key, uniqueness: true
    end
  end
end
