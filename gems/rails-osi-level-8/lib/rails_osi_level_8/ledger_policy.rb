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

    # APPLICATION OPERATIONS REGISTER THEIR OWN PLACEMENTS.
    #
    # RULES is the PROTOCOL's map and stays closed. An application that wraps its
    # own operations needs placements for them, and until this existed the only
    # way to get one was to add the application's operation names to RULES --
    # which would make the substrate name its consumers, the thing ADR 0063 says
    # it must not do, and would put an application contract in the protocol gem,
    # the thing shapes-application exists to prevent.
    #
    # So the substrate declares HOW to be extended without knowing WHO extends
    # it. An application registers from its own initializer:
    #
    #   RailsOsiLevel8::LedgerPolicy.register("acia.publish",
    #     request: :sync_intent, context: :canonical, receipt: :canonical)
    #
    # Two rules keep this from becoming a hole:
    #   a registration may NOT shadow a protocol operation -- the protocol's
    #     placements are not an application's to redefine
    #   values are checked against the closed placement set, so a typo refuses
    #     at registration rather than writing an unknown placement to a ledger
    PLACEMENTS = %w[canonical sync_intent private_local].freeze

    @registered = {}

    class << self
      def register(operation, **evidence_placements)
        op = operation.to_s
        raise ArgumentError, "#{op} is a protocol operation; its placements are not an application's to redefine" if RULES.key?(op)
        raise ArgumentError, "register #{op} with at least one evidence placement" if evidence_placements.empty?

        evidence_placements.each do |evidence, placement|
          unless PLACEMENTS.include?(placement.to_s)
            raise ArgumentError,
                  "unknown placement #{placement.inspect} for #{op}.#{evidence}; known: #{PLACEMENTS.join(', ')}"
          end
        end

        @registered[op] = evidence_placements.transform_keys(&:to_sym).freeze
        @registered[op]
      end

      def registered = @registered.dup

      # Test seam. Application registrations are process state, not config.
      def reset_registrations! = @registered = {}

      def placement_for!(operation:, evidence:)
        rules = RULES[operation.to_s] || @registered[operation.to_s]
        raise KeyError, "no ledger placement registered for operation #{operation.inspect}" if rules.nil?

        rules.fetch(evidence).to_s
      end
    end
  end
end
