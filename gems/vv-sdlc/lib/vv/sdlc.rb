# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

require "vv-bpmn-bbo"
require_relative "sdlc/version"
require_relative "sdlc/seed"
require_relative "sdlc/engine"

module Vv
  module Sdlc
    module_function

    def version = VERSION
    def seed = Seed.call
    def handles?(params) = Engine.handles?(params)
  end
end
