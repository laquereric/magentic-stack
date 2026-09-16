# frozen_string_literal: true

module Vv
  module Nooa
    # The published SWE-bench-Verified evidence behind NOOA's thesis that "the
    # harness matters more than the model": on the IDENTICAL model, harness design
    # alone moves both accuracy and token cost substantially.
    # Source: NVIDIA Labs technical report / labs-OO-Agents.
    module HarnessComparison
      module_function

      Run = Struct.new(:harness, :model, :calls, :tokens, :score, keyword_init: true)

      RUNS = [
        Run.new(harness: "NOOA",     model: "GPT-5.5",         calls: 29,  tokens: 1_100_000, score: 82.2),
        Run.new(harness: "baseline", model: "GPT-5.5",         calls: 66,  tokens: 2_200_000, score: 78.2),
        Run.new(harness: "OpenCode", model: "GPT-5.5",         calls: 30,  tokens: 1_300_000, score: 78.6),
        Run.new(harness: "NOOA",     model: "Claude Opus 4.6", calls: nil, tokens: nil,       score: 79.8),
      ].freeze

      def runs = RUNS

      # Compare two harnesses on the SAME model -- the harness delta the thesis is about.
      # score_delta = to - from; token_ratio/call_ratio = how much MORE `from` spent vs `to`.
      def delta(from:, to:, model: "GPT-5.5")
        a = RUNS.find { |r| r.harness == from && r.model == model }
        b = RUNS.find { |r| r.harness == to   && r.model == model }
        return { ok: false, reason: :unknown_run, because: "need both #{from} and #{to} on #{model}" } unless a && b
        { ok: true, model: model, from: from, to: to,
          score_delta: (b.score - a.score).round(1),
          token_ratio: (a.tokens && b.tokens ? (a.tokens.to_f / b.tokens).round(2) : nil),
          call_ratio:  (a.calls && b.calls ? (a.calls.to_f / b.calls).round(2) : nil) }
      end
    end
  end
end
