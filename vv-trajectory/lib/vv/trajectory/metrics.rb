# frozen_string_literal: true

module Vv
  module Trajectory
    # Deterministic trajectory metrics. No model is called from here.
    #
    # Outcome eval asks whether the agent got the right answer. That misses the
    # three failures that matter -- wrong tool, wrong arguments, wrong order --
    # and misses entirely the case where the answer is right and the path was
    # wrong, which is the one that breaks the moment the task shifts.
    #
    # Every metric below is computed from two records and no judgement. That is
    # deliberate: a judge's error rate on this kind of work is high enough that
    # a judge is a signal, never a ground truth, and nothing here should be
    # cheap to fool.
    module Metrics
      module_function

      # Did the run call the right tool at each step? A gold step may name a set
      # of acceptable tools, because there is rarely one correct path.
      def tool_selection(run, gold)
        pairs = run.tool_steps.zip(gold.steps)
        matched = pairs.count { |actual, expected| expected && actual && expected.accepts_tool?(actual.tool) }
        called = run.tool_steps.size
        expected_count = gold.steps.size
        { matched: matched,
          precision: ratio(matched, called),
          recall: ratio(matched, expected_count) }
      end

      # Right tool, wrong arguments: recall catches a missing required argument,
      # precision catches an invented one. They are different failures and both
      # are silent -- a bad argument usually returns an empty result, which the
      # agent reads as "no data" and proceeds on.
      def argument_accuracy(run, gold)
        recalls = []
        precisions = []
        run.tool_steps.zip(gold.steps).each do |actual, expected|
          next if actual.nil? || expected.nil?

          recalls << expected.argument_recall(actual.args)
          precisions << expected.argument_precision(actual.args)
        end
        r = mean(recalls)
        p = mean(precisions)
        { recall: r, precision: p, f1: f1(r, p) }
      end

      # Right tools, right arguments, wrong order. Kendall's tau over the tools
      # the two runs share: 1.0 is the gold order, 0 is random, -1.0 reversed.
      #
      # Out-of-order execution often passes a happy-path test and then corrupts
      # state under load, which is why order is measured rather than inferred
      # from the outcome.
      def sequencing(run, gold)
        gold_order = gold.steps.map(&:tool)
        actual = run.tool_steps.map(&:tool)
        common = gold_order & actual
        return { tau: nil, comparable: 0, because: :no_common_tools } if common.size < 2

        gold_rank = common.each_with_index.to_h { |t, i| [t, i] }
        observed = actual.select { |t| common.include?(t) }.uniq.map { |t| gold_rank[t] }
        { tau: kendall_tau(observed), comparable: common.size }
      end

      # Every claimed call, cross-referenced against the execution log.
      def receipts(run)
        run.steps.flat_map(&:receipt_findings)
      end

      # Kendall's tau over a permutation of 0..n-1.
      def kendall_tau(order)
        n = order.size
        return nil if n < 2

        concordant = 0
        discordant = 0
        (0...n).each do |i|
          ((i + 1)...n).each do |j|
            if order[i] < order[j]
              concordant += 1
            else
              discordant += 1
            end
          end
        end
        pairs = n * (n - 1) / 2.0
        ((concordant - discordant) / pairs).round(4)
      end

      def ratio(num, den) = den.zero? ? nil : (num.to_f / den).round(4)
      def mean(values) = values.empty? ? nil : (values.sum.to_f / values.size).round(4)

      def f1(recall, precision)
        return nil if recall.nil? || precision.nil? || (recall + precision).zero?

        ((2 * recall * precision) / (recall + precision)).round(4)
      end
    end
  end
end
