# frozen_string_literal: true
module RailsOsiLevel8
  # Never-raise envelope, identical in spirit to the base OSI Level 8 / CPCP contract.
  module Envelope
    module_function
    def ok(value: nil, **meta)  = { ok: true,  value: value, **meta }
    def fail(reason:, because:, **meta) = { ok: false, reason: reason.to_s, because: because.to_s, **meta }
  end
end
