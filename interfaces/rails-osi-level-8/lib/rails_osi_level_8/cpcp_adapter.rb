# frozen_string_literal: true
module RailsOsiLevel8
  # The adapter atop rails-cpcp. Wraps declared CPCP operations so their Context/Effect
  # semantics are interpreted in the Level 8 Grammar (grounding + ledger + profile evidence),
  # WITHOUT introducing a new endpoint family. rails-cpcp keeps /_cpcp; this decorates it.
  # TODO(build): hook RailsCpcp.project operations; attach Grounding + profile evidence to
  # PULL/PUSH; return the never-raise envelope with CID/profile identities.
  module CpcpAdapter
    module_function
    def available? = defined?(::RailsCpcp)
    def wrap(*) = Envelope.fail(reason: :not_implemented, because: "CpcpAdapter.wrap - decorate rails-cpcp ops with Level 8 grammar (no new RPC surface)")
  end
end
