# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"
require_relative "capability_matrix"

module Vv
  module Browser
    # Base engine adapter → EndpointDescriptor (design §3).
    class EngineAdapter
      def name
        :base
      end

      def available?
        false
      end

      def bootstrap(headless: true, profile: nil, **opts)
        Outcome.fail(reason: :not_implemented, because: "#{self.class}#bootstrap")
      end

      def endpoint_descriptor(**fields)
        {
          engine: name,
          ws_url: fields[:ws_url],
          bootstrap: fields[:bootstrap] || :fresh,
          process_ref: fields[:process_ref],
          pane_ref: fields[:pane_ref],
          session_id: fields[:session_id],
          metadata: fields[:metadata] || {}
        }
      end

      def supports?(feature)
        CapabilityMatrix.supports?(name, feature)
      end
    end
  end
end
