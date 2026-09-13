# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"

module Vv
  module Browser
    class Input
      def initialize(session)
        @session = session
      end

      def perform_actions(context, actions)
        @session.send_command(
          "input.performActions",
          { "context" => context, "actions" => Array(actions) }
        )
      end

      def release_actions(context)
        @session.send_command("input.releaseActions", { "context" => context })
      end

      # High-level helpers compiled to BiDi actions
      def click(context, x:, y:, button: 0)
        actions = [{
          "type" => "pointer",
          "id" => "mouse",
          "parameters" => { "pointerType" => "mouse" },
          "actions" => [
            { "type" => "pointerMove", "x" => x.to_i, "y" => y.to_i },
            { "type" => "pointerDown", "button" => button.to_i },
            { "type" => "pointerUp", "button" => button.to_i }
          ]
        }]
        perform_actions(context, actions)
      end

      def type_text(context, text)
        keys = text.to_s.chars.map { |ch| { "type" => "keyDown", "value" => ch } } +
               text.to_s.chars.map { |ch| { "type" => "keyUp", "value" => ch } }
        actions = [{ "type" => "key", "id" => "keyboard", "actions" => keys }]
        perform_actions(context, actions)
      end
    end
  end
end
