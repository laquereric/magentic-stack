# frozen_string_literal: true

module RailsOsiLevel8
  # Assigns ledger placement from registered operation + evidence class.
  # NEVER accepts a client-supplied placement.
  class LedgerPolicy
    RULES = {
      "note.create" => {
        request: :sync_intent,
        context: :canonical,
        receipt: :canonical,
        channel: :canonical,
        biography: :canonical,
        provenance: :canonical
      },
      "note.list" => { context: :canonical },
      "l8.execution.complete" => { receipt: :canonical, outcome: :canonical },
      "l8.observation.record" => { observation: :canonical },
      "l8.learning.record" => { learning: :canonical },
      "authorization.trace" => { detail: :private_local, summary: :canonical },
      "admission" => { attempt: :private_local }
    }.freeze

    def self.placement_for!(operation:, evidence:)
      RULES.fetch(operation).fetch(evidence).to_s
    end
  end
end
