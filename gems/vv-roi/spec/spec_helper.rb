# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-roi"

module RoiHelpers
  Roi = Vv::DecisionObject::Roi

  # The triage routing table from the README, priced. `gain` is what the
  # option is worth when it is right; `loss` is a positive magnitude,
  # subtracted when it is wrong; `versus` overrides the confusions that are
  # not symmetric.
  def stakes(**overrides)
    built(
      Roi::Stakes.build(
        question: :route,
        unit: :usd,
        escape: :human_review,
        options: {
          deterministic_code: { gain: 2.00, loss: 12.00 },
          fast_llm: { gain: 1.60, loss: 15.00 },
          human_review: { gain: 0.00, loss: 0.00, cost: 9.00, recovery: 0.97 }
        },
        versus: { %i[fast_llm human_review] => -420.00 },
        **overrides
      )
    )
  end

  # A one-way door with a thin, catastrophic branch — the case expected
  # value is happy to accept and `ruin_below` exists to stop.
  def trade_stakes(**overrides)
    built(
      Roi::Stakes.build(
        question: :trade,
        unit: :usd,
        escape: :human_review,
        options: {
          execute: { gain: 500.00, loss: 200.00, reversible: false },
          human_review: { gain: 0.00, loss: 0.00, cost: 40.00, recovery: 0.40 }
        },
        versus: { %i[execute human_review] => -50_000.00 },
        **overrides
      )
    )
  end

  def policy(**overrides) = Roi::RiskPolicy.build(**overrides)[:data]

  def appraise(dist, s: stakes, p: policy)
    Roi::Appraisal.of(distribution: dist, stakes: s, policy: p)
  end

  # Nothing here raises, so a fixture that failed to build would otherwise
  # arrive as a nil deep inside an example.
  def built(result)
    raise "fixture did not build: #{result[:problems].inspect}" unless result[:ok]

    result[:data]
  end
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.order = :random
  c.include RoiHelpers
end
