# frozen_string_literal: true

module RailsOsiLevel8
  class ProfileEvidence < Record
    self.table_name = "osi_l8_profile_evidences"
    include GovernedRecord

    validates :subject_cid, :evidence_type, :evidence_cid, :summary_json, presence: true
  end
end
