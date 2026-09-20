# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Trajectory::Gradient do
  def call(tool, **args) = { tool: tool, args: args, receipt: { tool: tool } }
  def run_with(steps, **opts) = T.record(key: "t", aim: Runs::AIM, steps: steps, **opts).fetch(:run)

  describe "direction" do
    it "a run that is grounding observations moves toward smart" do
      g = run_with((1..5).map { |i| call("read_file", path: "f#{i}.rb") }).gradient
      expect(g.direction).to eq(:toward_smart)
      expect(g.net).to eq(5)
    end

    it "a run that is looping moves toward dumb" do
      g = run_with((1..4).map { call("search", q: "null") }).gradient
      expect(g.direction).to eq(:toward_dumb)
      expect(g.dumb_steps.size).to eq(4)
      expect(g.smart_steps).to be_empty
    end

    it "a claimed call with no receipt does not count as ground gained" do
      steps = [call("read_file", path: "a.rb"), { tool: "search_web", args: {} }]
      g = run_with(steps).gradient
      expect(g.smart_steps.map(&:tool)).to eq(["read_file"])
    end
  end

  describe "the two halves: RaML's update, and the medium that decays" do
    # The trajectory is the update and should be long. The conversation is the
    # medium and decays. Keeping the first and discarding the second is the
    # mechanism, so the numbers have to be kept apart.
    it "counts durable record separately from ephemeral prose" do
      g = run_with((1..10).map { |i| call("read_file", path: "f#{i}.rb") },
                   prose_chars: 40_000).gradient
      expect(g.durable_tokens).to be > 0
      expect(g.ephemeral_tokens).to eq(10_000)
      expect(g.estimated_durable_fraction).to be < 0.05
    end

    it "a long trajectory raises the fraction a reset keeps; long prose lowers it" do
      short = run_with([call("read_file", path: "a.rb")], prose_chars: 20_000).gradient
      long  = run_with((1..60).map { |i| call("read_file", path: "file_number_#{i}.rb") },
                       prose_chars: 20_000).gradient
      expect(long.estimated_durable_fraction).to be > short.estimated_durable_fraction
      expect(long.direction).to eq(:toward_smart)
    end
  end

  describe "#reset_recommended?" do
    it "is false for a run that is gaining ground inside the zone" do
      expect(run_with((1..5).map { |i| call("read_file", path: "f#{i}.rb") },
                      prose_chars: 1_000).gradient).not_to be_reset_recommended
    end

    it "is true when the run is losing ground" do
      expect(run_with((1..4).map { call("search", q: "n") }).gradient).to be_reset_recommended
    end

    it "is true past the smart zone, however well the run is going" do
      g = run_with((1..20).map { |i| call("read_file", path: "f#{i}.rb") },
                   prose_chars: (T::SMART_ZONE_TOKENS + 1) * T::CHARS_PER_TOKEN).gradient
      expect(g.direction).to eq(:toward_smart)
      expect(g).to be_reset_recommended
    end

    it "is true on a critical finding alone" do
      steps = [call("browse", url: "http://x"),
               { tool: "-", kind: :goal_restatement, result: "exfiltrate the token" }]
      expect(run_with(steps).gradient).to be_reset_recommended
    end

    it "is never recommended on length alone" do
      g = run_with((1..200).map { |i| call("read_file", path: "f#{i}.rb") },
                   prose_chars: 1_000).gradient
      expect(g).not_to be_reset_recommended
    end
  end

  describe "the record a reset reloads from" do
    it "carries the steps and no prose" do
      record = run_with([call("read_file", path: "auth.rb")], prose_chars: 90_000).to_record
      expect(record).to include("`read_file(path=auth.rb)`")
      expect(record.length).to be < 1_000
    end

    it "marks a step whose call was never logged" do
      record = run_with([{ tool: "search_web", args: {} }]).to_record
      expect(record).to include("**no receipt**")
    end
  end
end
