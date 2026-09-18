# frozen_string_literal: true
require_relative "lib/vv/ios/version"

# ADR 0038: this repo is CLOSED. homepage must be magentic-stack.
# Origin: laquereric/vv-ios (standalone private copy, non-authoritative).
Gem::Specification.new do |s|
  s.name        = "vv-ios"
  s.version     = Vv::Ios::VERSION
  s.summary     = "Emit a SwiftUI iOS shell over the vv-mobile shared Swift package."
  s.description = "vv-ios generates SwiftUI views, @Observable view-models, and an @main " \
                  "App that consume the Foundation-only package emitted by vv-mobile. " \
                  "Apple-only — Swift 6.3 Android SDK does not render SwiftUI."
  s.authors     = ["CBI Business Transactions, LLC"]
  s.email       = ["LaquerEric@gmail.com"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "LicenseRef-DataYoursSoftwareMine-1.0"
  s.files       = Dir["lib/**/*", "bin/*", "docs/**/*", "README.md", "LICENSE", "*.gemspec"]
  s.require_paths = ["lib"]
  s.bindir      = "bin"
  s.executables = ["vv-ios"]
  s.required_ruby_version = ">= 3.2"
  s.add_dependency "vv-mobile", "~> 0.1"
  s.metadata = {
    "allowed_push_host" => "none",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-ios"
  }
end
