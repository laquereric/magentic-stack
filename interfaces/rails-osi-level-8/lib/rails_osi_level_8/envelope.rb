# frozen_string_literal: true

module RailsOsiLevel8
  # Never-raise envelope helpers for Level 8 services (not the wire JSON-RPC envelope).
  module Envelope
    module_function

    def ok(value: nil, **meta) = { ok: true, value: value, **meta }

    def fail(reason:, because:, **meta)
      {
        ok: false,
        reason: reason.to_s,
        because: because.is_a?(Hash) ? because : because.to_s,
        **meta
      }
    end
  end
end
