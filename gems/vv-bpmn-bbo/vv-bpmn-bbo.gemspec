# frozen_string_literal: true

require_relative "lib/vv/bpmn_bbo/version"

# ADR 0038: this repo is CLOSED, and rule 2 is specific -- no gemspec under
# gems/ may name a laquereric/ repo other than magentic-stack. The gem arrived
# from a standalone private repo whose gemspec pointed at itself, which is the
# exact configuration 0038 was written about: a reader arriving here would be
# directed at the other copy, and that is how divergence starts. Retargeted on
# the way in. The standalone repo is now the non-authoritative copy and 0038
# rule 3 says archive it -- an owner action on GitHub, not taken here.
Gem::Specification.new do |s|
  s.name        = "vv-bpmn-bbo"
  s.version     = Vv::BpmnBbo::VERSION
  s.summary     = "BPMN 2.0 / BBO relational core: spec and run as ActiveRecord."
  s.description = "Schema-only Rails engine. Table prefix bpmn_bbo_. " \
                  "Datatypes are linked records; first ar_class is Vv::Base::Actor. " \
                  "No XML importer. Private; not pushed to rubygems.org. " \
                  "Dry::Monads is not a dependency."
  s.authors     = ["MagenticMarket"]
  s.email       = ["substrate@magenticmarket.ai"]
  s.homepage    = "https://github.com/laquereric/magentic-stack"
  s.license     = "MIT"
  s.files       = Dir["lib/**/*", "db/migrate/**/*", "README.md", "LICENSE", "*.gemspec"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.2"
  s.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-bpmn-bbo",
    "rubygems_mfa_required" => "true"
  }
  s.add_dependency "activerecord", ">= 7.0"
  s.add_dependency "activesupport", ">= 7.0"
  s.add_dependency "railties", ">= 7.0"
  s.add_development_dependency "sqlite3", ">= 1.4"
  s.add_development_dependency "rspec", "~> 3.13"
  s.add_development_dependency "rake", ">= 13.0"
end
