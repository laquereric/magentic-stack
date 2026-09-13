# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Browser
    class ElementHandle
      attr_reader :shared_id, :context, :session, :node_type

      def initialize(shared_id:, context:, session: nil, node_type: nil)
        @shared_id = shared_id
        @context = context
        @session = session
        @node_type = node_type
      end

      def to_h
        { "sharedId" => shared_id, "context" => context, "nodeType" => node_type }.compact
      end

      def self.from_node(node, context:, session: nil)
        h = node.is_a?(Hash) ? node.transform_keys(&:to_s) : {}
        new(
          shared_id: h["sharedId"] || h["shared_id"],
          context: context,
          session: session,
          node_type: h["type"] || h["nodeType"]
        )
      end
    end
  end
end
