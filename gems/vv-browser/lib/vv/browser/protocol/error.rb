# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    module Protocol
      class Error
        attr_reader :code, :message, :data

        def initialize(code:, message:, data: nil)
          @code = code.to_s
          @message = message.to_s
          @data = data
        end

        def to_h
          { "error" => code, "message" => message, "data" => data }.compact
        end
      end
    end
  end
end
