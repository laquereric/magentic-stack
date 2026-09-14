# frozen_string_literal: true

require "vv-dependency-orch"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

# A fake that completes a round trip, and one that never does.
#
# The second is the more important of the two. Most of this gem's promises are
# about what it does NOT say when it cannot reach something, and a test suite
# that only ever exercises reachable adapters proves none of them.
module FakeAdapters
  # Behaves like Adapters::Base with a scripted outcome.
  class Scripted < Vv::DependencyOrch::Adapters::Base
    attr_reader :calls

    def initialize(outcome:, stdout: "", stderr: "", available: true)
      super()
      @outcome = outcome
      @stdout = stdout
      @stderr = stderr
      @available = available
      @calls = []
    end

    def available? = @available

    def run(argv, timeout: self.timeout)
      @calls << argv
      [@outcome, @stdout, @stderr]
    end

    # Exposes the protected helper so a spec can plant a timeout against it
    # directly -- which is the only way to prove the block never runs.
    def probe(kind: :host, at: "fake", &block)
      round_trip(kind: kind, at: at, argv: %w[fake command], &block)
    end
  end
end
