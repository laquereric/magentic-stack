# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"

module Vv
  module Browser
    class Script
      def initialize(session)
        @session = session
      end

      def evaluate(context, expression, await_promise: true)
        res = @session.send_command(
          "script.evaluate",
          {
            "expression" => expression.to_s,
            "target" => { "context" => context },
            "awaitPromise" => !!await_promise
          }
        )
        return res unless res[:ok]

        value = res.dig(:result, "result", "value")
        value = res.dig(:result, "result") if value.nil?
        Outcome.ok(value: value, result: res[:result], context: context)
      end

      def call_function(context, function_declaration, arguments: [], await_promise: true)
        @session.send_command(
          "script.callFunction",
          {
            "functionDeclaration" => function_declaration.to_s,
            "target" => { "context" => context },
            "arguments" => Array(arguments),
            "awaitPromise" => !!await_promise
          }
        )
      end

      def disown(context, handles)
        @session.send_command(
          "script.disown",
          { "target" => { "context" => context }, "handles" => Array(handles) }
        )
      end
    end
  end
end
