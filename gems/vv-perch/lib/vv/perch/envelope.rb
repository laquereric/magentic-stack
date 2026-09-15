# frozen_string_literal: true

module Vv
  module Perch
    module Envelope
      module_function

      def ok(**fields)
        { ok: true }.merge(fields)
      end

      def refuse(reason, because)
        { ok: false, reason: reason.to_s, because: because }
      end
    end
  end
end
