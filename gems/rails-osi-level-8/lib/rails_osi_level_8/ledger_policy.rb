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
        provenance: :canonical,
        authorization: :canonical,
        reference: :sync_intent,
        routing: :canonical
      },
      "note.list" => { context: :canonical },
      # The session cycle. A wrapped operation MUST appear here: placement_for!
      # fetches, so an unregistered operation refuses rather than being given a
      # default placement. That is the right failure -- guessing where evidence
      # lands is how a private record ends up on a public ledger -- but it does
      # mean wrapping an operation and forgetting this map produces a
      # processing_failed with no obvious cause.
      #
      # Mirrors note.create: the request is what the client PROPOSED (sync_intent)
      # and everything BACK derives from it is canonical.
      "session.open" => {
        request: :sync_intent,
        context: :canonical,
        receipt: :canonical,
        channel: :canonical,
        biography: :canonical,
        provenance: :canonical,
        authorization: :canonical,
        reference: :sync_intent,
        routing: :canonical
      },
      "session.observe" => {
        request: :sync_intent,
        context: :canonical,
        receipt: :canonical,
        channel: :canonical,
        biography: :canonical,
        provenance: :canonical,
        authorization: :canonical,
        reference: :sync_intent,
        routing: :canonical
      },
      "session.close" => {
        request: :sync_intent,
        context: :canonical,
        receipt: :canonical,
        channel: :canonical,
        biography: :canonical,
        provenance: :canonical,
        authorization: :canonical,
        reference: :sync_intent,
        routing: :canonical
      },
      "session.context" => { context: :canonical },
      "session.latest" => { context: :canonical },
      "l8.execution.complete" => { receipt: :canonical, outcome: :canonical, observation: :canonical },
      "l8.observation.record" => { observation: :canonical },
      "l8.outcome.record" => { outcome: :canonical },
      "l8.learning.record" => { learning: :canonical },
      "authorization.trace" => { detail: :private_local, summary: :canonical },
      "admission" => { attempt: :private_local }
    }.freeze

    def self.placement_for!(operation:, evidence:)
      RULES.fetch(operation).fetch(evidence).to_s
    end
  end
end
