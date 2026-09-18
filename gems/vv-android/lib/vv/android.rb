# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "vv/mobile"
require_relative "android/version"
require_relative "android/generator"

# vv-android: emit Swift for the official Swift 6.3 Android SDK.
# Dynamic library + @c JNI pins over the vv-mobile shared kit.
# Creates Swift, never SwiftUI, never Compose.
module Vv
  module Android
    ANDROID_SDK = Generator::ANDROID_SDK

    def self.version = VERSION

    def self.generate(spec:, output_dir:)
      parsed = Vv::Mobile::Spec.parse(spec)
      return parsed unless parsed[:ok]
      return { ok: false, reason: "invalid_output", because: "output_dir is required" } if output_dir.nil? || output_dir.to_s.strip.empty?

      Generator.new(spec: parsed[:spec], output_dir: output_dir).generate
    end
  end
end
