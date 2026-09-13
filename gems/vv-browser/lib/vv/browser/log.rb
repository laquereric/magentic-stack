# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"

module Vv
  module Browser
    class Log
      def initialize(session)
        @session = session
      end

      def subscribe
        @session.subscribe(["log.entryAdded"])
      end

      def entries
        @session.events.select { |e| e.method == "log.entryAdded" }.map { |e|
          {
            "level" => e.params["level"] || e.params[:level],
            "text" => e.params["text"] || e.params[:text],
            "timestamp" => e.params["timestamp"] || e.params[:timestamp],
            "type" => e.params["type"] || e.params[:type]
          }
        }
      end

      def texts
        entries.map { |e| e["text"] }.compact
      end
    end
  end
end
