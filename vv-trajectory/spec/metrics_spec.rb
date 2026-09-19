# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Trajectory::Metrics do
  let(:gold) { Runs.gold }

  describe "the worked example: right answer, wrong path" do
    let(:run) { Runs.lucky }

    it "scores tool selection at 3 of 4 even though the run succeeded" do
      expect(run).to be_reached_aim
      expect(described_class.tool_selection(run, gold)[:precision]).to eq(0.75)
    end

    it "fails the sequencing gate the outcome passed" do
      tau = described_class.sequencing(run, gold)[:tau]
      expect(tau).to be < 0.85
      expect(tau).to eq(0.3333)
    end

    it "catches the invented argument as precision, not as recall" do
      acc = described_class.argument_accuracy(run, gold)
      expect(acc[:recall]).to eq(1.0)
      expect(acc[:precision]).to eq(0.75)
    end
  end

  describe "a clean run" do
    it "matches the oracle on every axis" do
      run = Runs.clean
      expect(described_class.tool_selection(run, gold)[:precision]).to eq(1.0)
      expect(described_class.sequencing(run, gold)[:tau]).to eq(1.0)
      expect(described_class.argument_accuracy(run, gold)[:f1]).to eq(1.0)
    end
  end

  describe "there is rarely one correct path" do
    it "accepts either tool a gold step names" do
      run = T.record(key: "grep", aim: Runs::AIM, reached_aim: true, steps: [
                       { tool: "read_file", args: { path: "auth.rb" }, receipt: { tool: "read_file" } },
                       { tool: "grep", args: {}, receipt: { tool: "grep" } },
                       { tool: "write_patch", args: { file: "auth.rb" }, receipt: { tool: "write_patch" } },
                       { tool: "run_tests", args: { suite: "auth" }, receipt: { tool: "run_tests" } }
                     ]).fetch(:run)
      expect(described_class.tool_selection(run, gold)[:precision]).to eq(1.0)
    end
  end

  describe "Kendall's tau" do
    it "is 1.0 in order, -1.0 reversed, and 0 for a single swap of two" do
      expect(described_class.kendall_tau([0, 1, 2, 3])).to eq(1.0)
      expect(described_class.kendall_tau([3, 2, 1, 0])).to eq(-1.0)
      expect(described_class.kendall_tau([1, 0])).to eq(-1.0)
    end

    it "refuses to score an ordering with nothing to compare" do
      run = T.record(key: "one", aim: Runs::AIM, steps: [
                       { tool: "read_file", args: {}, receipt: { tool: "read_file" } }
                     ]).fetch(:run)
      expect(described_class.sequencing(run, gold)).to include(tau: nil, because: :no_common_tools)
    end
  end

  describe "R5 — receipt verification" do
    it "PLANT: a claimed call with no entry in the log is critical" do
      run = T.record(key: "ghost", aim: Runs::AIM, steps: [
                       { tool: "read_file", args: { path: "auth.rb" }, receipt: { tool: "read_file" } },
                       { tool: "search_web", args: { q: "null check" }, reasoning: "I searched and found the fix" }
                     ]).fetch(:run)
      f = described_class.receipts(run)
      expect(f.map { |x| x[:test] }).to eq([:fabricated_execution])
      expect(f.first[:severity]).to eq(:critical)
    end

    it "PLANT: the log recording a different tool than the step claims" do
      run = T.record(key: "swap", aim: Runs::AIM, steps: [
                       { tool: "read_file", args: {}, receipt: { tool: "delete_file" } }
                     ]).fetch(:run)
      expect(described_class.receipts(run).first[:test]).to eq(:receipt_tool_mismatch)
    end

    it "PLANT: a result the log does not carry" do
      run = T.record(key: "invent", aim: Runs::AIM, steps: [
                       { tool: "read_file", args: {}, result: "no nulls here",
                         receipt: { tool: "read_file", result: "line 42: obj.name" } }
                     ]).fetch(:run)
      expect(described_class.receipts(run).first[:test]).to eq(:fabricated_result)
    end

    it "is quiet when every claim has its receipt" do
      expect(described_class.receipts(Runs.clean)).to be_empty
    end
  end
end
