# frozen_string_literal: true

module RailsOsiLevel8
  # P9.6 — append-only GHIS rows. Envelope JSON is the Graph document; columns are
  # the governed identity + lookup keys. Never UPDATE/DELETE (callbacks + SQL triggers).
  class UxRecord < Record
    self.abstract_class = true
    include GovernedRecord
  end

  class UxActor < UxRecord
    self.table_name = "osi_l8_ux_actors"
  end

  class UxJourney < UxRecord
    self.table_name = "osi_l8_ux_journeys"
  end

  class UxFlow < UxRecord
    self.table_name = "osi_l8_ux_flows"
  end

  class UxPage < UxRecord
    self.table_name = "osi_l8_ux_pages"
  end

  class UxAciaDocument < UxRecord
    self.table_name = "osi_l8_ux_acia_documents"
  end

  class UxTokenSet < UxRecord
    self.table_name = "osi_l8_ux_token_sets"
  end

  class UxInteractionEvent < UxRecord
    self.table_name = "osi_l8_ux_interaction_events"
  end

  class UxReceipt < UxRecord
    self.table_name = "osi_l8_ux_receipts"
  end

  class UxEvidence < UxRecord
    self.table_name = "osi_l8_ux_evidences"
  end

  class UxActivation < UxRecord
    self.table_name = "osi_l8_ux_activations"
  end
end
