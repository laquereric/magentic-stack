# frozen_string_literal: true
module Mmg
  module Switchyard
    module Outcome
      module_function
      def ok(value: nil, reason: :ok, because: nil, meta: {})
        { ok: true, reason: reason.to_s, because: because, value: value, meta: meta }
      end
      def fail(reason:, because:, meta: {})
        { ok: false, reason: reason.to_s, because: because.to_s, meta: meta }
      end
    end
  end
end
