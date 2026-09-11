# frozen_string_literal: true

require_relative "lib/vv/medallion_memory/version"

Gem::Specification.new do |spec|
  spec.name    = "vv-medallion_memory"
  spec.version = Vv::MedallionMemory::VERSION
  spec.authors = ["MagenticMarket contributors"]
  spec.email   = ["substrate@magenticmarket.ai"]

  spec.summary     = "The memory product's contract on the medallion engine: three Build " \
                     "tiers, Platinum refused by name, and summarising on ingest refused too."
  spec.description = <<~DESC.strip
    A bot's yesterday, as a refinement pipeline rather than a bigger context
    window. Bronze lands raw and is never overwritten; Silver resolves identity
    and stamps temporal validity; Gold is task-shaped knowledge injected under a
    hard budget. Each layer adds meaning without destroying the one beneath it,
    which is the only discipline the 2026 memory field is consistently missing.

    This gem is the CONTRACT half. It carries the three canonical Build tiers and
    refuses Platinum, Serving and Working as ranks by name and with reasons; the
    three sibling purposes, so Consume and Operate never need to become tiers to
    be expressible; the closed refusal vocabulary the plan requires to exist
    before any happy path is claimed; the six memory Flow declarations; and the
    Bronze provenance envelope with its observed/inferred flag and bounded
    generation counter.

    It carries no Conformer, no Curator and no projection, and a spec asserts
    that against the source tree. The engine is mmg-medallion, and where it lives
    is an owner decision the plan states twice; EngineBinding.bind! refuses
    medallion_home_undecided so that blocker is one callers hit rather than one
    they have to remember. Everything here was written to be true under either
    answer.

    Platinum is kept out of Gold for one reason worth repeating: a weight matrix
    has no tombstone. A fact cannot be deleted from it the way a row is dropped,
    and a weight update leaves no audit trail for the provenance of the shift.

    Private. Not pushed to rubygems.org.
  DESC

  spec.homepage = "https://github.com/laquereric/magentic-stack"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "allowed_push_host" => "none",
    "source_code_uri" => "https://github.com/laquereric/magentic-stack/tree/main/gems/vv-medallion_memory",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "VERSION"]
  spec.require_paths = ["lib"]
end
