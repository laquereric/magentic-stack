# frozen_string_literal: true
module Mmg
  module Switchyard
    # The CID Config <-> Switchyard contract machinery: an LLM-assistance call is grounded
    # by a CID, configured as a Config, executed via the Client, and its result validated
    # against closed shapes. Never-raise. TODO(grok, per the Switchyard design memo in docs/):
    # the request/response schema + closed validation.
    module Contract
      module_function
      def call(_config, _request, ctx: nil)
        Outcome.fail(reason: :not_implemented, because: "Contract.call — see docs/ (Switchyard design memo)")
      end
    end
  end
end
