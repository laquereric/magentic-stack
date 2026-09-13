# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"
require_relative "navigation"

module Vv
  module Browser
    class BrowsingContext
      def initialize(session)
        @session = session
      end

      def create(type: "tab")
        res = @session.send_command("browsingContext.create", { "type" => type.to_s })
        return res unless res[:ok]

        ctx = res.dig(:result, "context") || res.dig(:result, :context)
        @session.contexts[ctx] = { id: ctx, type: type } if ctx
        Outcome.ok(context: ctx, result: res[:result])
      end

      def navigate(context, url, wait: "complete")
        nav = Navigation.new(@session, context: context, url: url)
        res = @session.send_command(
          "browsingContext.navigate",
          { "context" => context, "url" => url.to_s, "wait" => wait.to_s }
        )
        return res unless res[:ok]

        Outcome.ok(context: context, url: url.to_s, navigation: nav.to_h, result: res[:result])
      end

      def capture_screenshot(context)
        @session.send_command("browsingContext.captureScreenshot", { "context" => context })
      end

      def get_tree(root: nil)
        params = {}
        params["root"] = root if root
        @session.send_command("browsingContext.getTree", params)
      end

      def locate_nodes(context, locator)
        @session.send_command(
          "browsingContext.locateNodes",
          { "context" => context, "locator" => locator }
        )
      end
    end
  end
end
