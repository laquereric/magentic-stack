# frozen_string_literal: true

module RailsCpcp
  # One JSON shape for every PUSH replay, whichever cache answered (gaps 53, 55).
  # First-success bodies stay domain-shaped. Replay is this document, not a
  # frozen copy of the first success.
  module Replay
    module_function

    def from_first_result(cached)
      h = cached.is_a?(Hash) ? cached : {}
      gov = h["governance"].is_a?(Hash) ? h["governance"] : {}
      receipt = h["receipt_cid"] || gov["receipt_cid"]
      {
        "replayed" => true,
        "operation_request_cid" => h["operation_request_cid"] || gov["request_cid"],
        "receipt_cid" => receipt,
        "outcome_cid" => h["outcome_cid"],
        "replayed_from_receipt_cid" => h["replayed_from_receipt_cid"] || gov["replayed_from_receipt_cid"] || receipt
      }.compact
    end
  end
end
