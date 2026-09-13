# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    module Redactor
      SENSITIVE = /
        password|passwd|secret|token|authorization|cookie|api[_-]?key|private[_-]?key
      /xi

      module_function

      def redact(payload)
        case payload
        when Hash
          payload.each_with_object({}) do |(k, v), h|
            key = k.to_s
            h[k] = if key.match?(SENSITIVE)
                     "[REDACTED]"
                   else
                     redact(v)
                   end
          end
        when Array
          payload.map { |v| redact(v) }
        when String
          payload
        else
          payload
        end
      end
    end
  end
end
