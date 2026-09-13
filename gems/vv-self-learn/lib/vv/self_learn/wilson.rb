# frozen_string_literal: true

module Vv
  module SelfLearn
    # Wilson score interval for a binomial pass rate (EvalGrading).
    # 5/5 is a wide interval, not "perfect reliability".
    module Wilson
      Z95 = 1.959963984540054

      module_function

      def interval(passes, n, z: Z95)
        n = n.to_i
        passes = passes.to_i
        if n <= 0
          return Refusal.build(Refusal::N_NOT_PLANNED, "n must be a planned positive integer")
        end
        if passes.negative? || passes > n
          return Refusal.build(Refusal::AUDIT_REJECTED, "passes must be in 0..n")
        end

        p = passes.to_f / n
        z2 = z * z
        denom = 1.0 + (z2 / n)
        centre = p + (z2 / (2.0 * n))
        inner = (p * (1.0 - p) + (z2 / (4.0 * n))) / n
        margin = z * Math.sqrt([inner, 0.0].max)
        lo = [(centre - margin) / denom, 0.0].max
        hi = [(centre + margin) / denom, 1.0].min
        Refusal.ok(n: n, passes: passes, rate: p, wilson95: [lo, hi])
      end
    end
  end
end
