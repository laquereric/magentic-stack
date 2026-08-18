# frozen_string_literal: true
module RailsOsiLevel8
  # The OSI Level 8 grammar over the CPCP surface. Level 8 is the cybernetic interface:
  # the Cyborg PERCEIVES Context and ACTS via Effect. This maps onto CPCP: a PULL is a
  # Context read (perception); a PUSH is a typed, closed-shape Effect write (action).
  #
  # IMPORTANT (per the POC design): this gem is a SEMANTIC ADAPTER ATOP CPCP. It interprets
  # CPCP operations in the Level 8 grammar (grounding, ledger placement, profile evidence) -
  # it does NOT mount a second RPC surface. /_cpcp (rails-cpcp) remains the single public seam.
  module Grammar
    module_function
    # Context read (perception) - interpret a CPCP PULL result as grounded Level 8 Context.
    def context(pull_result, profile: RailsOsiLevel8.config.profile)
      Envelope.fail(reason: :not_implemented, because: "Grammar.context - map CPCP PULL -> grounded Context + profile evidence")
    end
    # Effect write (action) - validate + place a CPCP PUSH as a grounded Level 8 Effect.
    def effect(push_params, profile: RailsOsiLevel8.config.profile, placement: Ledger::SYNC_INTENT)
      Envelope.fail(reason: :not_implemented, because: "Grammar.effect - ground + closed-shape validate + ledger-place a CPCP PUSH")
    end
  end
end
