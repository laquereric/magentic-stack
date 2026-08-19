# frozen_string_literal: true

module RailsOsiLevel8
  class Context < Record
    self.table_name = "osi_l8_contexts"
    include GovernedRecord

    validates :subject_iri, :context_kind, :jsonld, :shape_id, :shape_digest, :admitted_at, presence: true
    validates :context_kind, inclusion: { in: %w[request response state projection] }
  end
end
