# frozen_string_literal: true

module Vv
  module DecisionObject
    # Governance gaps only become visible after production incidents —
    # unless something is looking. Audit runs the five named failure modes
    # over a set of decisions that share a definition.
    #
    # These are heuristics with declared thresholds, not measurements.
    # Each finding names the evidence so a human can disagree with it.
    #
    #   Vv::DecisionObject::Audit.run(decisions)
    #   # => { ok: true, data: { findings: [...], counts: {...} } }
    module Audit
      # Defaults chosen to be noticeable rather than precise. Tune them
      # against your own decision volume before wiring anything to them.
      DEFAULTS = {
        min_decisions: 20,
        signal_gap_rate: 0.10,     # decisions missing declared signals
        escalation_floor: 0.01,    # escalations as a share of decisions
        feedback_floor: 0.50,      # commitments with a recorded outcome
        drift_window: 0.20         # share of decisions under a stale version
      }.freeze

      module_function

      # @param decisions [Array<Decision>]
      # @return [Hash] envelope carrying findings and counts
      def run(decisions, **overrides)
        decisions = Array(decisions)
        return Envelope.refuse(:no_decisions, "nothing to audit") if decisions.empty?

        thresholds = DEFAULTS.merge(overrides)
        names = decisions.map { |d| d.definition.name }.uniq
        return Envelope.refuse(:mixed_definitions, "audit expects one definition, got #{names.join(', ')}") if names.size > 1

        counts = tally(decisions)
        findings = [
          signal_degradation(decisions, counts, thresholds),
          constraint_drift(decisions, counts, thresholds),
          metric_myopia(decisions, counts, thresholds),
          feedback_suppression(decisions, counts, thresholds),
          over_automation(decisions, counts, thresholds)
        ].compact

        Envelope.ok(
          data: { findings: findings, counts: counts },
          definition: names.first,
          underpowered: counts[:decisions] < thresholds[:min_decisions]
        )
      end

      def tally(decisions)
        committed = decisions.select(&:committed?)
        {
          decisions: decisions.size,
          committed: committed.size,
          escalated: decisions.count { |d| d.disposition == :escalate },
          refused: decisions.count { |d| d.disposition == :refuse },
          abstained: decisions.count { |d| d.disposition == :abstain },
          with_outcome: decisions.count { |d| !d.outcome.nil? },
          committed_with_outcome: committed.count { |d| !d.outcome.nil? },
          versions: decisions.map { |d| d.definition.version }.tally
        }
      end

      # Signal degradation — the judgment is increasingly made on state
      # the definition declared but did not receive.
      def signal_degradation(decisions, counts, thresholds)
        starved = decisions.select do |d|
          declared = d.definition.signals
          !declared.empty? && !(declared - d.state.keys.map(&:to_sym)).empty?
        end
        return nil if starved.empty?

        rate = starved.size.to_f / counts[:decisions]
        return nil if rate < thresholds[:signal_gap_rate]

        missing = starved.flat_map { |d| d.definition.signals - d.state.keys.map(&:to_sym) }.tally
        finding(
          :signal_degradation,
          "#{pct(rate)} of decisions ran without a declared signal",
          rate: rate,
          missing: missing
        )
      end

      # Constraint drift — the decision set spans definition versions, so
      # the boundaries were not the same for every decision in it.
      def constraint_drift(_decisions, counts, thresholds)
        versions = counts[:versions]
        return nil if versions.size < 2

        minority = versions.values.min.to_f / counts[:decisions]
        return nil if minority < thresholds[:drift_window]

        finding(
          :constraint_drift,
          "decisions span #{versions.size} definition versions; constraints were not identical across the set",
          versions: versions
        )
      end

      # Metric myopia — one question carries the whole decision, so the
      # object is a classifier wearing an ontology.
      def metric_myopia(decisions, _counts, _thresholds)
        definition = decisions.first.definition
        evaluators = definition.questions.size + definition.tables.size
        return nil if evaluators > 1

        finding(
          :metric_myopia,
          "the evaluation layer has a single evaluator (#{evaluators}); " \
          "decision quality is indistinguishable from that one score",
          questions: definition.question_names,
          tables: definition.tables.map(&:name)
        )
      end

      # Feedback suppression — commitments were made and nobody wrote
      # down what happened. The object cannot learn and the decision
      # cannot be separated from its luck.
      def feedback_suppression(decisions, counts, thresholds)
        definition = decisions.first.definition
        if definition.feedback.empty?
          return finding(
            :feedback_suppression,
            "the definition declares no feedback layer; outcomes cannot be attributed to decisions"
          )
        end

        return nil if counts[:committed].zero?

        rate = counts[:committed_with_outcome].to_f / counts[:committed]
        return nil if rate >= thresholds[:feedback_floor]

        finding(
          :feedback_suppression,
          "only #{pct(rate)} of commitments have a recorded outcome",
          rate: rate,
          committed: counts[:committed],
          with_outcome: counts[:committed_with_outcome]
        )
      end

      # Over-automation — nothing ever escalated. Either the domain is
      # genuinely trivial or the threshold is decorative.
      def over_automation(decisions, counts, thresholds)
        rate = counts[:escalated].to_f / counts[:decisions]
        return nil if rate > thresholds[:escalation_floor]

        floors = decisions.first.definition.policy.floors
        finding(
          :over_automation,
          "#{pct(rate)} of decisions escalated; the confidence floor is not binding on this traffic",
          rate: rate,
          floors: floors,
          committed: counts[:committed]
        )
      end

      def finding(mode, because, **evidence)
        { mode: mode, because: because, evidence: evidence.compact }
      end

      def pct(rate)
        format("%.1f%%", rate.to_f * 100)
      end
    end
  end
end
