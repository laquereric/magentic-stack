# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"
require_relative "element_handle"

module Vv
  module Browser
    class DomSnapshot
      def initialize(session, context:)
        @session = session
        @context = context
      end

      def capture(css: "body", max_nodes: 100)
        Outcome.capture(reason: :dom_snapshot_failed) do
          loc = @session.browsing_context.locate_nodes(
            @context,
            { "type" => "css", "value" => css.to_s }
          )
          return loc unless loc[:ok]

          nodes = Array(loc.dig(:result, "nodes") || loc.dig(:result, :nodes)).first(max_nodes)
          handles = nodes.map { |n| ElementHandle.from_node(n, context: @context, session: @session) }
          Outcome.ok(context: @context, nodes: nodes, handles: handles.map(&:to_h), n: handles.size)
        end
      end
    end
  end
end
