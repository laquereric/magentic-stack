# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    # Never-raise envelope helper (design §4).
    module Result
      module_function

      def success(**payload)
        { ok: true, **payload }
      end

      def failure(reason, because, **payload)
        { ok: false, reason: reason.to_sym, because: because.to_s, **payload }
      end

      def capture(reason: :error)
        payload = yield
        return payload if payload.is_a?(Hash) && payload.key?(:ok)

        success(**(payload.is_a?(Hash) ? payload : { value: payload }))
      rescue ::StandardError => e
        if e.class.name.include?("RecordInvalid")
          msgs = e.respond_to?(:record) ? e.record.errors.full_messages.join(", ") : e.message
          return failure(:validation_failed, msgs)
        end
        if e.class.name.include?("RecordNotUnique")
          return failure(:conflict, "a canonical or idempotency uniqueness constraint was violated")
        end

        failure(reason, "#{e.class}: #{e.message}")
      end
    end
  end
end
