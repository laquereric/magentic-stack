# frozen_string_literal: true

module Vv
  module CodeSearch
    # Never-raise results, the CPCP shape.
    #
    # A lookup is on the hot path of an editor hover and of an SLM step. Neither
    # has anywhere to put an exception: the editor draws nothing and the selector
    # has no branch for a stack trace. So every public entry point in this gem
    # returns one of these two hashes and raises nothing across its boundary.
    #
    # The reason vocabulary is CLOSED and small on purpose. plan_vv-code-search
    # turns on one distinction in particular -- `not_indexed` is not `no_hits` --
    # and a free-text reason field is how that distinction rots into "the caller
    # greps the message".
    module Envelope
      # Every refusal this gem can produce. A reason outside this set is a bug in
      # the gem, not a new case, and `refuse` says so rather than inventing one.
      REASONS = {
        "not_indexed" => "this (repo, fork, rev, schema) was never built, so silence here means nothing",
        "no_such_dimension" => "the schema does not name this dimension",
        "dimension_not_point_query" => "a scan-shaped dimension may not join the hot union",
        "schema_unknown" => "no repo-family schema is registered under that id",
        "index_unreadable" => "the store holds no readable index at that digest",
        "index_corrupt" => "the index exists and does not parse; a half-read index is not a miss",
        "schema_collision" => "two schemas claim the same (repo, fork, rev) digest",
        "bad_line" => "a line number must be a positive integer"
      }.freeze

      module_function

      def ok(**fields)
        { ok: true }.merge(fields)
      end

      # `because` is for a human reading a failure, never for a caller to parse.
      # Callers branch on `reason`.
      def refuse(reason, because)
        unless REASONS.key?(reason)
          return {
            ok: false,
            reason: "index_corrupt",
            because: "vv-code-search produced an unregistered reason #{reason.inspect}: #{because}"
          }
        end
        { ok: false, reason: reason, because: because }
      end

      # Wraps a block so nothing escapes. The rescue is deliberately broad: the
      # contract is "returns an envelope", and a StandardError filter would let
      # a NoMemoryError out of a code path whose whole promise is that it does
      # not raise.
      def never_raise(reason = "index_corrupt")
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        refuse(reason, "#{e.class}: #{e.message}")
      end
    end
  end
end
