# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "mobile/version"
require_relative "mobile/copyright"
require_relative "mobile/spec"
require_relative "mobile/catalog"
require_relative "mobile/compiler"
require_relative "mobile/generator"

# vv-mobile: emit a Foundation-only Swift package that is the shared *brain*
# of a mobile app. One package, compiled twice:
#   - Apple: `swift build` (iOS 17+ / macOS 14+)
#   - Android: `swift build --swift-sdk aarch64-unknown-linux-android28`
#
# This gem creates Swift. It does not create SwiftUI. Platform UI lives in
# vv-ios (SwiftUI) and the Android Kotlin/Compose shell that calls into the
# .so via Swift-Java JNI (see vv-android).
#
# Doctrine: docs/research/Swift.md (Swift 6.3 official Android SDK).
module Vv
  module Mobile
    ANDROID_SDK = Generator::ANDROID_SDK

    def self.version = VERSION

    # Never-raise. `spec` is a Hash, YAML string, file path, or Spec.
    def self.generate(spec:, output_dir:)
      parsed = Spec.parse(spec)
      return parsed unless parsed[:ok]
      return { ok: false, reason: "invalid_output", because: "output_dir is required" } if output_dir.nil? || output_dir.to_s.strip.empty?

      Generator.new(spec: parsed[:spec], output_dir: output_dir).generate
    end

    # Precompile an AIUX intention into an ACIA document (never-raise).
    def self.compile(**kwargs)
      Compiler.compile(**kwargs)
    end
  end
end
