# frozen_string_literal: true

module Vv
  module DependencyOrch
    # Never-raise results, the CPCP shape, and the same closed-vocabulary
    # discipline vv-code-search uses.
    #
    # The reason this gem needs it is sharper than "exceptions are awkward". The
    # product's whole claim is that it can tell three silences apart -- we never
    # looked, we looked and could not reach it, we reached it and it is not
    # there. An exception is a fourth silence with no place in that vocabulary,
    # and the tempting rescue is `rescue => e; return []`, which is how
    # `unreachable` becomes `absent` and a live image gets reported gone.
    #
    # So the vocabulary is CLOSED. A reason outside the set is a bug in this
    # gem, and `refuse` says so in-band rather than inventing a new one -- a
    # free-text reason field is how the distinctions above rot into "the caller
    # greps the message".
    module Envelope
      REASONS = {
        # The three the plan turns on. Keep them adjacent; they are read together.
        "not_indexed" => "we never looked at this repo, host or registry, so silence here means nothing",
        "unreachable" => "we looked and could not reach it -- this is NOT evidence of absence",

        # Caller-side faults. Named specifically so a gate can plant one and
        # catch it, rather than matching a generic parse failure.
        "tag_is_not_identity" => "a tag was supplied where a digest is required; a mutable tag is not a pin",
        "malformed_digest" => "a digest must be sha256: followed by 64 hex, or a 40-hex git revision",
        "no_such_resource" => "no resource in this inventory has that digest or name",
        "ambiguous_reference" => "that name matches more than one digest; name the digest",
        "unsupported_kind" => "resources are repo, local or remote; nothing else is modelled",

        # Environment.
        "adapter_unavailable" => "the tool or socket this adapter needs is not present here",

        "internal_error" => "a fault inside this gem; the because carries the class and message"
      }.freeze

      module_function

      def ok(**fields)
        { ok: true }.merge(fields)
      end

      # `because` is for a human reading a failure. Callers branch on `reason`,
      # never on this string.
      def refuse(reason, because)
        unless REASONS.key?(reason)
          return {
            ok: false,
            reason: "internal_error",
            because: "vv-dependency-orch produced an unregistered reason #{reason.inspect}: #{because}"
          }
        end

        { ok: false, reason: reason, because: because }
      end

      def ok?(envelope)
        envelope.is_a?(Hash) && envelope[:ok] == true
      end

      # Wraps a block so nothing escapes. The rescue is deliberately broad, for
      # the reason vv-code-search gives: the contract is "returns an envelope",
      # and a StandardError filter would let a NoMemoryError out of a code path
      # whose entire promise is that it does not raise.
      #
      # Default reason is internal_error and NOT `unreachable`, which would be
      # the convenient default in an adapter. Convenient and wrong: a bug in our
      # parsing would then report a reachable host as unreachable, and the
      # operator would go looking at the network.
      def never_raise(reason = "internal_error")
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        refuse(reason, "#{e.class}: #{e.message}")
      end
    end
  end
end
