# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "vv/mobile"
require_relative "ios/version"
require_relative "ios/generator"

# vv-ios: emit a SwiftUI iOS/macOS shell that imports the vv-mobile shared
# package. This gem creates Swift (SwiftUI). It never targets Android —
# Swift 6.3's Android SDK has no SwiftUI renderer.
module Vv
  module Ios
    def self.version = VERSION

    def self.generate(spec:, output_dir:)
      parsed = Vv::Mobile::Spec.parse(spec)
      return parsed unless parsed[:ok]
      return { ok: false, reason: "invalid_output", because: "output_dir is required" } if output_dir.nil? || output_dir.to_s.strip.empty?

      Generator.new(spec: parsed[:spec], output_dir: output_dir).generate
    end
  end
end
