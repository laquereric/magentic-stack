# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    # Never-raise boundary outcomes (bidi_core_design §2).
    module Outcome
      module_function

      def ok(**payload)
        { ok: true }.merge(payload)
      end

      def fail(reason:, because: nil, **payload)
        b = because
        b = { message: because } if because.is_a?(String)
        { ok: false, reason: reason.to_sym, because: b }.merge(payload)
      end

      def capture(reason: :error)
        v = yield
        return v if v.is_a?(Hash) && v.key?(:ok)

        ok(value: v)
      rescue ::StandardError => e
        fail(reason: reason, because: { message: e.message, class: e.class.name })
      end
    end
  end
end
