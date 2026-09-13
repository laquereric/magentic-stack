# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    module Transport
      # Abstract socket/channel for BiDi frames (pluggable; mock in specs).
      class Socket
        def connect(url, headers: {})
          raise NotImplementedError
        end

        def write(text)
          raise NotImplementedError
        end

        def read_available
          raise NotImplementedError
        end

        def close
          raise NotImplementedError
        end

        def open?
          false
        end
      end
    end
  end
end
