# frozen_string_literal: true

module Vv
  module Base
    # Authored schema of what a FlowStep collects or presents.
    # Not P10 intent, not P11 meaning, not ghis-19, not a Page.
    class InformationModel < Record
      include LedgerPlaced

      has_many :fields, class_name: "Vv::Base::InformationField",
                        inverse_of: :information_model, dependent: :destroy
      has_many :flow_steps, class_name: "Vv::Base::FlowStep",
                            inverse_of: :information_model, dependent: :restrict_with_error

      # ADR 0074 decision 2. Unique within a bundle, not across all of them.
      validates :key, :title, :bundle_key, presence: true
      validates :key, uniqueness: { scope: :bundle_key }
    end
  end
end
