# frozen_string_literal: true

module RailsOsiLevel8
  class MngRecord < Record
    self.abstract_class = true
    include GovernedRecord
  end

  class MngConcept < MngRecord
    self.table_name = "osi_l8_mng_concepts"
  end

  class MngDefinitionRevision < MngRecord
    self.table_name = "osi_l8_mng_definition_revisions"
  end

  class MngAttestation < MngRecord
    self.table_name = "osi_l8_mng_attestations"
  end

  class MngBinding < MngRecord
    self.table_name = "osi_l8_mng_bindings"
  end

  class MngActivation < MngRecord
    self.table_name = "osi_l8_mng_activations"
  end

  class MngReceipt < MngRecord
    self.table_name = "osi_l8_mng_receipts"
  end

  class MngDispute < MngRecord
    self.table_name = "osi_l8_mng_disputes"
  end

  class MngSemanticDispute < MngRecord
    self.table_name = "osi_l8_mng_semantic_disputes"
  end

  class MngDisputeResolution < MngRecord
    self.table_name = "osi_l8_mng_dispute_resolutions"
  end
end
