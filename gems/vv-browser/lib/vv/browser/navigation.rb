# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"

module Vv
  module Browser
    class Navigation
      attr_reader :id, :context, :url, :session

      def initialize(session, context:, url:)
        @session = session
        @context = context
        @url = url.to_s
        @id = "nav_#{SecureRandom.hex(4)}"
      end

      def to_h
        { id: id, context: context, url: url }
      end
    end
  end
end
