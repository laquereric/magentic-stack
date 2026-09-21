# frozen_string_literal: true

module Vv
  module DecisionObject
    # Roi prices the options a decision already declares.
    #
    # It does not introduce a seventh layer. It annotates three existing ones:
    # Evaluation gains a payoff per declared option, Commitment gains a veto,
    # Feedback gains a realized value to compare against the expected one.
    #
    # Two rules constrain everything below:
    #
    #   1. Roi is never more permissive than the threshold layer. It can veto a
    #      :commit. It can never turn an :escalate into a :commit. A payoff
    #      matrix is an estimate; a floor is a decision someone made on purpose.
    #
    #   2. Payoffs are never asked of the adapter. A model that prices its own
    #      mistakes is grading its own homework. Stakes are human-declared or
    #      derived from logged outcomes.
    module Roi
      EPSILON = 0.001

      SHAPES = %i[convex linear concave ruinous].freeze

      REASONS = %i[
        stakes_invalid
        stakes_error
        unpriced_option
        negative_expected_value
        downside_exceeded
        ruin_risk
        value_divergence
        irreversible_commitment
      ].freeze

      # ----------------------------------------------------------------------
      # Stakes — what an option is worth when it is right and what it costs
      # when it is wrong. Measurements, not appetite.
      # ----------------------------------------------------------------------
      class Stakes
        OPTION_KEYS = %i[gain loss cost reversible reversal_cost recovery].freeze

        attr_reader :question, :unit, :options, :versus, :escape

        def self.build(question:, unit: :usd, options: {}, versus: {}, escape: nil)
          problems = []

          problems << problem(:question, "must be a Symbol naming a declared question") unless question.is_a?(Symbol)
          problems << problem(:options, "at least one option must be priced") if options.empty?

          options.each do |name, spec|
            unless spec.is_a?(Hash)
              problems << problem(name, "option spec must be a Hash")
              next
            end
            unknown = spec.keys - OPTION_KEYS
            problems << problem(name, "unknown keys #{unknown.inspect}") if unknown.any?
            problems << problem(name, "gain must be Numeric or callable") unless amountish?(spec[:gain])
            problems << problem(name, "loss must be Numeric or callable") unless amountish?(spec[:loss])
            problems << problem(name, "loss must be declared as a positive magnitude") if spec[:loss].is_a?(Numeric) && spec[:loss].negative?
            if spec.key?(:recovery) && !(spec[:recovery].is_a?(Numeric) && spec[:recovery].between?(0, 1))
              problems << problem(name, "recovery must be between 0 and 1")
            end
          end

          versus.each_key do |pair|
            unless pair.is_a?(Array) && pair.size == 2
              problems << problem(:versus, "keys must be [chosen, actual] pairs")
              next
            end
            missing = pair.reject { |o| options.key?(o) }
            problems << problem(:versus, "#{missing.inspect} not priced in options") if missing.any?
          end

          if escape && !options.key?(escape)
            problems << problem(:escape, "escape option #{escape.inspect} is not priced")
          end

          if problems.any?
            return { ok: false, reason: :stakes_invalid,
                     because: "stakes for #{question.inspect} cannot be built",
                     problems: problems }
          end

          { ok: true, data: new(question: question, unit: unit, options: options,
                                versus: versus, escape: escape) }
        end

        def self.problem(key, because) = { key: key, because: because }
        def self.amountish?(v) = v.is_a?(Numeric) || v.respond_to?(:call)
        private_class_method :problem, :amountish?

        def initialize(question:, unit:, options:, versus:, escape:)
          @question = question
          @unit     = unit
          @options  = options.freeze
          @versus   = versus.freeze
          @escape   = escape
          freeze
        end

        def actions = options.keys

        def priced?(option) = options.key?(option)

        def reversible?(option)
          spec = options[option]
          return true if spec.nil?

          spec.fetch(:reversible, true)
        end

        def reversal_cost(option, state)
          amount(options.dig(option, :reversal_cost) || 0, state)
        end

        # Value of acting as if `chosen` when the truth is `actual`.
        # Returns a Float, :unpriced, or :error.
        def cell(chosen, actual, state)
          return :unpriced unless priced?(chosen) && priced?(actual)

          if versus.key?([chosen, actual])
            return amount(versus[[chosen, actual]], state)
          end

          spec = options[chosen]
          cost = amount(spec[:cost] || 0, state)
          return :error if cost == :error

          if chosen == escape
            # The escape route does not have to be right; it has to recover.
            recovery = spec.fetch(:recovery, 1.0)
            gain     = amount(options.dig(actual, :gain) || 0, state)
            return :error if gain == :error

            return (recovery * gain) - cost
          end

          base = if chosen == actual
                   amount(spec[:gain] || 0, state)
                 else
                   loss = amount(spec[:loss] || 0, state)
                   loss == :error ? :error : -loss
                 end
          return :error if base == :error

          base - cost
        end

        # An unevaluable payoff counts as the bad case, for the same reason an
        # unevaluable constraint counts as violated.
        def amount(v, state)
          return v.to_f if v.is_a?(Numeric)
          return 0.0 if v.nil?

          begin
            out = v.call(state)
            out.is_a?(Numeric) ? out.to_f : :error
          rescue StandardError
            :error
          end
        end
      end

      # ----------------------------------------------------------------------
      # RiskPolicy — appetite. Separate from stakes (measurement) and from
      # constraints (boundaries), because the three change on different clocks.
      # ----------------------------------------------------------------------
      class RiskPolicy
        DEFAULTS = {
          require_positive_nov: true,
          max_expected_loss: nil,       # e.g. -25.0 — expected loss worse than this vetoes
          worst_case_floor: nil,        # e.g. -250.0 — any plausible cell worse than this vetoes
          ruin_below: nil,              # e.g. -5_000.0 — unrecoverable; EV cannot argue past it
          ruin_epsilon: EPSILON,
          plausible_above: EPSILON,     # probability below which an outcome is ignored
          concavity_ratio: 2.0,
          require_priced: false,        # veto when the best row has unpriced cells
          irreversible_requires_human: false,
          allow_cost_sensitive_selection: false
        }.freeze

        attr_reader :settings

        def self.build(**overrides)
          unknown = overrides.keys - DEFAULTS.keys
          if unknown.any?
            return { ok: false, reason: :stakes_invalid,
                     because: "unknown risk policy keys",
                     problems: unknown.map { |k| { key: k, because: "not a risk policy setting" } } }
          end

          { ok: true, data: new(DEFAULTS.merge(overrides)) }
        end

        def initialize(settings)
          @settings = settings.freeze
          freeze
        end

        def [](key) = settings[key]
      end

      # ----------------------------------------------------------------------
      # Appraisal — what the numbers say, given a posterior and a payoff matrix.
      # ----------------------------------------------------------------------
      class Appraisal
        attr_reader :unit, :rows, :best, :hold, :likeliest, :shape, :verdict,
                    :reason, :because, :downside, :net_option_value

        def self.of(distribution:, stakes:, policy:, state: {})
          dist = normalize(distribution)
          return { ok: false, reason: :answer_missing, because: "empty distribution" } if dist.empty?

          plausible = dist.select { |_, p| p > policy[:plausible_above] }
          rows = stakes.actions.to_h { |a| [a, row(a, dist, stakes, state, policy)] }

          errored = rows.select { |_, r| r[:error] }.keys
          if errored.any?
            return { ok: false, reason: :stakes_error,
                     because: "payoff for #{errored.first.inspect} could not be evaluated" }
          end

          candidates = rows.reject { |a, _| a == stakes.escape }
          best = candidates.max_by { |_, r| r[:ev] }&.first
          return { ok: false, reason: :unpriced_option, because: "no priced action to commit to" } if best.nil?

          hold = stakes.escape ? rows.dig(stakes.escape, :ev) : 0.0
          likeliest = dist.max_by { |_, p| p }.first

          appraisal = new(
            unit: stakes.unit,
            rows: rows,
            best: best,
            hold: hold,
            likeliest: likeliest,
            downside: rows[best].slice(:expected_loss, :worst_case, :p_loss, :upside),
            net_option_value: rows[best][:ev] - hold,
            shape: shape_of(rows[best], policy),
            plausible: plausible,
            stakes: stakes,
            policy: policy,
            state: state
          )

          { ok: true, data: appraisal }
        end

        def self.normalize(distribution)
          total = distribution.values.sum.to_f
          return {} if total <= 0

          distribution.transform_values { |p| p / total }
        end

        def self.row(action, dist, stakes, state, policy)
          cells = dist.keys.to_h { |actual| [actual, stakes.cell(action, actual, state)] }
          return { error: true, cells: cells } if cells.value?(:error)

          priced = cells.reject { |_, v| v == :unpriced }
          unpriced_mass = dist.reject { |k, _| priced.key?(k) }.values.sum

          ev = priced.sum { |actual, v| dist[actual] * v }
          losses = priced.select { |_, v| v.negative? }
          gains  = priced.select { |_, v| v.positive? }
          plausible_cells = priced.select { |actual, _| dist[actual] > policy[:plausible_above] }

          {
            error: false,
            cells: cells,
            ev: ev,
            expected_loss: losses.sum { |actual, v| dist[actual] * v },
            upside: gains.sum { |actual, v| dist[actual] * v },
            p_loss: losses.keys.sum { |actual| dist[actual] },
            worst_case: plausible_cells.values.min || 0.0,
            best_case: plausible_cells.values.max || 0.0,
            unpriced_mass: unpriced_mass,
            reversible: stakes.reversible?(action)
          }
        end

        def self.shape_of(row, policy)
          up   = row[:best_case].abs
          down = row[:worst_case].abs
          ratio = policy[:concavity_ratio]

          return :ruinous if policy[:ruin_below] && row[:worst_case] <= policy[:ruin_below]
          return :concave if down > up * ratio
          return :convex  if up > down * ratio

          :linear
        end
        private_class_method :normalize, :row, :shape_of

        def initialize(unit:, rows:, best:, hold:, likeliest:, downside:, net_option_value:,
                       shape:, plausible:, stakes:, policy:, state:)
          @unit = unit
          @rows = rows
          @best = best
          @hold = hold
          @likeliest = likeliest
          @downside = downside
          @net_option_value = net_option_value
          @shape = shape
          @plausible = plausible
          @stakes = stakes
          @policy = policy
          @state = state
          @verdict, @reason, @because = adjudicate
          freeze
        end

        def clears? = verdict == :clears

        def diverges? = best != likeliest

        def expected_value = rows.transform_values { |r| r[:ev] }

        def to_h
          {
            unit: unit,
            best: best,
            likeliest: likeliest,
            diverges: diverges?,
            expected_value: expected_value,
            hold: hold,
            net_option_value: net_option_value,
            downside: downside,
            shape: shape,
            reversible: rows[best][:reversible],
            verdict: verdict,
            reason: reason,
            because: because
          }
        end

        private

        def adjudicate
          row = rows[best]

          if @policy[:ruin_below]
            ruinous = row[:cells].select { |actual, v| v.is_a?(Numeric) && v <= @policy[:ruin_below] && @plausible.key?(actual) }
            if ruinous.any?
              everywhere = rows.values.all? do |r|
                r[:cells].any? { |actual, v| v.is_a?(Numeric) && v <= @policy[:ruin_below] && @plausible.key?(actual) }
              end
              return [:vetoes, :ruin_risk,
                      everywhere ? "every action carries an unrecoverable branch" : "committing to #{best.inspect} carries an unrecoverable branch"]
            end
          end

          if @policy[:require_priced] && row[:unpriced_mass] > @policy[:plausible_above]
            return [:vetoes, :unpriced_option,
                    format("%.1f%% of the distribution is unpriced", row[:unpriced_mass] * 100)]
          end

          if @policy[:worst_case_floor] && row[:worst_case] < @policy[:worst_case_floor]
            return [:vetoes, :downside_exceeded,
                    format("worst plausible outcome %.2f %s is below the floor %.2f",
                           row[:worst_case], unit, @policy[:worst_case_floor])]
          end

          if @policy[:max_expected_loss] && row[:expected_loss] < @policy[:max_expected_loss]
            return [:vetoes, :downside_exceeded,
                    format("expected loss %.2f %s exceeds the declared appetite %.2f",
                           row[:expected_loss], unit, @policy[:max_expected_loss])]
          end

          if @policy[:irreversible_requires_human] && !row[:reversible]
            return [:vetoes, :irreversible_commitment,
                    "#{best.inspect} cannot be undone and the policy reserves that for a human"]
          end

          if @policy[:require_positive_nov] && net_option_value <= 0
            return [:vetoes, :negative_expected_value,
                    format("committing is worth %.2f %s less than keeping the option open",
                           -net_option_value, unit)]
          end

          if diverges? && !@policy[:allow_cost_sensitive_selection]
            return [:vetoes, :value_divergence,
                    "the likeliest option is #{likeliest.inspect} but the valuable one is #{best.inspect}"]
          end

          [:clears, nil, format("committing to %s is worth %.2f %s more than review",
                                best.inspect, net_option_value, unit)]
        end
      end

      # ----------------------------------------------------------------------
      # Gate — the one place Roi touches disposition. Downgrade only.
      # ----------------------------------------------------------------------
      def self.gate(disposition, appraisal)
        return { ok: true, data: { disposition: disposition, because: "roi does not review non-commitments" } } unless disposition == :commit
        return { ok: true, data: { disposition: :commit, because: appraisal.because } } if appraisal.clears?

        downgraded = appraisal.reason == :ruin_risk && appraisal.because.start_with?("every action") ? :refuse : :escalate
        { ok: true, data: { disposition: downgraded, reason: appraisal.reason, because: appraisal.because } }
      end

      # ----------------------------------------------------------------------
      # Realized value — the Feedback layer, priced.
      # ----------------------------------------------------------------------
      def self.realize(outcomes, valuation:, state: {})
        value =
          if valuation.respond_to?(:call)
            begin
              valuation.call(outcomes, state)
            rescue StandardError
              return { ok: false, reason: :stakes_error, because: "valuation raised" }
            end
          else
            outcomes.sum do |key, observed|
              table = valuation[key]
              next 0.0 if table.nil?

              (table.is_a?(Hash) ? table[observed] : table).to_f
            end
          end

        return { ok: false, reason: :stakes_error, because: "valuation did not return a number" } unless value.is_a?(Numeric)

        { ok: true, data: { realized: value.to_f } }
      end

      # ----------------------------------------------------------------------
      # Audit — three modes that only exist once decisions are priced.
      # They bracket the five in Audit: over_automation catches a floor set too
      # low, escalation_waste catches one set too high.
      # ----------------------------------------------------------------------
      DEFAULT_AUDIT = {
        min_decisions: 30,
        drift_tolerance: 0.25,   # realized within 25% of expected
        waste_ratio: 1.5,        # review spend vs downside avoided
        tail_fraction: 0.5       # realized loss reaching half the declared worst case
      }.freeze

      def self.audit(priced, thresholds: {})
        t = DEFAULT_AUDIT.merge(thresholds)
        n = priced.size
        findings = []

        settled = priced.select { |p| p[:realized] && p[:expected] }
        if settled.size >= t[:min_decisions]
          expected = settled.sum { |p| p[:expected] } / settled.size
          realized = settled.sum { |p| p[:realized] } / settled.size
          gap = expected.zero? ? 0.0 : (realized - expected) / expected.abs
          if gap.abs > t[:drift_tolerance]
            findings << {
              mode: :payoff_drift,
              because: format("realized value averages %.2f against an expected %.2f", realized, expected),
              evidence: { n: settled.size, expected: expected, realized: realized, gap: gap }
            }
          end
        end

        escalated = priced.select { |p| p[:disposition] == :escalate && p[:hold] && p[:expected] }
        if escalated.size >= t[:min_decisions]
          spend   = escalated.sum { |p| -p[:hold] }
          avoided = escalated.sum { |p| -(p[:expected_loss] || 0.0) }
          if avoided.positive? && spend > avoided * t[:waste_ratio]
            findings << {
              mode: :escalation_waste,
              because: format("review cost %.2f against %.2f of avoided loss", spend, avoided),
              evidence: { n: escalated.size, spend: spend, avoided: avoided }
            }
          end
        end

        declared_tail = priced.filter_map { |p| p[:worst_case] }.min
        observed_tail = priced.filter_map { |p| p[:realized] }.min
        if declared_tail && observed_tail && n >= t[:min_decisions] &&
           observed_tail > declared_tail * t[:tail_fraction]
          findings << {
            mode: :tail_blindness,
            because: format("worst realized loss %.2f never approached the declared %.2f", observed_tail, declared_tail),
            evidence: { n: n, declared: declared_tail, observed: observed_tail }
          }
        end

        {
          ok: true,
          data: { findings: findings, counts: findings.group_by { |f| f[:mode] }.transform_values(&:size) },
          underpowered: n < t[:min_decisions]
        }
      end

      # ----------------------------------------------------------------------
      # Portfolio — the sequence view. Each irreversible commitment sells an
      # option; this is where that position becomes visible.
      # ----------------------------------------------------------------------
      def self.portfolio(priced)
        return { ok: true, data: { n: 0 }, underpowered: true } if priced.empty?

        committed = priced.select { |p| p[:disposition] == :commit }
        shapes = priced.group_by { |p| p[:shape] }.transform_values(&:size)

        {
          ok: true,
          data: {
            n: priced.size,
            committed: committed.size,
            expected_total: priced.filter_map { |p| p[:expected] }.sum,
            realized_total: priced.filter_map { |p| p[:realized] }.sum,
            downside_exposure: committed.filter_map { |p| p[:worst_case] }.sum,
            escalation_spend: priced.select { |p| p[:disposition] == :escalate }.filter_map { |p| p[:hold] }.sum,
            short_option_position: committed.count { |p| p[:reversible] == false },
            shape_mix: shapes
          },
          underpowered: priced.size < DEFAULT_AUDIT[:min_decisions]
        }
      end
    end
  end
end
