# frozen_string_literal: true

module RailsOsiLevel8
  class ProvenanceEdge < Record
    self.table_name = "osi_l8_provenance_edges"
    include GovernedRecord

    validates :from_cid, :predicate, :asserted_at, presence: true
  end
end
