# frozen_string_literal: true
require_relative "lib/vv/mobile/version"

# ADR 0038: this repo is CLOSED. homepage must be magentic-stack.
# Origin: laquereric/vv-mobile-kit (standalone private copy, non-authoritative).
Gem::Specification.new do |s|
  s.name        = "vv-mobile"
  s.version     = Vv::Mobile::VERSION
  s.summary     = "Emit a Foundation-only Swift package shared by iOS and Android (Swift 6.3 Android SDK)."
  s.description = "vv-mobile generates the shared Swift brain of a mobile app: Codable/Sendable " \
                  "models, actor repositories, URLSession networking, and a never-raise Envelope. " \
                  "One package, compiled twice — Apple `swift build` and " \
                  "`swift build --swift-sdk aarch64-unknown-linux-android28`. No SwiftUI. " \
                  "Doctrine: Swift 6.3 official Android SDK (shared logic, not SwiftUI-on-Android)."
  s.authors     = ["CBI Business Transactions, LLC"]
  s.email       = ["LaquerEric@gmail.com"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "LicenseRef-DataYoursSoftwareMine-1.0"
  s.files       = Dir["lib/**/*", "bin/*", "docs/**/*", "examples/**/*", "README.md", "LICENSE", "*.gemspec"]
  s.require_paths = ["lib"]
  s.bindir      = "bin"
  s.executables = ["vv-mobile"]
  s.required_ruby_version = ">= 3.2"
  s.metadata = {
    "allowed_push_host" => "none",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-mobile"
  }
end
