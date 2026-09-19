# frozen_string_literal: true

require_relative "../lib/vv-trajectory"

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.expect_with(:rspec) { |e| e.syntax = :expect }
end

T = Vv::Trajectory

module Runs
  AIM = "fix the null check in auth.rb"

  # The worked example: the agent succeeded, and the trajectory shows it ran the
  # whole suite before it had anything to test.
  def self.lucky
    T.record(key: "lucky", aim: AIM, reached_aim: true, prose_chars: 8_000, step_budget: 8,
             steps: [
               { tool: "read_file", args: { path: "auth.rb" }, receipt: { tool: "read_file" } },
               { tool: "run_tests", args: { suite: "all" }, receipt: { tool: "run_tests" } },
               { tool: "write_patch", args: { file: "auth.rb" }, receipt: { tool: "write_patch" } },
               { tool: "run_tests", args: { suite: "auth" }, receipt: { tool: "run_tests" } }
             ]).fetch(:run)
  end

  def self.clean
    T.record(key: "clean", aim: AIM, reached_aim: true, prose_chars: 4_000, step_budget: 8,
             steps: [
               { tool: "read_file", args: { path: "auth.rb" }, receipt: { tool: "read_file" } },
               { tool: "search_code", args: {}, receipt: { tool: "search_code" } },
               { tool: "write_patch", args: { file: "auth.rb" }, receipt: { tool: "write_patch" } },
               { tool: "run_tests", args: { suite: "auth" }, receipt: { tool: "run_tests" } }
             ]).fetch(:run)
  end

  def self.gold
    T.gold(key: "gold", aim: AIM, steps: [
             { accepts: ["read_file"], required_args: { "path" => "auth.rb" } },
             { accepts: %w[search_code grep], required_args: {} },
             { accepts: ["write_patch"], required_args: { "file" => "auth.rb" } },
             { accepts: ["run_tests"], required_args: { "suite" => "auth" } }
           ]).fetch(:gold)
  end

  def self.steps(list) = T.record(key: "x", aim: AIM, steps: list, **@opts.to_h).fetch(:run)

  def self.with(**opts)
    @opts = opts
    yield self
  ensure
    @opts = nil
  end
end
