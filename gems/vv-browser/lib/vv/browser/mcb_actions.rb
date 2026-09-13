# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "outcome"
require_relative "agent_driver"
require_relative "bidi_session"
require_relative "engine_adapter/mock"

module Vv
  module Browser
    # MCB: browser_open/navigate/read/act/capture/close (design §5).
    module McbActions
      module_function

      def mcb_actions
        [
          {
            name: "browser_open",
            domain: "browser",
            personas: %w[superdev developer],
            describe: "Open BiDi browser session (mock or engine). Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                url: { type: "string" },
                engine: { type: "string", enum: %w[mock firefox chrome chromium] },
                intention: { type: "string" }
              }
            },
            handler: ->(i, _c) {
              h = str(i)
              Browser.open_bidi(url: h["url"], engine: (h["engine"] || "mock").to_sym, intention: h["intention"])
            }
          },
          {
            name: "browser_navigate",
            domain: "browser",
            personas: %w[superdev developer],
            describe: "Navigate active BiDi driver context. Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                url: { type: "string" },
                session_key: { type: "string" }
              },
              required: %w[url]
            },
            handler: ->(i, _c) {
              h = str(i)
              drv = ::Vv::Browser.driver_registry[h["session_key"]] || ::Vv::Browser.last_driver
              return Outcome.fail(reason: :no_driver, because: "no open driver") unless drv

              drv.navigate(h["url"])
            }
          },
          {
            name: "browser_read",
            domain: "browser",
            personas: %w[superdev developer],
            describe: "Read DOM snapshot + title from active driver. Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                css: { type: "string" },
                session_key: { type: "string" }
              }
            },
            handler: ->(i, _c) {
              h = str(i)
              drv = ::Vv::Browser.driver_registry[h["session_key"]] || ::Vv::Browser.last_driver
              return Outcome.fail(reason: :no_driver, because: "no open driver") unless drv

              drv.read(css: h["css"] || "body")
            }
          },
          {
            name: "browser_act",
            domain: "browser",
            personas: %w[superdev developer],
            describe: "Act on page (click/type/evaluate). Never-raise.",
            input_schema: {
              type: "object",
              properties: {
                kind: { type: "string" },
                x: { type: "number" },
                y: { type: "number" },
                text: { type: "string" },
                js: { type: "string" },
                session_key: { type: "string" }
              },
              required: %w[kind]
            },
            handler: ->(i, _c) {
              h = str(i)
              drv = ::Vv::Browser.driver_registry[h["session_key"]] || ::Vv::Browser.last_driver
              return Outcome.fail(reason: :no_driver, because: "no open driver") unless drv

              drv.act(kind: h["kind"], x: h["x"], y: h["y"], text: h["text"], js: h["js"])
            }
          },
          {
            name: "browser_capture",
            domain: "browser",
            personas: %w[superdev developer],
            describe: "Screenshot active browsing context. Never-raise.",
            input_schema: {
              type: "object",
              properties: { session_key: { type: "string" } }
            },
            handler: ->(i, _c) {
              h = str(i)
              drv = ::Vv::Browser.driver_registry[h["session_key"]] || ::Vv::Browser.last_driver
              return Outcome.fail(reason: :no_driver, because: "no open driver") unless drv

              drv.capture
            }
          },
          {
            name: "browser_close",
            domain: "browser",
            personas: %w[superdev developer],
            describe: "Close BiDi driver session. Never-raise.",
            input_schema: {
              type: "object",
              properties: { session_key: { type: "string" } }
            },
            handler: ->(i, _c) {
              h = str(i)
              key = h["session_key"]
              drv = key ? ::Vv::Browser.driver_registry[key] : ::Vv::Browser.last_driver
              return Outcome.fail(reason: :no_driver, because: "no open driver") unless drv

              res = drv.close
              ::Vv::Browser.driver_registry.delete(key) if key
              ::Vv::Browser.last_driver = nil if ::Vv::Browser.last_driver.equal?(drv)
              res
            }
          }
        ]
      end

      def str(i)
        (i || {}).each_with_object({}) { |(k, v), a| a[k.to_s] = v }
      end
    end
  end
end
