# frozen_string_literal: true
require_relative "lib/vv/android/version"

# ADR 0038: this repo is CLOSED. homepage must be magentic-stack.
# Origin: laquereric/vv-android (standalone private copy, non-authoritative).
Gem::Specification.new do |s|
  s.name        = "vv-android"
  s.version     = Vv::Android::VERSION
  s.summary     = "Emit Swift JNI/@c exports of the vv-mobile kit for the Swift 6.3 Android SDK."
  s.description = "vv-android generates a Swift dynamic library that re-exports the " \
                  "vv-mobile shared package and pins a Swift 6.3 @c ABI so Kotlin can " \
                  "System.loadLibrary the .so built with --swift-sdk aarch64-unknown-linux-android28. " \
                  "No SwiftUI — Android UI stays Kotlin/Jetpack Compose."
  s.authors     = ["CBI Business Transactions, LLC"]
  s.email       = ["LaquerEric@gmail.com"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "LicenseRef-DataYoursSoftwareMine-1.0"
  s.files       = Dir["lib/**/*", "bin/*", "docs/**/*", "README.md", "LICENSE", "*.gemspec"]
  s.require_paths = ["lib"]
  s.bindir      = "bin"
  s.executables = ["vv-android"]
  s.required_ruby_version = ">= 3.2"
  s.add_dependency "vv-mobile", "~> 0.1"
  s.metadata = {
    "allowed_push_host" => "none",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-android"
  }
end
