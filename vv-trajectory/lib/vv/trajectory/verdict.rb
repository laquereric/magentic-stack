# frozen_string_literal: true

require "set"

module Vv
  module Trajectory
    # A typed, dated fact about a run. Silver.
    #
    # Bronze is what happened -- the steps. Silver is what we concluded about
    # it, and it carries a clock, because a conclusion drawn on Tuesday was not
    # wrong on Monday.
    #
    # A verdict never promotes. Promotion is not a score clearing a bar; the
    # report is evidence put in front of someone who signs. So there is no
    # `pass` a verdict can write and no method here that closes a slice: the
    # slice's outward signal does that, and it is measured on the receiver
    # rather than declared by the system that served them.
    class Verdict
      SOURCES = %i[deterministic judge human].freeze

      attr_reader :run_key, :source, :metrics, :findings, :observed_at,
                  :judge_id, :judge_version, :confidence

      def initialize(run_key:, source:, metrics: {}, findings: [], observed_at: nil,
                     judge_id: nil, judge_version: nil, confidence: nil)
        @run_key = run_key.to_s
        @source = source.to_sym
        @metrics = metrics
        @findings = findings
        @observed_at = observed_at
        @judge_id = judge_id
        @judge_version = judge_version
        @confidence = confidence
      end

      # Compute a verdict from two records and no judgement.
      def self.deterministic(run:, gold: nil, observed_at:)
        m = { receipts: Metrics.receipts(run).size,
              gradient: run.gradient.to_h }
        if gold
          m[:tool_selection] = Metrics.tool_selection(run, gold)
          m[:argument_accuracy] = Metrics.argument_accuracy(run, gold)
          m[:sequencing] = Metrics.sequencing(run, gold)
        end
        { ok: true,
          verdict: new(run_key: run.key, source: :deterministic, metrics: m,
                       findings: run.findings, observed_at: observed_at) }
      end

      # A judge's score may be *recorded*. It may not be computed here, and it
      # arrives with the judge's identity and pinned version attached, because a
      # provider updating a model underneath an unpinned judge is how a score
      # changes with nothing else changing.
      def self.from_judge(run_key:, score:, judge_id:, judge_version:, observed_at:,
                          confidence: nil)
        if judge_version.to_s.strip.empty?
          return { ok: false, reason: :judge_version_unpinned,
                   because: "an unpinned judge changes its answer with nothing else changing" }
        end

        { ok: true,
          verdict: new(run_key: run_key, source: :judge, metrics: { score: score },
                       observed_at: observed_at, judge_id: judge_id,
                       judge_version: judge_version, confidence: confidence) }
      end

      def deterministic? = source == :deterministic

      # Whether this verdict may stand alone. A deterministic verdict may. A
      # judge's may not: it is a first pass requiring review, whatever its
      # confidence says.
      def standalone? = deterministic?

      def to_h
        h = { run_key: run_key, source: source, observed_at: observed_at,
              metrics: metrics, findings: findings.size, standalone: standalone? }
        return h if deterministic?

        h.merge(judge_id: judge_id, judge_version: judge_version, confidence: confidence)
      end
    end

    # Reliability across repeats.
    #
    # pass@k asks whether any of k attempts worked; pass^k asks whether every
    # one did. At a 75% per-trial rate, pass@3 reads 98.4% and pass^3 is 42%.
    # Anything a person depends on needs the second number, so a single
    # observation is refused as a claim about reliability rather than reported
    # as one.
    module Reliability
      module_function

      def over(runs)
        n = runs.size
        return { ok: false, reason: :single_run_is_not_a_pass, because: "k=#{n}" } if n < 2

        succeeded = runs.count(&:reached_aim?)
        { ok: true,
          k: n,
          per_trial: (succeeded.to_f / n).round(4),
          pass_at_k: succeeded.positive?,
          pass_pow_k: succeeded == n }
      end
    end
  end
end
