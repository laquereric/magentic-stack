# frozen_string_literal: true

module RailsOsiLevel8
  class AuthorizationEvidence < Record
    self.table_name = "osi_l8_authorization_evidences"
    include GovernedRecord

    DECISIONS = %w[permit deny not_applicable].freeze

    validates :principal_iri, :action, :policy_ref, :decision, :decided_at, :evidence_digest,
              presence: true
    validates :decision, inclusion: { in: DECISIONS }
  end
end
