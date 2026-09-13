# frozen_string_literal: true

require_relative "lib/vv/browser/version"

Gem::Specification.new do |s|
  s.name        = "vv-browser"
  s.version     = Vv::Browser::VERSION
  s.summary     = "WebDriver BiDi browser control (Firefox + Chrome, pure Ruby)."
  s.description = "Moved from magentic-market-ai/gems/mmg-browser. Drive a browser over " \
                  "WebDriver BiDi — TCPSocket + websocket-driver, no selenium. " \
                  "Mmg::Browser remains an alias. Private. Not on rubygems.org."
  s.authors     = ["Eric Laquer"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "MIT"
  s.files       = Dir["lib/**/*", "spec/**/*", "features/**/*", "cucumber.yml", "README.md", "vv-browser.gemspec"]
  s.required_ruby_version = ">= 3.3"
  s.add_dependency "websocket-driver", ">= 0.7"
  s.add_development_dependency "rspec", ">= 3.0"
  s.add_development_dependency "cucumber", ">= 9.0"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-browser",
    "rubygems_mfa_required" => "true"
  }
  s.require_paths = ["lib"]
end
