# frozen_string_literal: true

require_relative "lib/vv/cal_com/version"

# ADR 0038: this repo is CLOSED. homepage must be magentic-stack.
# Origin: laquereric/vv-cal-com (standalone private copy, non-authoritative).
Gem::Specification.new do |s|
  s.name        = "vv-cal-com"
  s.version     = Vv::CalCom::VERSION
  s.summary     = "Ruby client for the Cal.com API v2"
  s.description = "Never-raise Ruby client for Cal.com scheduling: API v2 " \
                  "(bookings, event types, schedules, slots, webhooks, teams), " \
                  "OAuth 2.0, HMAC webhook verify, and embed URLs. Snake_case " \
                  "at the Ruby boundary, camelCase on the wire."
  s.authors     = ["Eric Laquer"]
  s.email       = ["eric@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.files       = Dir["lib/**/*", "README.md", "LICENSE", "docs/**/*"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.license     = "Nonstandard"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-cal-com",
    "rubygems_mfa_required" => "true"
  }
end
